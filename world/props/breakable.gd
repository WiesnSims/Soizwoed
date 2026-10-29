class_name Breakable
extends StaticBody3D
## Rock the Spitzhacke can break (DESIGN.md §7): a thin salt wall closing a shortcut or a
## niche, or a pile of rubble left by a rockfall. Part of the mine on every peer (same name and
## path everywhere); the host counts the hits and breaks it for all. A blocked passage keeps
## its waypoint switched off, so creatures do not walk into the wall until it is gone.

enum Kind { SALT_WALL, RUBBLE }

@export var kind: Kind = Kind.SALT_WALL
@export var size: Vector3 = Vector3(5.6, 4.4, 0.7)

var health: int = 1
## The waypoint this blocks (-1: none).
var nav_point: int = -1

var _mesh: MeshInstance3D


func _ready() -> void:
	add_to_group(&"breakables")
	collision_layer = 1
	collision_mask = 0
	health = Balance.config.salt_wall_health if kind == Kind.SALT_WALL else Balance.config.rubble_health
	if get_child_count() == 0:
		_build()


func _build() -> void:
	var rock: Material = load("res://assets/materials/salt_rock.tres") as Material
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3.UP * size.y / 2.0
	add_child(shape)
	_mesh = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	_mesh.mesh = mesh
	_mesh.position = shape.position
	_mesh.material_override = rock
	add_child(_mesh)
	# A few lumps so it reads as a rough wall of salt, not a panel.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(name)
	for i: int in 7:
		var lump: MeshInstance3D = MeshInstance3D.new()
		var ball: SphereMesh = SphereMesh.new()
		ball.radius = rng.randf_range(0.35, 0.7)
		ball.height = ball.radius * 1.4
		ball.radial_segments = 10
		ball.rings = 5
		lump.mesh = ball
		lump.material_override = rock
		var side: float = -1.0 if i % 2 == 0 else 1.0
		lump.position = Vector3(rng.randf_range(-size.x, size.x) * 0.4, rng.randf_range(0.3, size.y * 0.8), side * size.z * 0.45)
		add_child(lump)


## Host: a pick hit (only the Spitzhacke breaks rock).
func host_hit(damage: int) -> void:
	health -= damage
	if health <= 0:
		Game.instance.host_broke(self)
		_break.rpc()
	else:
		_crack.rpc()


@rpc("authority", "call_local", "reliable")
func _crack() -> void:
	Audio.play_at("pick_hit", global_position + Vector3.UP * 1.2, &"SFX", 0.0, 25.0)
	_puff(6)


@rpc("authority", "call_local", "reliable")
func _break() -> void:
	Audio.play_at("wall_break", global_position + Vector3.UP * 1.2, &"SFX", 2.0, 40.0)
	_puff(28)
	if Game.instance != null and Game.instance.mine != null and nav_point >= 0:
		Game.instance.mine.nav.set_point_disabled(nav_point, false)
	collision_layer = 0
	for child: Node in get_children():
		if child is MeshInstance3D or child is CollisionShape3D:
			child.queue_free()
	await get_tree().create_timer(3.0).timeout
	queue_free()


## Salt dust bursting from the rock.
func _puff(amount: int) -> void:
	var dust: CPUParticles3D = CPUParticles3D.new()
	dust.one_shot = true
	dust.amount = amount
	dust.lifetime = 1.6
	dust.explosiveness = 0.9
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = size * Vector3(0.4, 0.4, 0.5)
	dust.direction = Vector3.UP
	dust.spread = 80.0
	dust.initial_velocity_min = 0.5
	dust.initial_velocity_max = 2.5
	dust.scale_amount_min = 0.05
	dust.scale_amount_max = 0.18
	dust.color = Color(0.85, 0.82, 0.76, 0.8)
	var grain: SphereMesh = SphereMesh.new()
	grain.radius = 0.5
	grain.height = 1.0
	grain.radial_segments = 4
	grain.rings = 2
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grain.material = material
	dust.mesh = grain
	dust.position = Vector3.UP * size.y * 0.5
	add_child(dust)
	dust.emitting = true
	dust.finished.connect(dust.queue_free)
