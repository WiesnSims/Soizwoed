extends Node
## Session handling behind one interface. Everything outside net/ talks to this autoload,
## never to a backend or to Steam directly. Solo is a session where we are the host
## (peer 1) with zero clients, so all host code paths run in solo too.

signal session_started
## `reason` is a translation key, shown to the player.
signal session_ended(reason: String)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)

enum Mode { NONE, SOLO, HOST, CLIENT }

const MAX_PLAYERS: int = 4

var mode: Mode = Mode.NONE
var options: NetOptions = NetOptions.parse(OS.get_cmdline_user_args())
## Translation key of why the last session ended, for the main menu.
var last_end_reason: String = ""

var _backend: NetBackend


func _ready() -> void:
	_backend = _pick_backend(options.backend)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(_delta: float) -> void:
	if mode == Mode.HOST or mode == Mode.CLIENT:
		_backend.poll()


static func game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0"))


func backend_name() -> String:
	return _backend.get_backend_name()


func in_session() -> bool:
	return mode != Mode.NONE


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


func host() -> bool:
	leave()
	var peer: MultiplayerPeer = _backend.create_host(options.port, MAX_PLAYERS - 1)
	if peer == null:
		last_end_reason = "NET_HOST_FAILED"
		return false
	multiplayer.multiplayer_peer = peer
	mode = Mode.HOST
	print("[net] hosting via %s" % backend_name())
	session_started.emit()
	return true


## Starts connecting; `session_started` or `session_ended` follows.
func join(target: String) -> bool:
	leave()
	var peer: MultiplayerPeer = _backend.create_client(target, options.port)
	if peer == null:
		last_end_reason = "NET_CONNECT_FAILED"
		return false
	multiplayer.multiplayer_peer = peer
	mode = Mode.CLIENT
	print("[net] joining %s via %s" % [target, backend_name()])
	return true


func leave() -> void:
	if mode == Mode.NONE:
		return
	# Detach before closing so the multiplayer API never sends on a closed peer.
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peer.close()
	mode = Mode.NONE
	print("[net] left session")


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
