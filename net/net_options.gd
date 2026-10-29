class_name NetOptions
extends RefCounted
## Networking options from the command line (the part after `--`):
##   --net=enet|steam   transport backend (default steam; enet in headless runs, so automated
##                      tests never show up as "playing" on the Steam account)
##   --host             host a session right away
##   --public           Steam: the hosted lobby can be found by everyone, not only friends
##   --join=<target>    join right away (IP for ENet, lobby id for Steam)
##   --lobby=<id>       same as --join=<id>
##   --port=<n>         ENet port
##   --find-lobbies     search for lobbies right away (tools/steam_test.ps1)
##   --solo             start a solo session right away
## Steam itself starts the game with `+connect_lobby <id>` when a friend's invite is accepted
## while the game is not running; that ends up as `join_target` too.

const DEFAULT_PORT: int = 24760
const STEAM_CONNECT_ARG: String = "+connect_lobby"

var backend: String = "steam"
var auto_host: bool = false
var auto_solo: bool = false
var public_lobby: bool = false
var auto_find: bool = false
var join_target: String = ""
var port: int = DEFAULT_PORT


## `args` are the user arguments (after `--`), `engine_args` all others (Steam's launch
## arguments land there).
static func parse(args: PackedStringArray, engine_args: PackedStringArray = PackedStringArray(),
		headless: bool = false) -> NetOptions:
	var options: NetOptions = NetOptions.new()
	if headless:
		options.backend = "enet"
	for arg: String in args:
		if arg.begins_with("--net="):
			options.backend = arg.trim_prefix("--net=").to_lower()
		elif arg == "--host":
			options.auto_host = true
		elif arg == "--public":
			options.public_lobby = true
		elif arg == "--find-lobbies":
			options.auto_find = true
		elif arg == "--solo":
			options.auto_solo = true
		elif arg.begins_with("--join="):
			options.join_target = arg.trim_prefix("--join=")
		elif arg.begins_with("--lobby="):
			options.join_target = arg.trim_prefix("--lobby=")
		elif arg.begins_with("--port="):
			options.port = arg.trim_prefix("--port=").to_int()
	var lobby: String = steam_connect_target(engine_args)
	if lobby != "":
		options.join_target = lobby
	return options


## The lobby id in Steam's `+connect_lobby <id>` launch arguments, or "".
static func steam_connect_target(args: PackedStringArray) -> String:
	for i: int in args.size():
		if args[i] == STEAM_CONNECT_ARG and i + 1 < args.size() and args[i + 1].is_valid_int():
			return args[i + 1]
		if args[i].begins_with(STEAM_CONNECT_ARG + " ") or args[i].begins_with(STEAM_CONNECT_ARG + "="):
			var value: String = args[i].substr(STEAM_CONNECT_ARG.length() + 1).strip_edges()
			if value.is_valid_int():
				return value
	return ""
