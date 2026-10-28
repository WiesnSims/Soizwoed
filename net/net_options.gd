class_name NetOptions
extends RefCounted
## Networking options from the command line (the part after `--`):
##   --net=enet|steam   transport backend (default steam)
##   --host             host a session right away
##   --join=<target>    join right away (IP for ENet)
##   --port=<n>         ENet port
##   --solo             start a solo session right away

const DEFAULT_PORT: int = 24760

var backend: String = "steam"
var auto_host: bool = false
var auto_solo: bool = false
var join_target: String = ""
var port: int = DEFAULT_PORT


static func parse(args: PackedStringArray) -> NetOptions:
	var options: NetOptions = NetOptions.new()
	for arg: String in args:
		if arg.begins_with("--net="):
			options.backend = arg.trim_prefix("--net=").to_lower()
		elif arg == "--host":
			options.auto_host = true
		elif arg == "--solo":
			options.auto_solo = true
		elif arg.begins_with("--join="):
			options.join_target = arg.trim_prefix("--join=")
		elif arg.begins_with("--port="):
			options.port = arg.trim_prefix("--port=").to_int()
	return options
