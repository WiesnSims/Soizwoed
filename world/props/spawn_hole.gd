class_name SpawnHole
extends Node3D
## A "Loch" (DESIGN.md §4): where a wave breaks out of the rock after the alarm – a black hollow
## in the wall (or the floor), cracks and broken salt around it and the rubble it threw out.
## Built the same on every peer from where the host found the rock; it stays for the rest of the
## shift, so the crew sees where they came from. Purely a look: no collision, the creatures walk out of it.

const SIZE: float = 1.1

var normal: Vector3 = Vector3.FORWARD


static func open(parent: Node, at: Vector3, wall_normal: Vector3) -> SpawnHole:
	var hole: SpawnHole = SpawnHole.new()
	hole.name = "SpawnHole"
	hole.normal = wall_normal.normalized()
	parent.add_child(hole)
	hole.global_position = at
	return hole


func _ready() -> void:
	var up: Vector3 = normal
	var side: Vector3 = up.cross(Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT).normalized()
	global_basis = Basis(side, up, side.cross(up)).orthonormalized()
	var rock: Material = load("res://assets/materials/salt_rock.tres") as Material
	# The hollow: black where the light does not reach in, inside a ring of cracks.
	var hollow: Decal = Decal.new()
	hollow.texture_albedo = ImpactFx.mark_texture(&"pool")
	hollow.modulate = Color(0.0, 0.0, 0.0)
	hollow.size = Vector3(SIZE, 0.8, SIZE * 0.8)
	add_child(hollow)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(global_position.snapped(Vector3.ONE * 0.1))
	for i: int in 7:
		var angle: float = TAU * i / 7.0 + rng.randf_range(-0.3, 0.3)
		var chunk: MeshInstance3D = MeshInstance3D.new()
		var stone: SphereMesh = SphereMesh.new()
		stone.radius = rng.randf_range(0.08, 0.16)
		stone.height = stone.radius * 1.4
		stone.radial_segments = 6
		stone.rings = 3
		chunk.mesh = stone
		chunk.material_override = rock
		chunk.position = Vector3(cos(angle) * SIZE * 0.52, 0.02, sin(angle) * SIZE * 0.42)
		chunk.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0.0)
		add_child(chunk)
	# The cracks around it.
	var cracks: Decal = Decal.new()
	cracks.texture_albedo = ImpactFx.mark_texture(&"hole_rock")
	cracks.size = Vector3(SIZE * 2.2, 0.6, SIZE * 2.2)
	cracks.modulate = Color(1, 1, 1, 0.8)
	add_child(cracks)
	# The rubble it threw out, on the floor in front of it.
	var floor_at: Vector3 = global_position + normal * 0.6
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var down: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(floor_at + Vector3.UP * 0.5, floor_at + Vector3.DOWN * 3.0, 1))
	if not down.is_empty() and absf(normal.y) < 0.7:
		for i: int in 5:
			var piece: MeshInstance3D = MeshInstance3D.new()
			var stone: SphereMesh = SphereMesh.new()
			stone.radius = rng.randf_range(0.07, 0.18)
			stone.height = stone.radius * 1.2
			stone.radial_segments = 6
			stone.rings = 3
			piece.mesh = stone
			piece.material_override = rock
			add_child(piece)
			piece.global_position = (down.position as Vector3) + Vector3(rng.randf_range(-0.6, 0.6), stone.radius * 0.4, rng.randf_range(-0.6, 0.6))
	ImpactFx.burst_rock(get_parent(), global_position + normal * 0.2, normal)
	Audio.play_at("hole_burst", global_position, &"SFX", 0.0, 40.0, randf_range(0.92, 1.05))
