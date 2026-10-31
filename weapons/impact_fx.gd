class_name ImpactFx
extends RefCounted
## What a hit leaves behind (DESIGN.md §10, M10), on every peer and purely cosmetic: a bullet
## hole with a ring of chipped salt, grit and a dust cloud on rock; splinters on timber; sparks
## and a ping on iron; blood splashed on the rock behind a creature and a pool where one dies.
## The surface is read from the hit body's own material (timber, iron or else rock), so chunks
## need no extra tags; a body can still say it with the meta "surface" ("wood", "metal", "rock").
## Marks are decals, at most MAX_MARKS in the world – the oldest goes first.

enum Surface { ROCK, WOOD, METAL }

const MAX_MARKS: int = 72
const RAY_MASK: int = 1  # rock and props only: marks never land on miners or creatures
const SOUNDS: PackedStringArray = ["impact_rock", "impact_wood", "impact_metal"]

static var _marks: Array[Decal] = []
static var _surfaces: Dictionary = {}  # collider instance id -> Surface
static var _textures: Dictionary = {}  # kind -> Texture2D
static var _materials: Dictionary = {}  # kind -> Material


## A shot or a pick ending at `at`, coming along `direction`. `sound` only for the first few
## pellets of a shotgun blast, so eight pellets do not make eight pings.
static func hit_surface(root: Node, at: Vector3, direction: Vector3, sound: bool) -> void:
	var hit: Dictionary = _probe(root, at - direction * 0.25, at + direction * 0.25)
	if hit.is_empty():
		return
	var normal: Vector3 = hit.normal
	var point: Vector3 = hit.position
	var surface: Surface = surface_of(hit.collider)
	match surface:
		Surface.WOOD:
			_particles(root, point, normal, _material(&"splinter"), _splinter_mesh(), 10, 2.4, 0.9, 9.0)
			_mark(root, point, normal, &"hole_wood", 0.07)
		Surface.METAL:
			_particles(root, point, normal.lerp(-direction, 0.3).normalized(), _material(&"spark"), _spark_mesh(), 14, 6.0, 0.35, 4.0)
			_spark_light(root, point + normal * 0.05)
			_mark(root, point, normal, &"dent", 0.05)
		_:
			_particles(root, point, normal, _material(&"grit"), _chip_mesh(), 12, 2.6, 0.7, 9.0)
			_dust_cloud(root, point + normal * 0.05, normal)
			_mark(root, point, normal, &"hole_rock", 0.09)
	if sound:
		Audio.play_at(SOUNDS[surface], point, &"SFX", -8.0, 28.0, randf_range(0.92, 1.08))


## A hit on a creature: its blood splashes onto the rock behind it, if there is rock close.
static func splash_behind(root: Node, at: Vector3, direction: Vector3) -> void:
	var hit: Dictionary = _probe(root, at, at + (direction + Vector3.DOWN * 0.35).normalized() * 2.2)
	if not hit.is_empty():
		_mark(root, hit.position, hit.normal, &"splat", randf_range(0.3, 0.55))


## Where a creature dies: a dark pool spreading under it.
static func pool_at(root: Node, at: Vector3, size: float) -> void:
	var hit: Dictionary = _probe(root, at + Vector3.UP * 0.6, at + Vector3.DOWN * 1.6)
	if hit.is_empty():
		return
	var mark: Decal = _mark(root, hit.position, hit.normal, &"pool", 0.1)
	if mark == null:
		return
	var grow: Tween = mark.create_tween()
	grow.tween_property(mark, "size", Vector3(size, 0.4, size), 2.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


## Grit and a dust cloud bursting off rock (a spawn hole breaking open).
static func burst_rock(root: Node, at: Vector3, normal: Vector3) -> void:
	_particles(root, at, normal, _material(&"grit"), _chip_mesh(), 40, 4.0, 1.2, 9.0)
	for i: int in 3:
		_dust_cloud(root, at + Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3)), normal)


static func mark_texture(kind: StringName) -> Texture2D:
	return _texture(kind)


## Rock, timber or iron, from the body's meta "surface" or its meshes' materials (cached).
static func surface_of(body: Object) -> Surface:
	if body == null:
		return Surface.ROCK
	var id: int = body.get_instance_id()
	if _surfaces.has(id):
		return _surfaces[id]
	var found: Surface = Surface.ROCK
	if body.has_meta(&"surface"):
		found = surface_from_name(String(body.get_meta(&"surface")))
	elif body is Node:
		found = _surface_of_meshes(body as Node)
	_surfaces[id] = found
	return found


