class_name SaltColumn
extends StaticBody3D
## A pillar of rock salt left standing in a big cavern, slightly waisted, floor to roof.

@export var height: float = 8.0
@export var radius: float = 0.9


func _ready() -> void:
	var rock: Material = load("res://assets/materials/salt_rock.tres") as Material
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var column: CylinderMesh = CylinderMesh.new()
	column.top_radius = radius * 1.35
	column.bottom_radius = radius * 1.25
	column.height = height
	column.radial_segments = 14
	column.rings = 6
	mesh.mesh = column
	mesh.material_override = rock
	mesh.position = Vector3.UP * height / 2.0
	add_child(mesh)
	var waist: MeshInstance3D = MeshInstance3D.new()
	var middle: CylinderMesh = CylinderMesh.new()
	middle.top_radius = radius * 1.3
	middle.bottom_radius = radius * 1.3
	middle.height = height * 0.3
	middle.radial_segments = 12
	waist.mesh = middle
	waist.material_override = rock
	waist.scale = Vector3(0.8, 1.0, 0.8)
	waist.position = Vector3.UP * height * 0.5
	add_child(waist)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = radius * 1.25
	cylinder.height = height
	shape.shape = cylinder
	shape.position = Vector3.UP * height / 2.0
	add_child(shape)
