class_name CelticStone
extends StaticBody3D
## A standing stone the old Celtic miners left in Die Tiefe, with spirals cut into its face
## (facing -Z). Something to hide behind from the Percht.

@export var height: float = 2.2
@export var width: float = 0.9

static var _stone: StandardMaterial3D
static var _groove: StandardMaterial3D


func _ready() -> void:
	if _stone == null:
		_stone = BodyParts.rough(Color(0.34, 0.31, 0.27), 0.92, 1.0, 0.05)
		_groove = BodyParts.rough(Color(0.12, 0.11, 0.1), 1.0, 0.3)
	var depth: float = 0.38
	var slab: MeshInstance3D = BodyParts.add(self, BodyParts.box(Vector3(width, height, depth)), _stone, Vector3.UP * height / 2.0, Vector3(0.0, 0.0, 2.5))
	slab.scale = Vector3(1.0, 1.0, 1.0)
	BodyParts.add(self, BodyParts.box(Vector3(width * 0.8, 0.25, depth * 0.95)), _stone, Vector3(0.0, height + 0.08, 0.0), Vector3(0.0, 0.0, -6.0))
	# Three spirals (rings inside rings) and a line between them.
	for spiral: Vector3 in [Vector3(-0.2, height * 0.68, 0.0), Vector3(0.2, height * 0.68, 0.0), Vector3(0.0, height * 0.42, 0.0)]:
		for ring: int in 3:
			var torus: TorusMesh = TorusMesh.new()
			torus.inner_radius = 0.05 + ring * 0.045
			torus.outer_radius = torus.inner_radius + 0.018
			torus.rings = 20
			torus.ring_segments = 4
			BodyParts.add(self, torus, _groove, spiral + Vector3(0.0, 0.0, -depth / 2.0 + 0.002), Vector3(90.0, 0.0, 0.0), Vector3(1.0, 0.2, 1.0))
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(width, height + 0.2, depth)
	shape.shape = box
	shape.position = Vector3.UP * (height + 0.2) / 2.0
	add_child(shape)