static func surface_from_name(word: String) -> Surface:
	var lower: String = word.to_lower()
	if lower.contains("timber") or lower.contains("wood") or lower.contains("plank") or lower.contains("logs") or lower.contains("crate"):
		return Surface.WOOD
	if lower.contains("iron") or lower.contains("metal") or lower.contains("steel"):
		return Surface.METAL
	return Surface.ROCK


static func _surface_of_meshes(node: Node) -> Surface:
	var counts: Array[int] = [0, 0, 0]
	for child: Node in [node] + node.get_children():
		var mesh: MeshInstance3D = child as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		for i: int in mesh.mesh.get_surface_count():
			var material: Material = mesh.get_active_material(i)
			if material != null:
				counts[surface_from_name(material.resource_path + " " + material.resource_name)] += 1
	if counts[Surface.ROCK] > 0 and counts[Surface.ROCK] >= counts[Surface.WOOD] + counts[Surface.METAL]:
		return Surface.ROCK
	if counts[Surface.METAL] > counts[Surface.WOOD]:
		return Surface.METAL
	return Surface.WOOD if counts[Surface.WOOD] > 0 else Surface.ROCK


static func _probe(root: Node, from: Vector3, to: Vector3) -> Dictionary:
	var spatial: Node3D = root as Node3D
	if spatial == null or not spatial.is_inside_tree() or from.is_equal_approx(to):
		return {}
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, RAY_MASK)
	return spatial.get_world_3d().direct_space_state.intersect_ray(query)


## A decal lying on the surface (its projection axis, local Y, along the normal).
static func _mark(root: Node, at: Vector3, normal: Vector3, kind: StringName, size: float) -> Decal:
	while _marks.size() >= MAX_MARKS:
		var old: Decal = _marks.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var mark: Decal = Decal.new()
	mark.texture_albedo = _texture(kind)
	mark.size = Vector3(size, 0.12, size)
	mark.upper_fade = 0.3
	mark.lower_fade = 0.3
	mark.normal_fade = 0.5
	mark.cull_mask = 1
	if kind == &"splat" or kind == &"pool":
		mark.modulate = Color(0.55, 0.05, 0.04)
		mark.albedo_mix = 0.95
	root.add_child(mark)
	var up: Vector3 = normal.normalized()
	var side: Vector3 = up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var basis: Basis = Basis(side, up, side.cross(up)).rotated(up, randf() * TAU)
	mark.global_transform = Transform3D(basis, at)
	_marks.append(mark)
	return mark


static func _particles(root: Node, at: Vector3, direction: Vector3, material: Material, mesh: Mesh, amount: int, speed: float, life: float, gravity: float) -> void:
	var burst: CPUParticles3D = CPUParticles3D.new()
	burst.one_shot = true
	burst.emitting = false
	burst.amount = amount
	burst.lifetime = life
	burst.explosiveness = 0.95
	burst.direction = direction
	burst.spread = 40.0
	burst.initial_velocity_min = speed * 0.35
	burst.initial_velocity_max = speed
	burst.gravity = Vector3(0, -gravity, 0)
	burst.angular_velocity_min = -720.0
	burst.angular_velocity_max = 720.0
	burst.scale_amount_min = 0.5
	burst.scale_amount_max = 1.2
	burst.particle_flag_align_y = material == _materials.get(&"spark")
	burst.mesh = mesh
	burst.material_override = material
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(burst)
	burst.global_position = at + direction * 0.02
	burst.emitting = true
	_free_after(burst, life + 0.3)


## Salt dust hanging in the air a moment after the hit, drifting off.
static func _dust_cloud(root: Node, at: Vector3, normal: Vector3) -> void:
	var cloud: CPUParticles3D = CPUParticles3D.new()
	cloud.one_shot = true
	cloud.emitting = false
	cloud.amount = 6
	cloud.lifetime = 1.6
	cloud.explosiveness = 0.9
	cloud.direction = normal
	cloud.spread = 50.0
	cloud.initial_velocity_min = 0.2
	cloud.initial_velocity_max = 0.7
	cloud.damping_min = 0.6
	cloud.damping_max = 1.0
	cloud.gravity = Vector3(0, -0.05, 0)
	cloud.scale_amount_min = 0.12
	cloud.scale_amount_max = 0.3
	var grow: Curve = Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.0))
	cloud.scale_amount_curve = grow
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.5))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	cloud.color_ramp = fade
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	cloud.mesh = quad
	cloud.material_override = _material(&"dust")
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(cloud)
	cloud.global_position = at
	cloud.emitting = true
	_free_after(cloud, 2.0)


