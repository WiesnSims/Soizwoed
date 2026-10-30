class_name SaltMan
extends StaticBody3D
## The "Mann im Salz" (DESIGN.md §4): the body of a Celtic miner, kept for two and a half
## thousand years by the salt, standing half inside a wall of rock salt (his face to -Z). One
## of his arms is gone – that piece lies in front of him as loot (a "relic_spawn" marker).

const SALT_MATERIAL: String = "res://items/salt_block_material.tres"


func _ready() -> void:
	var salt: Material = load(SALT_MATERIAL) as Material
	var skin: StandardMaterial3D = BodyParts.rough(Color(0.22, 0.13, 0.08), 0.55, 1.0, 0.12)
	skin.clearcoat_enabled = true
	skin.clearcoat_roughness = 0.5
	var cloth: StandardMaterial3D = BodyParts.rough(Color(0.27, 0.22, 0.15), 1.0, 0.8, 0.2)
	# The wall of salt he is stuck in, crystals catching the lamp light.
	BodyParts.add(self, BodyParts.box(Vector3(2.6, 3.0, 0.9)), salt, Vector3(0.0, 1.5, 0.35))
	for crystal: Vector3 in [Vector3(-1.0, 0.4, -0.15), Vector3(0.9, 2.3, -0.12), Vector3(1.05, 0.7, -0.1), Vector3(-0.85, 2.5, -0.12)]:
		BodyParts.add(self, BodyParts.box(Vector3(0.35, 0.5, 0.35)), salt, crystal, Vector3(20.0, 35.0, 15.0))
	# Him: leaning back into the salt, head bowed.
	var body: Node3D = Node3D.new()
	body.position = Vector3(0.0, 0.0, -0.12)
	body.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
	add_child(body)
	BodyParts.add(body, BodyParts.capsule(0.2, 0.85), cloth, Vector3(0.0, 1.35, 0.0))
	BodyParts.add(body, BodyParts.capsule(0.17, 0.75), skin, Vector3(0.0, 1.4, 0.04))
	var skull: MeshInstance3D = BodyParts.add(body, BodyParts.sphere(0.12, 16), skin, Vector3(0.0, 1.93, -0.03), Vector3(18.0, 0.0, 6.0))
	skull.scale = Vector3(0.9, 1.05, 1.0)
	var dark: StandardMaterial3D = BodyParts.rough(Color(0.03, 0.02, 0.02), 1.0, 0.0)
	for side: float in [-1.0, 1.0]:
		BodyParts.add(body, BodyParts.sphere(0.025, 8), dark, Vector3(side * 0.045, 1.95, -0.13))
		BodyParts.add(body, BodyParts.capsule(0.07, 0.85), skin, Vector3(side * 0.12, 0.55, 0.0))  # legs
	BodyParts.add(body, BodyParts.capsule(0.055, 0.7), skin, Vector3(0.27, 1.25, -0.02), Vector3(0.0, 0.0, 8.0))  # the arm he kept
	BodyParts.add(body, BodyParts.cylinder(0.06, 0.07, 0.12), skin, Vector3(-0.26, 1.55, -0.02), Vector3(0.0, 0.0, -30.0))  # the stump
	# His leather cap and the scraps of a Tragsack on his back.
	BodyParts.add(body, BodyParts.cylinder(0.1, 0.13, 0.1), cloth, Vector3(0.0, 2.04, -0.02), Vector3(18.0, 0.0, 0.0))
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2.6, 3.0, 1.1)
	shape.shape = box
	shape.position = Vector3(0.0, 1.5, 0.25)
	add_child(shape)
	BodyParts.no_shadows(body)
