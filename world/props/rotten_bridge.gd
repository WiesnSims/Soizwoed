class_name RottenBridge
extends StaticBody3D
## Old planks across a Gesenk (DESIGN.md §4 "rotten floors"): they creak under anyone and give
## way under anyone carrying something heavy (or a heavy thing dropped on them). The host
## watches who is on it and breaks it on every peer; it stays broken for the shift.

@export var length: float = 6.0
@export var width: float = 1.2

var broken: bool = false

var _area: Area3D
var _planks: Array[MeshInstance3D] = []
var _strain: float = 0.0
var _creak_left: float = 0.0
var _check_left: float = 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(width, 0.08, length)
	shape.shape = box
	add_child(shape)
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.34, 0.25, 0.16)
	wood.roughness = 0.95
	var count: int = floori(length / 0.32)
	for i: int in count:
		var plank: MeshInstance3D = MeshInstance3D.new()
		var board: BoxMesh = BoxMesh.new()
		board.size = Vector3(width * (0.85 + 0.15 * absf(sin(i * 1.7))), 0.05, 0.28)
		plank.mesh = board
		plank.material_override = wood
		plank.position = Vector3(sin(i * 3.1) * 0.05, 0.02, -length / 2.0 + 0.16 + i * 0.32)
		plank.rotation.y = sin(i * 2.3) * 0.06
		add_child(plank)
		_planks.append(plank)
	for side: float in [-width / 2.0, width / 2.0]:
		var beam: MeshInstance3D = MeshInstance3D.new()
		var log_mesh: BoxMesh = BoxMesh.new()
		log_mesh.size = Vector3(0.1, 0.12, length)
		beam.mesh = log_mesh
		beam.material_override = load("res://assets/materials/timber_wood.tres") as Material
		beam.position = Vector3(side, -0.05, 0.0)
		add_child(beam)
		_planks.append(beam)
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2 | WorldItem.LAYER_ITEMS
	_area.monitorable = false
	var zone: CollisionShape3D = CollisionShape3D.new()
	var zone_box: BoxShape3D = BoxShape3D.new()
	zone_box.size = Vector3(width + 0.2, 1.0, length - 1.6)
	zone.shape = zone_box
	zone.position = Vector3.UP * 0.5
	_area.add_child(zone)
	add_child(_area)


func _physics_process(delta: float) -> void:
	if broken or not multiplayer.is_server():
		return
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = 0.2
	var anyone: bool = false
	var heavy: bool = false
	for body: Node3D in _area.get_overlapping_bodies():
		anyone = true
		heavy = heavy or _is_heavy(body)
	_strain = _strain + 0.2 if heavy else 0.0
	_creak_left -= 0.2
	if anyone and _creak_left <= 0.0:
		_creak_left = randf_range(0.8, 1.6)
		_creak.rpc()
	if _strain >= Balance.config.rotten_break_seconds:
		_collapse.rpc()
		print("[hazards] %s gave way" % name)


## Someone carrying something heavy (a Schubkarre with a heavy load counts), or a heavy item.
static func _is_heavy(body: Node3D) -> bool:
	var player: Player = body as Player
	if player != null:
		var cart: CargoItem = player.inventory.hands as CargoItem
		if cart != null:
			return cart.used_units() >= cart.heavy_units()
		return player.alive and player.inventory.hands != null and player.inventory.hands_weight == ItemData.WeightClass.HEAVY
	var item: WorldItem = body as WorldItem
	return item != null and item.state == WorldItem.State.FREE and item.data.weight_class == ItemData.WeightClass.HEAVY


@rpc("authority", "call_local", "reliable")
func _creak() -> void:
	Audio.play_at("plank_creak", global_position + Vector3.UP * 0.2, &"SFX", -2.0, 20.0)


@rpc("authority", "call_local", "reliable")
func _collapse() -> void:
	if broken:
		return
	broken = true
	Audio.play_at("plank_crack", global_position, &"SFX", 4.0, 40.0)
	collision_layer = 0
	for plank: MeshInstance3D in _planks:
		plank.visible = false
	# A few planks still hang from the ends.
	for i: int in [0, 1, _planks.size() - 3]:
		if i >= 0 and i < _planks.size():
			_planks[i].visible = true
			_planks[i].rotation.x = 0.9 if i < 3 else -0.9
