class_name SteamBackend
extends NetBackend
## Steam transport via GodotSteam (App ID 480). The only place outside voice code that may
## call Steam APIs. Not implemented before M3: until then it reports itself unavailable
## and NetworkManager falls back to ENet.
##
## Lobby rule for M3: every lobby sets and every search filters
## `game=soizwoed` and `ver=<NetworkManager.game_version()>` (App ID 480 is shared).

const LOBBY_GAME: String = "soizwoed"


func get_backend_name() -> String:
	return "steam"


func is_available() -> bool:
	return false