static func _spark_light(root: Node, at: Vector3) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.35)
	light.light_energy = 1.6
	light.omni_range = 1.8
	root.add_child(light)
	light.global_position = at
	var fade: Tween = light.create_tween()
	fade.tween_property(light, "light_energy", 0.0, 0.08)
	fade.tween_callback(light.queue_free)


static func _free_after(node: Node, seconds: float) -> void:
	var done: Tween = node.create_tween()
	done.tween_interval(seconds)
	done.tween_callback(node.queue_free)


static func _chip_mesh() -> Mesh:
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.018, 0.012, 0.015)
	return box


static func _splinter_mesh() -> Mesh:
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.008, 0.008, 0.05)
	return box


static func _spark_mesh() -> Mesh:
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.004, 0.035, 0.004)
	return box


static func _material(kind: StringName) -> Material:
	if _materials.has(kind):
		return _materials[kind]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	match kind:
		&"grit":
			m.albedo_color = Color(0.74, 0.69, 0.62)
			m.roughness = 1.0
		&"splinter":
			m.albedo_color = Color(0.52, 0.38, 0.24)
			m.roughness = 0.9
		&"spark":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.0, 0.75, 0.35)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.6, 0.2)
			m.emission_energy_multiplier = 4.0
		&"dust":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			m.vertex_color_use_as_albedo = true
			m.albedo_color = Color(0.7, 0.66, 0.6)
			m.albedo_texture = _texture(&"puff")
			m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_materials[kind] = m
	return m


## The marks' pictures, drawn once: holes with chipped rims, a dent, blood.
static func _texture(kind: StringName) -> Texture2D:
	if _textures.has(kind):
		return _textures[kind]
	var image: Image = draw_mark(kind, 64)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_textures[kind] = texture
	return texture


static func draw_mark(kind: StringName, size: int) -> Image:
	var image: Image = Image.create(size, size, true, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var lobes: PackedFloat32Array = []
	for i: int in 9:
		lobes.append(rng.randf_range(0.75, 1.25))
	var drops: Array[Vector3] = []  # x, y, radius (0..1 of the half size)
	if kind == &"splat":
		for i: int in 14:
			var angle: float = rng.randf() * TAU
			var reach: float = rng.randf_range(0.45, 0.9)
			drops.append(Vector3(cos(angle) * reach, sin(angle) * reach, rng.randf_range(0.04, 0.12)))
	var half: float = size / 2.0
	for y: int in size:
		for x: int in size:
			var p: Vector2 = Vector2((x + 0.5 - half) / half, (y + 0.5 - half) / half)
			var r: float = p.length()
			var angle: float = atan2(p.y, p.x)
			var wobble: float = lerpf(lobes[int(floor((angle + PI) / TAU * 9.0)) % 9], lobes[int(ceil((angle + PI) / TAU * 9.0)) % 9], fposmod((angle + PI) / TAU * 9.0, 1.0))
			var color: Color = Color(0, 0, 0, 0)
			match kind:
				&"hole_rock", &"hole_wood":
					var core: float = 0.22 * wobble
					var rim: float = (0.55 if kind == &"hole_rock" else 0.42) * wobble
					var crack: float = pow(absf(sin(angle * 3.5 + lobes[0] * 2.0)), 40.0) * (1.0 - r)
					if r < core:
						color = Color(0.03, 0.025, 0.02, 1.0)
					elif r < rim:
						var t: float = (r - core) / (rim - core)
						color = Color(0.1, 0.09, 0.08, lerpf(0.85, 0.0, t)) if kind == &"hole_rock" else Color(0.16, 0.1, 0.05, lerpf(0.9, 0.0, t))
					if crack > 0.25 and r < 0.9:
						color = Color(0.05, 0.045, 0.04, maxf(color.a, crack * 0.8))
				&"dent":
					if r < 0.35 * wobble:
						color = Color(0.85, 0.8, 0.72, 0.9 - r * 1.5)
					elif r < 0.6:
						color = Color(0.1, 0.08, 0.06, 0.5 * (1.0 - r / 0.6))
				&"splat":
					var blob: float = 0.38 * wobble
					var a: float = 1.0 if r < blob else 0.0
					for d: Vector3 in drops:
						if p.distance_to(Vector2(d.x, d.y)) < d.z:
							a = 1.0
					color = Color(1, 1, 1, a * 0.9)
				&"pool":
					var edge: float = 0.85 * (0.9 + 0.1 * wobble)
					color = Color(1, 1, 1, clampf((edge - r) * 12.0, 0.0, 0.92))
				&"puff":
					color = Color(1, 1, 1, clampf(1.0 - r, 0.0, 1.0) ** 2)
			image.set_pixel(x, y, color)
	image.generate_mipmaps()
	return image
