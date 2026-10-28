class_name FlickerLight
extends OmniLight3D
## A flame's light: energy wobbles with smooth noise. Used by lanterns and the carbide lamp.

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


func _process(delta: float) -> void:
	_time += delta * speed
	light_energy = base_energy * (1.0 + flicker * _noise.get_noise_1d(_time * 7.0))
