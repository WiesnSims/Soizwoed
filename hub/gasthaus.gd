class_name Gasthaus
extends Node3D
## The hub: the wood-panelled Gasthaus "Zum Salzstock" with the shop counter, the notice board
## with the quota, the stove, the Herrgottswinkel and the Förderkorb down into the mine
## (DESIGN.md §10). The room is built from boxes here; placed things live in gasthaus.tscn.
## The room's floor centre is the node's origin; the cage stands at the south wall.

const LOGS: Material = preload("res://assets/materials/hub_logs.tres")
const PLANKS: Material = preload("res://assets/materials/hub_planks.tres")
const FLOOR: Material = preload("res://assets/materials/hub_floor.tres")
const PLASTER: Material = preload("res://assets/materials/hub_plaster.tres")
const TIMBER: Material = preload("res://assets/materials/timber_wood.tres")
const IRON: Material = preload("res://assets/materials/rust_iron.tres")
const HALF_X: float = 8.0
const HALF_Z: float = 6.0
const HEIGHT: float = 3.6
const WALL: float = 0.3

@onready var menu_camera: Camera3D = $MenuCamera
@onready var board_text: Label3D = $Board/Text

var _body: StaticBody3D
## The Grubnplan beside the notice board: which mine section the crew rides down into.
var _plan: Label3D


func _ready() -> void:
	_body = StaticBody3D.new()
	_body.name = "Room"
	add_child(_body)
	_build_plan()
	_build_shell()
	_build_counter()
	_build_tables()
	_build_stove()
	_build_corner()
	_build_shaft_frame()
	menu_camera.look_at_from_position(to_global(Vector3(7.2, 2.3, 5.2)), to_global(Vector3(-2.5, 1.0, -1.0)))
	update_board({})


func player_spot(index: int) -> Transform3D:
	var local: Vector3 = Vector3(-1.2 + (index % 4) * 0.8, 0.1, 1.2)
	return global_transform * Transform3D(Basis.IDENTITY, local)


func counter_spot() -> Transform3D:
	var local: Vector3 = Vector3(-5.1, 0.4, -0.5 + randf_range(-1.5, 1.5))
	return global_transform * Transform3D(Basis(Vector3.UP, randf_range(-0.4, 0.4)), local)


func free_cart_spot() -> Transform3D:
	return global_transform * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(2.6, 0.3, 3.4))


## The notice board shows the quota of the current cycle (DESIGN.md §10).
func update_board(info: Dictionary) -> void:
	if info.is_empty():
		board_text.text = tr("BOARD_TITLE")
		return
	board_text.text = "%s\n\n%s\n%s\n%s\n%s" % [
		tr("BOARD_TITLE"),
		tr("BOARD_CYCLE") % (int(info.cycle) + 1),
		tr("BOARD_QUOTA") % int(info.quota),
		tr("BOARD_MONEY") % int(info.money),
		tr("BOARD_SHIFTS") % int(info.shifts_left),
	]
	if _plan != null:
		var section: ChunkSet = Game.BIOMES[clampi(int(info.get("section", 0)), 0, Game.BIOMES.size() - 1)]
		_plan.text = "%s\n\n%s" % [tr("PLAN_TITLE"), tr("PLAN_TODAY") % tr(section.biome_name_key)]


# --- building ---------------------------------------------------------------------------------------

## A yellowed mine plan pinned to the wall right of the notice board; E opens the section list.
func _build_plan() -> void:
	var paper: StandardMaterial3D = StandardMaterial3D.new()
	paper.albedo_color = Color(0.78, 0.7, 0.52)
	paper.roughness = 0.9
	var plan: SectionPlan = SectionPlan.new()
	plan.name = "Plan"
	plan.position = Vector3(1.4, 1.7, -HALF_Z + 0.05)
	add_child(plan)
	var sheet: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(1.3, 0.9, 0.02)
	sheet.mesh = box
	sheet.material_override = paper
	plan.add_child(sheet)
	_plan = Label3D.new()
	_plan.text = tr("PLAN_TITLE")
	_plan.font_size = 32
	_plan.pixel_size = 0.0035
	_plan.modulate = Color(0.2, 0.14, 0.08)
	_plan.outline_size = 0
	_plan.position = Vector3(0.0, 0.0, 0.02)
	plan.add_child(_plan)


