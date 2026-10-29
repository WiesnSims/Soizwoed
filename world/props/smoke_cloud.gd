class_name SmokeCloud
extends Node3D
## The "Bierzelt" cloud (DESIGN.md §7): a thick, yellowish haze of stale beer, smoke and
## worse. Only the look; the host keeps the zone creatures avoid (Game.add_smoke). Billowing
## puffs plus a fog volume, so it also hangs in the lamp light when volumetric fog is on.

var radius: float = 5.0
var seconds: float = 35.0

var _puffs: CPUParticles3D
var _fog: FogVolume
var _fog_material: FogMaterial


func _ready() -> void:
	_puffs = CPUParticles3D.new()
	_puffs.amount = 48
	_puffs.lifetime = 7.0
	_puffs.preprocess = 2.0
	_puffs.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_puffs.emission_sphere_radius = radius * 0.55
	_puffs.direction = Vector3.UP
	_puffs.spread = 180.0
	_puffs.initial_velocity_min = 0.05
	_puffs.initial_velocity_max = 0.3
	_puffs.gravity = Vector3(0.0, 0.04, 0.0)
	_puffs.scale_amount_min = 1.4
	_puffs.scale_amount_max = 2.6
	var fade: Curve = Curve.new()
	fade.add_point(Vector2(0.0, 0.3))
	fade.add_point(Vector2(0.3, 1.0))
	fade.add_point(Vector2(1.0, 0.6))
	_puffs.scale_amount_curve = fade
	_puffs.color = Color(0.62, 0.56, 0.32, 0.28)
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _soft_dot()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.roughness = 1.0
	quad.material = material
	_puffs.mesh = quad
	_puffs.position = Vector3.UP * 0.8
	add_child(_puffs)
	_fog_material = FogMaterial.new()
	_fog_material.density = 0.6
	_fog_material.albedo = Color(0.7, 0.62, 0.36)
	_fog = FogVolume.new()
	_fog.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	_fog.size = Vector3(radius * 2.0, radius, radius * 2.0)
	_fog.material = _fog_material
	_fog.position = Vector3.UP * radius * 0.35
	add_child(_fog)
	_fade_out_later()


func _fade_out_later() -> void:
	await get_tree().create_timer(maxf(0.0, seconds - 4.0)).timeout
	_puffs.emitting = false
	var tween: Tween = create_tween()
	tween.tween_property(_fog_material, "density", 0.0, 4.0)
	await tween.finished
	await get_tree().create_timer(_puffs.lifetime).timeout
	queue_free()


## A round, soft-edged puff texture.
static func _soft_dot() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	return texture
