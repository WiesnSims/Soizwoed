class_name SteamBackend
extends NetBackend
## Steam transport via GodotSteam (App ID 480). The only place outside voice code that may
## call Steam APIs.
##
## Hosting creates a Steam lobby (friends only unless --public) and a SteamMultiplayerPeer host;
## joining joins a lobby and connects a client peer to the lobby owner. Traffic goes through
## the host (server relay), the same star layout as ENet, and Steam's relays handle NAT.
##
## App ID 480 is shared by many developers: every lobby sets `game=soizwoed` and
## `ver=<NetworkManager.game_version()>`, every search filters on both, and joining a lobby
## with other values is refused.

const APP_ID: int = 480
const LOBBY_GAME: String = "soizwoed"
const KEY_GAME: String = "game"
const KEY_VERSION: String = "ver"
const KEY_NAME: String = "name"

enum State { IDLE, CREATING, JOINING, IN_LOBBY }

var _initialised: bool = false
var _init_tried: bool = false
var _state: State = State.IDLE
var _lobby_id: int = 0
var _max_members: int = 0
## Lobbies found by the current search: lobby id -> info Dictionary (see NetBackend).
var _found: Dictionary = {}
## Friends' lobbies we asked Steam about and are waiting for (lobby id -> friend steam id).
var _asked: Dictionary = {}


func get_backend_name() -> String:
	return "steam"


func is_available() -> bool:
	if not _init_tried:
		_init_tried = true
		_initialised = _init_steam()
	return _initialised


func _init_steam() -> bool:
	if not ClassDB.class_exists("Steam"):
		print("[steam] GodotSteam is not loaded")
		return false
	if not Steam.isSteamRunning():
		print("[steam] Steam is not running")
		return false
	var result: Dictionary = Steam.steamInitEx(APP_ID, true)
	if int(result.get("status", -1)) != Steam.STEAM_API_INIT_RESULT_OK:
		print("[steam] init failed: %s" % result.get("verbal", "?"))
		return false
	Steam.initRelayNetworkAccess()
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	Steam.lobby_data_update.connect(_on_lobby_data_update)
	Steam.join_requested.connect(_on_join_requested)
	Steam.join_game_requested.connect(_on_join_game_requested)
	print("[steam] ready as %s (app %d)" % [Steam.getPersonaName(), APP_ID])
	return true


# --- hosting and joining --------------------------------------------------------------------------

func start_host(_port: int, max_clients: int, public: bool) -> bool:
	close()
	_state = State.CREATING
	_max_members = max_clients + 1
	var lobby_type: int = Steam.LOBBY_TYPE_PUBLIC if public else Steam.LOBBY_TYPE_FRIENDS_ONLY
	Steam.createLobby(lobby_type, _max_members)
	print("[steam] creating %s lobby" % ("public" if public else "friends-only"))
	return true


func start_join(target: String, _port: int) -> bool:
	if not target.is_valid_int() or target.to_int() <= 0:
		return false
	close()
	_state = State.JOINING
	Steam.joinLobby(target.to_int())
	print("[steam] joining lobby %s" % target)
	return true


func close() -> void:
	if _lobby_id != 0:
		Steam.leaveLobby(_lobby_id)
		print("[steam] left lobby %d" % _lobby_id)
	_lobby_id = 0
	_state = State.IDLE
	Steam.clearRichPresence()


func _on_lobby_created(result: int, lobby_id: int) -> void:
	if _state != State.CREATING:
		return
	if result != Steam.RESULT_OK:
		print("[steam] lobby could not be created (%d)" % result)
		_state = State.IDLE
		failed.emit("NET_HOST_FAILED")
		return
	_lobby_id = lobby_id
	_state = State.IN_LOBBY
	for entry: Array in lobby_metadata(NetworkManager.game_version(), Steam.getPersonaName()):
		Steam.setLobbyData(lobby_id, entry[0], entry[1])
	Steam.setLobbyJoinable(lobby_id, true)
	Steam.setRichPresence("connect", "%s %d" % [NetOptions.STEAM_CONNECT_ARG, lobby_id])
	var peer: SteamMultiplayerPeer = SteamMultiplayerPeer.new()
	peer.server_relay = true
	var error: int = peer.create_host(0)
	if error != OK:
		print("[steam] host peer failed: %s" % error_string(error))
		close()
		failed.emit("NET_HOST_FAILED")
		return
	print("[steam] lobby created %d" % lobby_id)
	peer_ready.emit(peer)


func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	# Steam also reports joining our own new lobby; only a join we asked for counts here.
	if _state != State.JOINING:
		return
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		print("[steam] could not join lobby %d (%d)" % [lobby_id, response])
		_state = State.IDLE
		failed.emit("NET_LOBBY_FULL" if response == Steam.CHAT_ROOM_ENTER_RESPONSE_FULL else "NET_CONNECT_FAILED")
		return
	_lobby_id = lobby_id
	_state = State.IN_LOBBY
	var info: Dictionary = _lobby_info(lobby_id)
	var check: String = lobby_problem(info, NetworkManager.game_version())
	var owner: int = Steam.getLobbyOwner(lobby_id)
	if check == "" and owner == Steam.getSteamID():
		check = "NET_CONNECT_FAILED"
	if check != "":
		print("[steam] refusing lobby %d: %s %s" % [lobby_id, check, info])
		close()
		failed.emit(check)
		return
	var peer: SteamMultiplayerPeer = SteamMultiplayerPeer.new()
	peer.server_relay = true
	var error: int = peer.create_client(owner, 0)
	if error != OK:
		print("[steam] client peer failed: %s" % error_string(error))
		close()
		failed.emit("NET_CONNECT_FAILED")
		return
	Steam.setRichPresence("connect", "%s %d" % [NetOptions.STEAM_CONNECT_ARG, lobby_id])
	print("[steam] joined lobby %d, connecting to host %d" % [lobby_id, owner])
	peer_ready.emit(peer)


