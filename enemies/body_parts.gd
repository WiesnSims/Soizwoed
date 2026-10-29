class_name BodyParts
extends RefCounted
## Small helpers to build creature bodies from primitive meshes in code (the Bergmandl's body is
## laid out by hand in its scene; the M4 creatures are put together here).


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return mesh


static func sphere(radius: float, segments: int = 24) -> SphereMesh:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = segments / 2
	return mesh


static func cylinder(top: float, bottom: float, height: float, segments: int = 16) -> CylinderMesh:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


static func box(size: Vector3) -> BoxMesh:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return mesh


static func add(parent: Node3D, mesh: Mesh, material: Material, at: Vector3, rotation_deg: Vector3 = Vector3.ZERO,
		scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.rotation_degrees = rotation_deg
	instance.scale = scale
	parent.add_child(instance)
	return instance


## A rough, lit material with a noise bump (skin, cloth, scales).
static func rough(color: Color, roughness: float = 0.8, bump: float = 0.5, noise_scale: float = 0.08) -> StandardMaterial3D:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.frequency = noise_scale
	var bumps: NoiseTexture2D = NoiseTexture2D.new()
	bumps.width = 256
	bumps.height = 256
	bumps.seamless = true
	bumps.as_normal_map = true
	bumps.bump_strength = 6.0
	bumps.noise = noise
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.normal_enabled = bump > 0.0
	material.normal_scale = bump
	material.normal_texture = bumps
	return material


## A see-through glowing material for ghosts; fade it with `albedo_color.a`.
static func ghost(color: Color, glow: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = glow
	material.roughness = 1.0
	material.rim_enabled = true
	material.rim = 0.8
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## Glowing eyes.
static func glow(color: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


## No creature body part casts a shadow of its own (ghosts never; the rest keeps the lamp light clean).
static func no_shadows(root: Node) -> void:
	for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
