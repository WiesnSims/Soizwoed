class_name Cosmetics
extends RefCounted
## What the Knappenbrief's cosmetics look like (DESIGN.md §7): hats others see on your head.
## Built per peer from the hat's id; nothing about them is networked but the id.

const GAMSBART_SCENE: String = "res://items/scenes/gamsbarthut.tscn"


## The hat `kind` (a HAT perk's target) as plain meshes, sitting on the head's hat point.
static func build_hat(kind: StringName) -> Node3D:
	var hat: Node3D = Node3D.new()
	hat.name = "CosmeticHat"
	match kind:
		&"gamsbart":
			# The same hat as the loot, without its body: only the meshes.
			var scene: PackedScene = load(GAMSBART_SCENE) as PackedScene
			var source: Node = scene.instantiate()
			for child: Node in source.get_children():
				if child is MeshInstance3D:
					var mesh: MeshInstance3D = (child as MeshInstance3D).duplicate() as MeshInstance3D
					hat.add_child(mesh)
			source.free()
		&"knappe":
			_knappenhut(hat)
	for child: Node in hat.get_children():
		(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return hat


## The miners' parade hat (Schachthut): a tall black felt crown, a narrow brim, a gold badge
## with hammer and pick and a green-white plume.
static func _knappenhut(hat: Node3D) -> void:
	var felt: StandardMaterial3D = StandardMaterial3D.new()
	felt.albedo_color = Color(0.05, 0.05, 0.055)
	felt.roughness = 0.95
	var gold: StandardMaterial3D = StandardMaterial3D.new()
	gold.albedo_color = Color(0.85, 0.66, 0.25)
	gold.metallic = 0.9
	gold.roughness = 0.3
	var plume: StandardMaterial3D = StandardMaterial3D.new()
	plume.albedo_color = Color(0.18, 0.45, 0.2)
	plume.roughness = 1.0
	var white: StandardMaterial3D = StandardMaterial3D.new()
	white.albedo_color = Color(0.9, 0.9, 0.86)
	white.roughness = 1.0
	_cylinder(hat, 0.16, 0.16, 0.02, Vector3(0, 0.01, 0), felt)
	_cylinder(hat, 0.095, 0.11, 0.2, Vector3(0, 0.11, 0), felt)
	var badge: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.05, 0.05, 0.01)
	badge.mesh = box
	badge.material_override = gold
	badge.position = Vector3(0, 0.13, -0.105)
	badge.rotation.z = PI / 4.0
	hat.add_child(badge)
	_cylinder(hat, 0.035, 0.012, 0.16, Vector3(0, 0.27, 0.0), plume)
	_cylinder(hat, 0.022, 0.006, 0.1, Vector3(0, 0.33, 0.0), white)


static func _cylinder(parent: Node3D, top: float, bottom: float, height: float, at: Vector3, material: Material) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 16
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