class SectionPlan:
	extends StaticBody3D

	func _ready() -> void:
		collision_layer = 16
		collision_mask = 0
		var shape: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(1.3, 0.9, 0.1)
		shape.shape = box
		add_child(shape)

	func interaction_text(_player: Player) -> String:
		return tr("PROMPT_PLAN") if Game.instance.phase == Game.Phase.HUB else ""

	func interact(_player: Player) -> void:
		Game.instance.hud.open_sections()

func _build_shell() -> void:
	_box(Vector3(HALF_X * 2.0, 0.2, HALF_Z * 2.0), Vector3(0, -0.1, 0), FLOOR)
	_box(Vector3(HALF_X * 2.0, 0.2, HALF_Z * 2.0), Vector3(0, HEIGHT + 0.1, 0), PLANKS)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(HALF_X * 2.0 + WALL * 2.0, HEIGHT, WALL), Vector3(0, HEIGHT / 2.0, side * (HALF_Z + WALL / 2.0)), LOGS)
		_box(Vector3(WALL, HEIGHT, HALF_Z * 2.0), Vector3(side * (HALF_X + WALL / 2.0), HEIGHT / 2.0, 0), LOGS)
	# Ceiling beams.
	for x: float in [-6.0, -3.0, 0.0, 3.0, 6.0]:
		_box(Vector3(0.22, 0.26, HALF_Z * 2.0), Vector3(x, HEIGHT - 0.13, 0), TIMBER, false)
	# Plastered strip behind the stove and windows into the night.
	_box(Vector3(3.2, HEIGHT, 0.04), Vector3(6.2, HEIGHT / 2.0, -HALF_Z + 0.02), PLASTER, false)
	for x: float in [-4.5, 2.5]:
		_window(Vector3(x, 1.9, -HALF_Z + 0.03))
	# A door to the outside (closed: the only way is down).
	_box(Vector3(0.08, 2.1, 1.1), Vector3(HALF_X - 0.04, 1.05, 3.0), TIMBER, false)
	_box(Vector3(0.1, 0.06, 0.06), Vector3(HALF_X - 0.1, 1.05, 2.6), IRON, false)


func _window(at: Vector3) -> void:
	var night: StandardMaterial3D = StandardMaterial3D.new()
	night.albedo_color = Color(0.02, 0.03, 0.06)
	night.emission_enabled = true
	night.emission = Color(0.1, 0.16, 0.32)
	night.emission_energy_multiplier = 0.35
	_box(Vector3(1.2, 1.0, 0.02), at, night, false)
	_box(Vector3(1.36, 0.08, 0.08), at + Vector3(0, 0.54, 0.03), TIMBER, false)
	_box(Vector3(1.36, 0.08, 0.08), at + Vector3(0, -0.54, 0.03), TIMBER, false)
	_box(Vector3(0.06, 1.0, 0.06), at + Vector3(0, 0, 0.03), TIMBER, false)
	_box(Vector3(1.2, 0.05, 0.06), at + Vector3(0, 0, 0.03), TIMBER, false)


func _build_counter() -> void:
	_box(Vector3(1.0, 1.1, 5.0), Vector3(-6.3, 0.55, -0.5), PLANKS)
	_box(Vector3(1.25, 0.07, 5.3), Vector3(-6.25, 1.135, -0.5), TIMBER, false)
	# Shelves with bottles behind the counter.
	var glass: StandardMaterial3D = StandardMaterial3D.new()
	glass.albedo_color = Color(0.16, 0.3, 0.12, 0.85)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 0.9
	var bottle: CylinderMesh = CylinderMesh.new()
	bottle.top_radius = 0.03
	bottle.bottom_radius = 0.045
	bottle.height = 0.3
	bottle.radial_segments = 10
	for shelf_y: float in [1.5, 2.1]:
		_box(Vector3(0.35, 0.05, 4.0), Vector3(-HALF_X + 0.18, shelf_y, -0.5), TIMBER, false)
		for i: int in 9:
			var mesh: MeshInstance3D = MeshInstance3D.new()
			mesh.mesh = bottle
			mesh.material_override = glass
			mesh.position = Vector3(-HALF_X + 0.18, shelf_y + 0.175, -2.3 + i * 0.45 + fmod(shelf_y * 7.0, 0.2))
			add_child(mesh)


