class_name ShotFx
extends RefCounted
## What a shot looks and sounds like, on every peer: the report (loud, echoing), a muzzle flash
## that lights the tunnel for an instant, a faint tracer per pellet and a puff where it hit
## (salt dust on rock, dark spray on flesh). Purely cosmetic.

const FLASH_SECONDS: float = 0.06
const TRACER_SECONDS: float = 0.07

static var _tracer_material: StandardMaterial3D


static func play(muzzle: Vector3, ends: PackedVector3Array, flesh: PackedByteArray, sound: String) -> void:
	var root: Node = Engine.get_main_loop().current_scene if Engine.get_main_loop() is SceneTree else null
	if root == null:
		return
	Audio.play_at(sound, muzzle, &"SFX", 4.0, 90.0, randf_range(0.96, 1.04))
	var flash: OmniLight3D = OmniLight3D.new()
	flash.light_color = Color(1.0, 0.8, 0.5)
	flash.light_energy = 5.0
	flash.omni_range = 7.0
	flash.shadow_enabled = false
	root.add_child(flash)
	flash.global_position = muzzle
	var fade: Tween = flash.create_tween()
	fade.tween_property(flash, "light_energy", 0.0, FLASH_SECONDS)
	fade.tween_callback(flash.queue_free)
	for i: int in ends.size():
		_tracer(root, muzzle, ends[i])
		if muzzle.distance_to(ends[i]) < 80.0:
			_impact(root, ends[i], i < flesh.size() and flesh[i] == 1)


static func _tracer(root: Node, from: Vector3, to: Vector3) -> void:
	if _tracer_material == null:
		_tracer_material = StandardMaterial3D.new()
		_tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tracer_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_tracer_material.albedo_color = Color(1.0, 0.85, 0.55, 0.35)
	var length: float = from.distance_to(to)
	if length < 0.5:
		return
	var line: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.008, 0.008, length)
	line.mesh = box
	line.material_override = _tracer_material
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(line)
	line.global_position = (from + to) / 2.0
	if absf((to - from).normalized().dot(Vector3.UP)) < 0.99:
		line.look_at(to, Vector3.UP)
	var fade: Tween = line.create_tween()
	fade.tween_interval(TRACER_SECONDS)
	fade.tween_callback(line.queue_free)


static func _impact(root: Node, at: Vector3, flesh: bool) -> void:
	var puff: CPUParticles3D = CPUParticles3D.new()
	puff.one_shot = true
	puff.emitting = false
	puff.amount = 10
	puff.lifetime = 0.5
	puff.explosiveness = 1.0
	puff.spread = 180.0
	puff.initial_velocity_min = 0.6
	puff.initial_velocity_max = 2.0
	puff.gravity = Vector3(0, -3.0, 0)
	puff.scale_amount_min = 0.02
	puff.scale_amount_max = 0.05
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3.ONE
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.04, 0.03) if flesh else Color(0.75, 0.7, 0.62)
	mesh.material = material
	puff.mesh = mesh
	root.add_child(puff)
	puff.global_position = at
	puff.emitting = true
	var done: Tween = puff.create_tween()
	done.tween_interval(1.0)
	done.tween_callback(puff.queue_free)
