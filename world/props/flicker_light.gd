class_name FlickerLight
extends Light3D
## A flame's light: energy wobbles with smooth noise. Used by lanterns (omni) and the miners'
## lamps (the beam is a spot, the glow around them an omni).

@export var base_energy: float = 1.0
@export_range(0.0, 1.0) var flicker: float = 0.12
@export var speed: float = 1.0

var _noise: FastNoiseLite = FastNoiseLite.new()
var _time: float = 0.0


func _ready() -> void:
	_noise.seed = randi()
	_noise.frequency = 1.0
	_noise.fractal_octaves = 3
	_time = randf() * 100.0
	# Far lights fade out, and their shadows sooner (Settings.shadow_distance): a shadowed
	# omni light renders the scene six more times, so only the near ones may.
	distance_fade_enabled = true
	distance_fade_begin = 32.0
	distance_fade_length = 8.0
	_apply_shadow_distance()
	Settings.changed.connect(_apply_shadow_distance)


func _apply_shadow_distance() -> void:
	distance_fade_shadow = Settings.shadow_distance


func _process(delta: float) -> void:
	_time += delta * speed
	light_energy = base_energy * (1.0 + flicker * _noise.get_noise_1d(_time * 7.0))
