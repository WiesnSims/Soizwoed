extends Node
## Owns the current run. Host-authoritative: only the host changes the run; syncing it
## to clients comes with M2.

signal run_started
signal run_changed
signal run_ended(score: Dictionary)

const SMOKE_ARG: String = "--smoke="
## `--profile=<name>` keeps the profile in user://profile_<name>.cfg (several instances on one
## PC); automated runs without it never touch the real profile.
const PROFILE_ARG: String = "--profile="
const AUTOMATED_ARGS: Array[String] = ["--smoke=", "--scenario=", "--auto-shift", "--shots=", "--wait-peers="]

var run: RunState
## This player's own profile: Ehrenzeichen and the Knappenbrief (DESIGN.md §7).
var profile: PlayerProfile


func _ready() -> void:
	profile = PlayerProfile.new(_profile_path())
	profile.load_from_file(Balance.config.perks_by_id())
	_start_smoke_timer_if_requested()


func _profile_path() -> String:
	var automated: bool = DisplayServer.get_name() == "headless"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(PROFILE_ARG):
			return "user://profile_%s.cfg" % arg.trim_prefix(PROFILE_ARG).validate_filename()
		for prefix: String in AUTOMATED_ARGS:
			automated = automated or arg.begins_with(prefix)
	return "" if automated else PlayerProfile.DEFAULT_PATH


## The company honours this player: Ehrenzeichen into the profile, saved at once.
func earn_ehrenzeichen(amount: int) -> void:
	if amount <= 0:
		return
	profile.earn(amount)
	profile.save()


## The run is over for this player (fired after `shifts` shifts).
func record_run(shifts: int) -> void:
	profile.finish_run(shifts)
	profile.save()


func start_run(player_count: int) -> void:
	run = RunState.new(Balance.config, player_count)
	run_started.emit()
	run_changed.emit()


func finish_shift(loot_value: int, delivered: bool, bonus: int = 0, honours: int = 0) -> void:
	run.finish_shift(loot_value, delivered, bonus, honours)
	run_changed.emit()
	if run.fired:
		run_ended.emit(run.score())


func end_run() -> void:
	run = null


## `--smoke=<seconds>` quits the game after that long (headless smoke tests).
func _start_smoke_timer_if_requested() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(SMOKE_ARG):
			var seconds: float = arg.trim_prefix(SMOKE_ARG).to_float()
			print("[smoke] quitting after %.1f s" % seconds)
			get_tree().create_timer(seconds).timeout.connect(_on_smoke_timeout)


func _on_smoke_timeout() -> void:
	print("[smoke] done")
	NetworkManager.leave()
	# Free the scene first so no sound is still playing at exit (that leaks the playback).
	get_tree().unload_current_scene()
	Audio.stop_all()  # and the stings and UI sounds, which live on the Audio autoload
	await get_tree().create_timer(0.3).timeout
	get_tree().quit(0)
