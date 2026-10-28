extends Node3D
## Dev tool: generates a mine and saves screenshots along its main path, lit by a carbide-lamp
## style light at the camera. Needs a real window (not --headless).
##   godot --path . res://tools/preview/mine_preview.tscn -- --seed=7 --out=<dir>

const CHUNKS: ChunkSet = preload("res://world/chunks/oberer_stollen/oberer_stollen.tres")
const ENVIRONMENT: Environment = preload("res://world/mine_environment.tres")
const SETTLE_FRAMES: int = 45

var _shots: Array[Transform3D] = []
var _shot: int = 0
var _frames: int = 0
var _out_dir: String = "user://preview"
var _camera: Camera3D


func _ready() -> void:
	var seed_value: int = 7
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed_value = arg.trim_prefix("--seed=").to_int()
		elif arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = ENVIRONMENT
	add_child(world_env)
	var mine: Mine = Mine.new()
	add_child(mine)
	mine.build(seed_value, MineParams.from_balance(BalanceConfig.new(), 1), CHUNKS)
	_camera = Camera3D.new()
	_camera.fov = 75.0
	add_child(_camera)
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.5)
	lamp.light_energy = 2.2
	lamp.omni_range = 14.0
	lamp.omni_attenuation = 1.2
	lamp.shadow_enabled = true
	lamp.light_size = 0.05
	lamp.position = Vector3(0.25, -0.25, -0.2)
	_camera.add_child(lamp)
	_plan_shots(mine)


## A shot from inside the station looking out, then from each main-path cell looking along it.
func _plan_shots(mine: Mine) -> void:
	var size: float = mine.chunk_set.cell_size
	var path: Array[Vector2i] = mine.layout.main_path
	for i: int in mini(path.size() - 1, 6):
		var here: Vector3 = Vector3(path[i].x, 0.0, path[i].y) * size + Vector3(0.0, 1.65, 0.0)
		var next: Vector3 = Vector3(path[i + 1].x, 0.0, path[i + 1].y) * size + Vector3(0.0, 1.5, 0.0)
		var from: Vector3 = here.lerp(next, 0.15)
		_shots.append(Transform3D.IDENTITY.translated(from).looking_at(next, Vector3.UP))
	# The station chamber, seen from its tunnel mouth.
	var station: Chunk = mine.station
	var look_from: Vector3 = station.to_global(Vector3(-1.0, 1.7, -3.5))
	_shots.append(Transform3D.IDENTITY.translated(look_from).looking_at(station.to_global(Vector3(0.5, 1.2, 3.0)), Vector3.UP))


func _process(_delta: float) -> void:
	if _shot >= _shots.size():
		get_tree().quit()
		return
	_camera.global_transform = _shots[_shot]
	_frames += 1
	if _frames < SETTLE_FRAMES:
		return
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(_out_dir.path_join("shot_%d.png" % _shot))
	_frames = 0
	_shot += 1