func _build_tables() -> void:
	for z: float in [-3.2, 0.6]:
		var at: Vector3 = Vector3(4.2, 0, z)
		_box(Vector3(2.2, 0.08, 1.0), at + Vector3(0, 0.78, 0), PLANKS)
		for corner: Vector3 in [Vector3(-0.95, 0, -0.38), Vector3(0.95, 0, -0.38), Vector3(-0.95, 0, 0.38), Vector3(0.95, 0, 0.38)]:
			_box(Vector3(0.08, 0.74, 0.08), at + corner + Vector3(0, 0.37, 0), TIMBER, false)
		for side: float in [-1.0, 1.0]:
			_box(Vector3(2.2, 0.06, 0.32), at + Vector3(0, 0.45, side * 0.85), PLANKS)
			_box(Vector3(2.0, 0.42, 0.06), at + Vector3(0, 0.21, side * 0.85), TIMBER, false)


func _build_stove() -> void:
	var tiles: StandardMaterial3D = StandardMaterial3D.new()
	tiles.albedo_color = Color(0.13, 0.24, 0.17)
	tiles.roughness = 0.25
	tiles.clearcoat_enabled = true
	var at: Vector3 = Vector3(6.4, 0, -4.6)
	_box(Vector3(1.6, 1.3, 1.5), at + Vector3(0, 0.65, 0), tiles)
	_box(Vector3(1.3, 0.8, 1.2), at + Vector3(0, 1.7, 0), tiles)
	_box(Vector3(1.8, 0.08, 1.7), at + Vector3(0, 1.3, 0), TIMBER, false)
	var ember: StandardMaterial3D = StandardMaterial3D.new()
	ember.albedo_color = Color(0.1, 0.04, 0.02)
	ember.emission_enabled = true
	ember.emission = Color(1.0, 0.38, 0.1)
	ember.emission_energy_multiplier = 3.0
	_box(Vector3(0.45, 0.3, 0.02), at + Vector3(-0.3, 0.45, 0.76), ember, false)
	# A bench around the stove.
	_box(Vector3(0.4, 0.45, 2.4), at + Vector3(-1.1, 0.225, 1.0), PLANKS)


func _build_corner() -> void:
	# Herrgottswinkel: a corner shelf with a cross and a little red light.
	var at: Vector3 = Vector3(HALF_X - 0.35, 0, HALF_Z - 0.35) * Vector3(1, 0, -1)
	_box(Vector3(0.5, 0.04, 0.5), at + Vector3(0, 2.2, 0), TIMBER, false)
	_box(Vector3(0.05, 0.6, 0.04), at + Vector3(0, 2.62, 0), TIMBER, false)
	_box(Vector3(0.32, 0.05, 0.04), at + Vector3(0, 2.75, 0), TIMBER, false)


func _build_shaft_frame() -> void:
	# The heavy timber frame around the Förderkorb.
	var cage_at: Vector3 = ($Foerderkorb as Node3D).position
	for x: float in [-1.75, 1.75]:
		_box(Vector3(0.3, HEIGHT, 0.3), cage_at + Vector3(x, HEIGHT / 2.0, -1.6), TIMBER)
	_box(Vector3(3.8, 0.35, 0.3), cage_at + Vector3(0, HEIGHT - 0.3, -1.6), TIMBER, false)


func _box(size: Vector3, at: Vector3, material: Material, collide: bool = true) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	add_child(instance)
	if collide:
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = size
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.shape = shape
		collision.position = at
		_body.add_child(collision)
	return instance
