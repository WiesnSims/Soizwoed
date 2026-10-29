extends Node
## Session handling behind one interface. Everything outside net/ talks to this autoload,
## never to a backend or to Steam directly. Solo is a session where we are the host
## (peer 1) with zero clients, so all host code paths run in solo too.
##
## Hosting and joining can take a moment (Steam lobbies): `host()` / `join()` start it, then
## `session_started` (or `session_ended` with a reason) follows.

signal session_started
## `reason` is a translation key, shown to the player.
signal session_ended(reason: String)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
## An invite was accepted while in the main menu; the menu joins `pending_invite`.
signal invite_pending
## Results of `find_lobbies()` (see NetBackend.lobbies_found).
signal lobbies_found(lobbies: Array)

enum Mode { NONE, SOLO, HOST, CLIENT }

const MAX_PLAYERS: int = 4

var mode: Mode = Mode.NONE
var options: NetOptions = NetOptions.parse(OS.get_cmdline_user_args(), OS.get_cmdline_args(),
		DisplayServer.get_name() == "headless")
## Translation key of why the last session ended, for the main menu.
var last_end_reason: String = ""
## A join target (Steam lobby) from an accepted invite, joined by the main menu.
var pending_invite: String = ""

var _backend: NetBackend
## HOST or CLIENT while the backend is still setting the session up, else NONE.
var _pending: Mode = Mode.NONE


func _ready() -> void:
	_backend = _pick_backend(options.backend)
	_backend.peer_ready.connect(_on_backend_peer_ready)
	_backend.failed.connect(_on_backend_failed)
	_backend.join_requested.connect(_on_backend_join_requested)
	_backend.lobbies_found.connect(lobbies_found.emit)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	if options.join_target != "" and _backend.get_backend_name() == "steam":
		pending_invite = options.join_target
		options.join_target = ""


func _process(_delta: float) -> void:
	_backend.poll()


static func game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0"))


func backend_name() -> String:
	return _backend.get_backend_name()


func in_session() -> bool:
	return mode != Mode.NONE


## True while a host or join is being set up.
func is_connecting() -> bool:
	return _pending != Mode.NONE


## True for solo and for the host of a multiplayer session.
func is_host() -> bool:
	return mode == Mode.SOLO or mode == Mode.HOST


func player_count() -> int:
	if not in_session():
		return 0
	return multiplayer.get_peers().size() + 1


func host_solo() -> void:
	leave()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = Mode.SOLO
	print("[net] solo session started")
	session_started.emit()


## Starts hosting (Steam: a friends-only lobby unless `public`); `session_started` follows.
func host(public: bool = options.public_lobby) -> bool:
	leave()
	_pending = Mode.HOST
	if not _backend.start_host(options.port, MAX_PLAYERS - 1, public):
		_pending = Mode.NONE
		last_end_reason = "NET_HOST_FAILED"
		return false
	return true


## Starts connecting; `session_started` or `session_ended` follows.
func join(target: String) -> bool:
	leave()
	_pending = Mode.CLIENT
	if not _backend.start_join(target, options.port):
		_pending = Mode.NONE
		last_end_reason = "NET_CONNECT_FAILED"
		return false
	print("[net] joining %s via %s" % [target, backend_name()])
	return true


func leave() -> void:
	if _pending != Mode.NONE:
		_pending = Mode.NONE
		_backend.close()
	if mode == Mode.NONE:
		return
	# Detach before closing so the multiplayer API never sends on a closed peer.
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peer.close()
	if mode != Mode.SOLO:
		_backend.close()
	mode = Mode.NONE
	print("[net] left session")


## Late join is only allowed in the hub (DESIGN.md §9): the host closes the lobby during a shift.
func set_joinable(joinable: bool) -> void:
	if mode == Mode.HOST:
		_backend.set_joinable(joinable)


## The player's own name (Steam name), or "".
func local_name() -> String:
	return _backend.local_name() if _backend.is_available() else ""


## The display name of `peer_id` (Steam name), or "" when the backend has none.
func peer_name(peer_id: int) -> String:
	if mode == Mode.HOST or mode == Mode.CLIENT:
		return _backend.peer_name(multiplayer.multiplayer_peer, peer_id)
	if mode == Mode.SOLO and _backend.is_available():
		return _backend.local_name()
	return ""


func can_find_lobbies() -> bool:
	return _backend.can_find_lobbies()


func find_lobbies() -> void:
	_backend.find_lobbies()


func can_invite() -> bool:
	return mode == Mode.HOST and _backend.can_invite()


## The Steam overlay's invite dialog; false when the overlay is not there (the game was not
## started by Steam), then the HUD shows its own friends list.
func invite_friends() -> bool:
	return can_invite() and _backend.invite_friends()


func invitable_friends() -> Array[Dictionary]:
	if not can_invite():
		return []
	return _backend.invitable_friends()


func invite_friend(friend_id: int) -> bool:
	return can_invite() and _backend.invite_friend(friend_id)


## Proximity voice runs in multiplayer sessions over a backend that carries it (Steam).
func voice_enabled() -> bool:
	return (mode == Mode.HOST or mode == Mode.CLIENT) and _backend.has_voice()


func _end_session(reason: String) -> void:
	leave()
	last_end_reason = reason
	session_ended.emit(reason)


func _pick_backend(backend: String) -> NetBackend:
	if backend == "enet":
		return ENetBackend.new()
	var steam: SteamBackend = SteamBackend.new()
	if steam.is_available():
		return steam
	print("[net] Steam backend not available, using ENet")
	return ENetBackend.new()


func _on_backend_peer_ready(peer: MultiplayerPeer) -> void:
	var wanted: Mode = _pending
	_pending = Mode.NONE
	if wanted == Mode.NONE:
		peer.close()
		return
	multiplayer.multiplayer_peer = peer
	mode = wanted
	if mode == Mode.HOST:
		print("[net] hosting via %s" % backend_name())
		session_started.emit()


func _on_backend_failed(reason: String) -> void:
	if _pending == Mode.NONE:
		return
	_pending = Mode.NONE
	print("[net] %s failed: %s" % [backend_name(), reason])
	last_end_reason = reason
	session_ended.emit(reason)


func _on_backend_join_requested(target: String) -> void:
	pending_invite = target
	if in_session() or is_connecting():
		# The game scene reloads to the main menu, which then joins the invite.
		_end_session("NET_JOINING_INVITE")
	else:
		invite_pending.emit()


func _on_peer_connected(peer_id: int) -> void:
	if is_host():
		print("[net] peer joined: %d" % peer_id)
		peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if is_host():
		print("[net] peer left: %d" % peer_id)
		peer_left.emit(peer_id)


func _on_connected_to_server() -> void:
	print("[net] connected as peer %d" % multiplayer.get_unique_id())
	session_started.emit()


func _on_connection_failed() -> void:
	print("[net] connection failed")
	_end_session("NET_CONNECT_FAILED")


func _on_server_disconnected() -> void:
	print("[net] host left")
	_end_session("NET_HOST_LEFT")
