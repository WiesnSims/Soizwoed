class_name Rope
extends Node3D
## A Seil hung down an edge (DESIGN.md §7): a climbable line from its hook at `top` down to
## `bottom`, for the rest of the shift. Hold E on the hook to take it back. Made on every peer
## by Game._place_rope with the same name.

var top: Vector3
var bottom: Vector3


func setup(new_top: Vector3, new_bottom: Vector3) -> void:
	top = new_top
	bottom = new_bottom
	global_position = bottom
	var length: float = top.y - bottom.y
	var rope_material: StandardMaterial3D = StandardMaterial3D.new()
	rope_material.albedo_color = Color(0.62, 0.5, 0.32)
	rope_material.roughness = 0.95
	var line: MeshInstance3D = MeshInstance3D.new()
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 0.018
	cylinder.bottom_radius = 0.018
	cylinder.height = length
	cylinder.radial_segments = 6
	cylinder.rings = 1
	line.mesh = cylinder
	line.material_override = rope_material
	line.position = Vector3.UP * length / 2.0
	add_child(line)
	var climb: Climbable = Climbable.new()
	climb.height = length
	add_child(climb)
	climb.position = Vector3.ZERO
	var hook: RopeHook = RopeHook.new()
	add_child(hook)
	hook.position = Vector3.UP * length


## The iron hook at the top: E (held) takes the rope back.
class RopeHook:
	extends StaticBody3D

	func _ready() -> void:
		collision_layer = 16
		collision_mask = 0
		var shape: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(0.4, 0.3, 0.4)
		shape.shape = box
		add_child(shape)
		var iron: StandardMaterial3D = StandardMaterial3D.new()
		iron.albedo_color = Color(0.4, 0.4, 0.42)
		iron.metallic = 0.9
		iron.roughness = 0.4
		var ring: MeshInstance3D = MeshInstance3D.new()
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = 0.05
		torus.outer_radius = 0.08
		ring.mesh = torus
		ring.material_override = iron
		ring.rotation.x = PI / 2.0
		ring.position = Vector3.UP * 0.05
		add_child(ring)

	func interaction_text(_player: Player) -> String:
		return tr("PROMPT_ROPE_TAKE")

	func interact_hold_seconds(_player: Player) -> float:
		return 1.0

	func interact(_player: Player) -> void:
		Game.instance.request_take_rope.rpc_id(1, get_parent().get_path())
