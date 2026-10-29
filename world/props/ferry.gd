class_name Ferry
extends Node3D
## The ferry across the Salzsee lake (DESIGN.md §4: "small boat to cross water"): a flat Zille
## that crosses between two landings. Ring the bell at either landing ("Hol über!") and it
## crosses to the other side: it comes over to you, or takes you across. Every peer moves its
## own copy the same way when the host says so; standing on it carries you along.

@export var dock_a: Vector3 = Vector3(0.0, 0.0, -3.5)
@export var dock_b: Vector3 = Vector3(0.0, 0.0, 3.5)
@export var bell_a: Vector3 = Vector3(2.0, 0.0, -5.5)
@export var bell_b: Vector3 = Vector3(2.0, 0.0, 5.5)

var at_b: bool = false
var moving: bool = false

var _boat: AnimatableBody3D
var _oars: AudioStreamPlayer3D


func _ready() -> void:
	_build_boat()
	_add_bell(bell_a, "BellA")
	_add_bell(bell_b, "BellB")


func _build_boat() -> void:
	_boat = AnimatableBody3D.new()
	_boat.name = "Boat"
	_boat.sync_to_physics = true
	_boat.collision_layer = 1
	_boat.position = dock_a
	add_child(_boat)
	var wood: Material = load("res://assets/materials/timber_wood.tres") as Material
	var dark: StandardMaterial3D = StandardMaterial3D.new()
	dark.albedo_color = Color(0.22, 0.15, 0.09)
	dark.roughness = 0.8
	var deck: CollisionShape3D = CollisionShape3D.new()
	var deck_box: BoxShape3D = BoxShape3D.new()
	deck_box.size = Vector3(2.6, 0.2, 4.2)
	deck.shape = deck_box
	deck.position = Vector3.DOWN * 0.08
	_boat.add_child(deck)
	_part(Vector3(2.6, 0.08, 4.2), Vector3(0.0, -0.02, 0.0), wood)  # deck planks
	_part(Vector3(2.4, 0.5, 4.0), Vector3(0.0, -0.32, 0.0), dark)  # hull
	for side: float in [-1.27, 1.27]:
		_part(Vector3(0.08, 0.3, 4.2), Vector3(side, 0.13, 0.0), dark)  # gunwales
		var rail: CollisionShape3D = CollisionShape3D.new()
		var rail_box: BoxShape3D = BoxShape3D.new()
		rail_box.size = Vector3(0.08, 0.3, 4.2)
		rail.shape = rail_box
		rail.position = Vector3(side, 0.13, 0.0)
		_boat.add_child(rail)
	_part(Vector3(0.12, 1.6, 0.12), Vector3(1.0, 0.8, 1.7), wood)  # lantern post
	_oars = AudioStreamPlayer3D.new()
	_oars.stream = Audio.stream("row")
	_oars.bus = &"SFX"
	_oars.max_distance = 30.0
	_boat.add_child(_oars)


func _part(part_size: Vector3, at: Vector3, material: Material) -> void:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = part_size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	_boat.add_child(mesh)


func _add_bell(at: Vector3, bell_name: String) -> void:
	var bell: FerryBell = FerryBell.new()
	bell.name = bell_name
	bell.position = at
	add_child(bell)


func boat_position() -> Vector3:
	return _boat.global_position


## Host: a bell was rung. The ferry crosses unless it is already under way.
func host_ring() -> bool:
	if moving:
		return false
	_cross.rpc(not at_b)
	return true


@rpc("authority", "call_local", "reliable")
func _cross(to_b: bool) -> void:
	moving = true
	if _oars.stream != null:
		_oars.play()
	var tween: Tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_boat, "position", dock_b if to_b else dock_a, Balance.config.ferry_seconds)
	await tween.finished
	at_b = to_b
	moving = false
	_oars.stop()


## The bell on a post at a landing: E rings it.
class FerryBell:
	extends StaticBody3D

	func _ready() -> void:
		collision_layer = 16
		collision_mask = 0
		var shape: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(0.5, 2.2, 0.5)
		shape.shape = box
		shape.position = Vector3.UP * 1.1
		add_child(shape)
		var post: MeshInstance3D = MeshInstance3D.new()
		var pole: BoxMesh = BoxMesh.new()
		pole.size = Vector3(0.14, 2.2, 0.14)
		post.mesh = pole
		post.material_override = load("res://assets/materials/timber_wood.tres") as Material
		post.position = Vector3.UP * 1.1
		add_child(post)
		var bronze: StandardMaterial3D = StandardMaterial3D.new()
		bronze.albedo_color = Color(0.7, 0.5, 0.22)
		bronze.metallic = 0.95
		bronze.roughness = 0.3
		var bell: MeshInstance3D = MeshInstance3D.new()
		var cup: CylinderMesh = CylinderMesh.new()
		cup.top_radius = 0.07
		cup.bottom_radius = 0.16
		cup.height = 0.22
		bell.mesh = cup
		bell.material_override = bronze
		bell.position = Vector3(0.0, 1.95, -0.2)
		add_child(bell)

	func interaction_text(_player: Player) -> String:
		var ferry: Ferry = get_parent() as Ferry
		return tr("PROMPT_FERRY_BUSY") if ferry.moving else tr("PROMPT_FERRY_BELL")

	func interact(_player: Player) -> void:
		Game.instance.request_ferry.rpc_id(1, get_parent().get_path(), global_position + Vector3.UP * 1.9)
