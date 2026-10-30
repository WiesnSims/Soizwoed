class_name ShotFx
extends RefCounted
## What a shot looks and sounds like, on every peer: the report (a real recording) with the
## mine throwing it back (a long rolling echo), a muzzle flash that lights the tunnel for an
## instant, a faint tracer per pellet, and what it hit: salt dust on rock, a spray of dark blood
## on flesh. There is no hit marker (owner decision): you see the blood and hear the creature –
## in the dark you may not know whether you hit.

const FLASH_SECONDS: float = 0.06
const TRACER_SECONDS: float = 0.06

static var _tracer_material: StandardMaterial3D
static var _flash_material: StandardMaterial3D
static var _dust_material: StandardMaterial3D
static var _blood_material: StandardMaterial3D


## `own` is the shooter's own shot: their GunView shows the flash on the gun, so no flash here.
static func play(muzzle: Vector3, ends: PackedVector3Array, flesh: PackedByteArray, sound: String, show_flash: bool = true) -> void:
	var root: Node = Engine.get_main_loop().current_scene if Engine.get_main_loop() is SceneTree else null
	if root == null:
		return
	Audio.play_at(sound, muzzle, &"SFX", -1.0, 90.0, randf_range(0.97, 1.03))
	# The mine throws it back: a long, dark rolling echo, heard far.
	Audio.play_at("shot_echo", muzzle, &"SFX", -6.0, 120.0, randf_range(0.9, 1.05))
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(1.0, 0.78, 0.45)
	light.light_energy = 6.0
	light.omni_range = 8.0
	light.shadow_enabled = false
	root.add_child(light)
	light.global_position = muzzle
	var fade: Tween = light.create_tween()
	fade.tween_property(light, "light_energy", 0.0, FLASH_SECONDS)
	fade.tween_callback(light.queue_free)
	if show_flash:
		_flash(root, muzzle, ends[0] if not ends.is_empty() else muzzle)
	for i: int in ends.size():
		_tracer(root, muzzle, ends[i])
		if muzzle.distance_to(ends[i]) < 80.0:
			if i < flesh.size() and flesh[i] == 1:
				_blood(root, ends[i], (ends[i] - muzzle).normalized())
			else:
				_dust(root, ends[i])


static func _flash(root: Node, at: Vector3, toward: Vector3) -> void:
	if _flash_material == null:
		_flash_material = StandardMaterial3D.new()
		_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_flash_material.albedo_color = Color(1.0, 0.72, 0.35, 0.9)
		_flash_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.25, 0.25)
	var flash: MeshInstance3D = MeshInstance3D.new()
	flash.mesh = quad
	flash.material_override = _flash_material
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(flash)
	flash.global_position = at + (toward - at).normalized() * 0.1
	var done: Tween = flash.create_tween()
	done.tween_interval(FLASH_SECONDS)
	done.tween_callback(flash.queue_free)


static func _tracer(root: Node, from: Vector3, to: Vector3) -> void:
	if _tracer_material == null:
		_tracer_material = StandardMaterial3D.new()
		_tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tracer_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_tracer_material.albedo_color = Color(1.0, 0.85, 0.55, 0.3)
	var length: float = from.distance_to(to)
	if length < 0.5:
		return
	var line: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.006, 0.006, length)
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


## Salt dust and grit where a shot hits rock.
static func _dust(root: Node, at: Vector3) -> void:
	if _dust_material == null:
		_dust_material = StandardMaterial3D.new()
		_dust_material.albedo_color = Color(0.78, 0.73, 0.65)
		_dust_material.roughness = 1.0
	_burst(root, at, Vector3.UP, _dust_material, 12, 0.02, 0.05, 2.0, 0.6)


## A hit on a creature: a spray of dark blood out of the far side and some dripping down.
static func _blood(root: Node, at: Vector3, direction: Vector3) -> void:
	if _blood_material == null:
		_blood_material = StandardMaterial3D.new()
		_blood_material.albedo_color = Color(0.32, 0.02, 0.02)
		_blood_material.roughness = 0.35
		_blood_material.metallic_specular = 0.8
	_burst(root, at, direction, _blood_material, 26, 0.02, 0.06, 3.5, 0.8)
	_burst(root, at, Vector3.DOWN, _blood_material, 8, 0.03, 0.07, 0.8, 1.2)


static func _burst(root: Node, at: Vector3, direction: Vector3, material: Material, amount: int, small: float, big: float, speed: float, life: float) -> void:
	var puff: CPUParticles3D = CPUParticles3D.new()
	puff.one_shot = true
	puff.emitting = false
	puff.amount = amount
	puff.lifetime = life
	puff.explosiveness = 0.95
	puff.direction = direction
	puff.spread = 35.0
	puff.initial_velocity_min = speed * 0.4
	puff.initial_velocity_max = speed
	puff.gravity = Vector3(0, -9.0, 0)
	puff.scale_amount_min = small
	puff.scale_amount_max = big
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = material
	puff.mesh = mesh
	root.add_child(puff)
	puff.global_position = at
	puff.emitting = true
	var done: Tween = puff.create_tween()
	done.tween_interval(life + 0.5)
	done.tween_callback(puff.queue_free)
