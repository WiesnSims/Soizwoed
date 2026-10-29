extends Node
## Audio buses, audio settings, and one-shot sound helpers. Sounds are looked up by name in
## assets/audio/{sfx,ambience,voices/*}; "name.ogg" or variants "name_1.ogg", "name_2.ogg" ...
## of which one is picked at random.

const BUSES: PackedStringArray = ["Music", "SFX", "Creatures", "Voice", "Ambience"]
const ROOT: String = "res://assets/audio/"
const FOLDERS: PackedStringArray = ["sfx", "ambience"]

## Setting "Gegner reden": creature speech on/off. Non-speech creature sounds always play.
var creature_lines_enabled: bool = true

var _variants: Dictionary = {}  # name -> Array[AudioStream]


func _ready() -> void:
	for bus_name: String in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			var index: int = AudioServer.bus_count
			AudioServer.add_bus(index)
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")


## A random variant of `name` (e.g. "footstep_gravel" or "voices/bergmandl/giggle"), or null.
func stream(sound: String) -> AudioStream:
	if not _variants.has(sound):
		_variants[sound] = _find_variants(sound)
	var found: Array = _variants[sound]
	return null if found.is_empty() else found[randi() % found.size()]


func _find_variants(sound: String) -> Array:
	var result: Array = []
	var bases: PackedStringArray = [ROOT + sound] if sound.contains("/") else PackedStringArray()
	for folder: String in FOLDERS:
		bases.append(ROOT + folder + "/" + sound)
	for base: String in bases:
		if ResourceLoader.exists(base + ".ogg"):
			result.append(load(base + ".ogg"))
		var i: int = 1
		while ResourceLoader.exists("%s_%d.ogg" % [base, i]):
			result.append(load("%s_%d.ogg" % [base, i]))
			i += 1
		if not result.is_empty():
			break
	if result.is_empty():
		push_warning("no sound named %s" % sound)
	return result


## A one-shot positional sound that frees itself when done.
func play_at(sound: String, where: Vector3, bus: StringName = &"SFX", volume_db: float = 0.0,
		max_distance: float = 30.0, pitch: float = 1.0) -> AudioStreamPlayer3D:
	var audio: AudioStream = stream(sound)
	if audio == null:
		return null
	return play_stream_at(audio, where, bus, volume_db, max_distance, pitch)


## Like play_at, for a stream at hand (e.g. a creature's last words).
func play_stream_at(audio: AudioStream, where: Vector3, bus: StringName = &"SFX", volume_db: float = 0.0,
		max_distance: float = 30.0, pitch: float = 1.0) -> AudioStreamPlayer3D:
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = audio
	player.bus = bus
	player.volume_db = volume_db
	player.max_distance = max_distance
	player.unit_size = 4.0
	player.pitch_scale = pitch
	player.attenuation_filter_cutoff_hz = 6000.0
	get_tree().current_scene.add_child(player)
	player.global_position = where
	player.finished.connect(player.queue_free)
	player.play()
	return player


## Plays on an existing 3D player node (e.g. one riding on a creature), picking a variant.
func play_on(player: AudioStreamPlayer3D, sound: String, pitch_jitter: float = 0.0) -> void:
	var audio: AudioStream = stream(sound)
	if audio == null:
		return
	player.stream = audio
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()


func play_ui(sound: String) -> void:
	var audio: AudioStream = stream(sound)
	if audio == null:
		return
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = audio
	player.bus = &"SFX"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