func set_joinable(joinable: bool) -> void:
	if _lobby_id != 0 and _state == State.IN_LOBBY and Steam.getLobbyOwner(_lobby_id) == Steam.getSteamID():
		Steam.setLobbyJoinable(_lobby_id, joinable)


## The key/value pairs every Soizwöd lobby carries.
static func lobby_metadata(version: String, host_name: String) -> Array[Array]:
	return [[KEY_GAME, LOBBY_GAME], [KEY_VERSION, version], [KEY_NAME, host_name]]


## Why a lobby with `data` may not be joined by this build ("" = fine), as a translation key.
static func lobby_problem(data: Dictionary, version: String) -> String:
	if str(data.get(KEY_GAME, "")) != LOBBY_GAME:
		return "NET_NOT_SOIZWOED"
	if str(data.get(KEY_VERSION, "")) != version:
		return "NET_WRONG_VERSION"
	return ""


# --- invites --------------------------------------------------------------------------------------

func can_invite() -> bool:
	return _lobby_id != 0 and _state == State.IN_LOBBY


func invite_friends() -> void:
	if can_invite():
		Steam.activateGameOverlayInviteDialog(_lobby_id)


## Accepted an invite in the overlay or clicked "join game" on a friend in a lobby.
func _on_join_requested(lobby_id: int, _friend_id: int) -> void:
	print("[steam] join requested for lobby %d" % lobby_id)
	join_requested.emit(str(lobby_id))


## "Join game" via the rich presence connect string ("+connect_lobby <id>").
func _on_join_game_requested(_user: int, connect: String) -> void:
	var target: String = NetOptions.steam_connect_target(connect.split(" ", false))
	if target != "":
		join_requested.emit(target)


# --- finding lobbies ------------------------------------------------------------------------------

func can_find_lobbies() -> bool:
	return true


## Public Soizwöd lobbies of this version, plus the lobbies friends are in.
func find_lobbies() -> void:
	_found.clear()
	_asked.clear()
	Steam.addRequestLobbyListStringFilter(KEY_GAME, LOBBY_GAME, Steam.LOBBY_COMPARISON_EQUAL)
	Steam.addRequestLobbyListStringFilter(KEY_VERSION, NetworkManager.game_version(), Steam.LOBBY_COMPARISON_EQUAL)
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.requestLobbyList()
	for i: int in Steam.getFriendCount(Steam.FRIEND_FLAG_IMMEDIATE):
		var friend: int = Steam.getFriendByIndex(i, Steam.FRIEND_FLAG_IMMEDIATE)
		var game: Dictionary = Steam.getFriendGamePlayed(friend)
		var lobby: int = int(game.get("lobby", 0))
		if int(game.get("id", 0)) == APP_ID and lobby != 0:
			_asked[lobby] = friend
			if not Steam.requestLobbyData(lobby):
				_asked.erase(lobby)


func _on_lobby_match_list(lobbies: Array) -> void:
	for lobby: Variant in lobbies:
		_add_found(int(lobby), false)
	lobbies_found.emit(_found.values())


func _on_lobby_data_update(_success: int, lobby_id: int, member_id: int) -> void:
	# Only the answers to our requestLobbyData for friends' lobbies (not member data changes).
	if not _asked.has(lobby_id) or member_id != lobby_id:
		return
	_asked.erase(lobby_id)
	if _add_found(lobby_id, true):
		lobbies_found.emit(_found.values())


func _lobby_info(lobby_id: int) -> Dictionary:
	var data: Dictionary = {}
	for key: String in [KEY_GAME, KEY_VERSION, KEY_NAME]:
		data[key] = Steam.getLobbyData(lobby_id, key)
	return data


func _add_found(lobby_id: int, friend: bool) -> bool:
	var data: Dictionary = _lobby_info(lobby_id)
	if lobby_problem(data, NetworkManager.game_version()) != "" or lobby_id == _lobby_id:
		return false
	_found[lobby_id] = {
		"target": str(lobby_id),
		"name": data[KEY_NAME],
		"players": Steam.getNumLobbyMembers(lobby_id),
		"max_players": Steam.getLobbyMemberLimit(lobby_id),
		"friend": friend or bool(_found.get(lobby_id, {}).get("friend", false)),
	}
	return true


# --- names and voice ------------------------------------------------------------------------------

func local_name() -> String:
	return Steam.getPersonaName()


func peer_name(peer: MultiplayerPeer, peer_id: int) -> String:
	var steam_peer: SteamMultiplayerPeer = peer as SteamMultiplayerPeer
	if steam_peer == null:
		return ""
	var steam_id: int = steam_peer.get_steam_id_for_peer_id(peer_id)
	if steam_id == 0:
		return ""
	return Steam.getPersonaName() if steam_id == Steam.getSteamID() else Steam.getFriendPersonaName(steam_id)


func has_voice() -> bool:
	return true
