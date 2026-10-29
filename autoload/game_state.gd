extends Node
## Owns the current run. Host-authoritative: only the host changes the run; syncing it
## to clients comes with M2.

signal run_started
signal run_changed
signal run_ended(score: Dictionary)

const SMOKE_ARG: String = "--smoke="

var run: RunState


func _ready() -> void:
	_start_smoke_timer_if_requested()


func start_run(player_count: int) -> void:
	run = RunState.new(Balance.config, player_count)
	run_started.emit()
	run_changed.emit()


func finish_shift(loot_value: int) -> void:
	var cycle_ended: bool = run.finish_shift(loot_value)
	run_changed.emit()
	if cycle_ended and run.fired:
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
	await get_tree().create_timer(0.3).timeout
	get_tree().quit(0)
