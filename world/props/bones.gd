class_name Bones
extends Node3D
## Old bones on the floor of Die Tiefe: long bones, a few ribs and (maybe) a skull, scattered
## the same way on every peer (`seed_value`). Decoration only, no collision.

@export var seed_value: int = 1
@export var count: int = 6
@export var skull: bool = true
@export var spread: float = 0.7

## Shared by every pile (one noise texture, not one per chunk).
static var _bone: StandardMaterial3D
static var _dark: StandardMaterial3D


func _ready() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	if _bone == null:
		_bone = BodyParts.rough(Color(0.72, 0.66, 0.54), 0.85, 0.6, 0.15)
		_dark = BodyParts.rough(Color(0.05, 0.04, 0.03), 1.0, 0.0)
	var bone: StandardMaterial3D = _bone
	for i: int in count:
		var at: Vector3 = Vector3(rng.randf_range(-spread, spread), 0.03, rng.randf_range(-spread, spread))
		var turn: Vector3 = Vector3(90.0, rng.randf_range(0.0, 360.0), rng.randf_range(-10.0, 10.0))
		if rng.randf() < 0.6:
			# A long bone with knobbly ends.
			var length: float = rng.randf_range(0.25, 0.45)
			var piece: Node3D = Node3D.new()
			add_child(piece)
			piece.position = at
			piece.rotation_degrees = turn
			BodyParts.add(piece, BodyParts.cylinder(0.018, 0.022, length, 8), bone, Vector3.ZERO)
			for end: float in [-0.5, 0.5]:
				BodyParts.add(piece, BodyParts.sphere(0.032, 8), bone, Vector3(0.0, end * length, 0.0))
		else:
			# A curved rib.
			var rib: MeshInstance3D = BodyParts.add(self, _rib_mesh(), bone, at + Vector3.UP * 0.02, Vector3(0.0, turn.y, 0.0))
			rib.scale = Vector3.ONE * rng.randf_range(0.8, 1.2)
	if skull:
		var head: Node3D = Node3D.new()
		add_child(head)
		head.position = Vector3(rng.randf_range(-spread, spread) * 0.5, 0.09, rng.randf_range(-spread, spread) * 0.5)
		head.rotation_degrees = Vector3(rng.randf_range(-20.0, 10.0), rng.randf_range(0.0, 360.0), rng.randf_range(-25.0, 25.0))
		var cranium: MeshInstance3D = BodyParts.add(head, BodyParts.sphere(0.1, 16), bone, Vector3.ZERO)
		cranium.scale = Vector3(0.9, 0.95, 1.1)
		BodyParts.add(head, BodyParts.box(Vector3(0.11, 0.06, 0.08)), bone, Vector3(0.0, -0.08, -0.06))  # jaw
		var dark: StandardMaterial3D = _dark
		for side: float in [-1.0, 1.0]:
			BodyParts.add(head, BodyParts.sphere(0.026, 8), dark, Vector3(side * 0.04, 0.0, -0.085))
		BodyParts.add(head, BodyParts.sphere(0.015, 6), dark, Vector3(0.0, -0.04, -0.1))


static func _rib_mesh() -> TorusMesh:
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.13
	torus.outer_radius = 0.15
	torus.rings = 10
	torus.ring_segments = 5
	return torus
