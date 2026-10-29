class_name NetBackend
extends RefCounted
## Common interface of the transport backends. Only NetworkManager uses these.
##
## Hosting and joining may take a while (Steam first creates or joins a lobby), so both are
## started with `start_host` / `start_join`, and `peer_ready` or `failed` follows – right away
## for ENet, after the lobby callbacks for Steam.

## The multiplayer peer for the session that was started is ready to use.
signal peer_ready(peer: MultiplayerPeer)
## Starting the session failed after all. `reason` is a translation key.
signal failed(reason: String)
## The player accepted an invite (or clicked "join game" on a friend) outside the game's menus.
signal join_requested(target: String)
## Result of `find_lobbies`: Array of Dictionaries {target, name, players, max_players, friend}.
## May be emitted several times while more results come in.
signal lobbies_found(lobbies: Array)


func get_backend_name() -> String:
	return "none"


## False when the backend cannot run here (e.g. Steam not running).
func is_available() -> bool:
	return false


## Starts hosting for up to `max_clients` clients. False when it fails right away.
func start_host(port: int, max_clients: int, _public: bool) -> bool:
	var peer: MultiplayerPeer = create_host(port, max_clients)
	if peer == null:
		return false
	peer_ready.emit(peer)
	return true


## Starts joining `target`. False when it fails right away.
func start_join(target: String, port: int) -> bool:
	var peer: MultiplayerPeer = create_client(target, port)
	if peer == null:
		return false
	peer_ready.emit(peer)
	return true


## A peer hosting a session for up to `max_clients` clients, or null on failure.
func create_host(_port: int, _max_clients: int) -> MultiplayerPeer:
	return null


## A peer connecting to `target`, or null on failure.
func create_client(_target: String, _port: int) -> MultiplayerPeer:
	return null


## The session ended or a pending host/join was cancelled.
func close() -> void:
	pass


## Called every frame.
func poll() -> void:
	pass


## Whether late joiners may come in now (only in the hub, DESIGN.md §9).
func set_joinable(_joinable: bool) -> void:
	pass


## The player's own name, or "" when the backend has none (then "Kumpl N" is used).
func local_name() -> String:
	return ""


## The name of `peer_id` in the session of `peer`, or "".
func peer_name(_peer: MultiplayerPeer, _peer_id: int) -> String:
	return ""


## True when the backend can list sessions to join (`find_lobbies`).
func can_find_lobbies() -> bool:
	return false


func find_lobbies() -> void:
	lobbies_found.emit([])


## True when friends can be invited to the running session (`invite_friends`).
func can_invite() -> bool:
	return false


## Opens the platform's own invite dialog (Steam overlay); false when it cannot be shown.
func invite_friends() -> bool:
	return false


## Friends who could be invited, for the in-game list: [{"id": int, "name": String,
## "online": bool, "in_game": bool}], online friends first.
func invitable_friends() -> Array[Dictionary]:
	return []


## Invites one friend from `invitable_friends` to the running session.
func invite_friend(_friend_id: int) -> bool:
	return false


## True when this backend carries voice chat.
func has_voice() -> bool:
	return false
