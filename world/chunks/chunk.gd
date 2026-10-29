class_name Chunk
extends Node3D
## One hand-made piece of the mine. Children named with a _N/_E/_S/_W suffix (cave boxes,
## timbering, nav points, ...) belong to that opening and are removed when the opening is
## not used. Cave boxes under `Cave` become the rock mesh; markers in the groups
## "loot_spawn" / "enemy_spawn" / "nav_point" are read by the Mine.

const ROCK_MATERIAL: Material = preload("res://assets/materials/salt_rock.tres")
const FLOOR_MATERIAL: Material = preload("res://assets/materials/mine_floor.tres")

var cell: Vector2i


## Removes everything that belongs to openings outside `world_mask` (given in world directions).
func setup(world_mask: int, rotation_steps: int) -> void:
	var local_mask: int = GridDir.rotate_mask(world_mask, -rotation_steps)
	var closed: PackedStringArray = []
	for dir: int in GridDir.ALL:
		if not (local_mask & dir):
			closed.append("_" + GridDir.suffix(dir))
	_remove_closed(self, closed)


## Builds the rock mesh and its collision. Needs the final global transform.
func build_cave(half_cell: float, seed_value: int) -> void:
	var boxes: Array[AABB] = []
	for box: Node in find_child("Cave", false).get_children():
		if box is CaveBox:
			boxes.append((box as CaveBox).local_aabb(self))
	var result: CaveMesher.Result = CaveMesher.build(boxes, global_transform, half_cell, seed_value)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "RockMesh"
	mesh_instance.mesh = result.mesh
	for surface: int in result.mesh.get_surface_count():
		var is_floor: bool = result.mesh.surface_get_name(surface) == "floor"
		mesh_instance.set_surface_override_material(surface, FLOOR_MATERIAL if is_floor else ROCK_MATERIAL)
	add_child(mesh_instance)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "RockBody"
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.set_faces(result.collision_faces)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	_follow_walls(seed_value)


## Props and markers move with the walls' slow wander so they stay where they were placed
## relative to the rock (the same function moves the rock, so both chunks at a border agree).
func _follow_walls(seed_value: int) -> void:
	for group_name: String in ["Props", "Markers"]:
		var group: Node = find_child(group_name, false)
		if group == null:
			continue
		for child: Node in group.get_children():
			var node: Node3D = child as Node3D
			if node != null:
				node.global_position += CaveMesher.wander(node.global_position, seed_value)


func markers(group: StringName) -> Array[Marker3D]:
	var result: Array[Marker3D] = []
	for node: Node in find_children("*", "Marker3D", true, false):
		if node.is_in_group(group):
			result.append(node as Marker3D)
	return result


static func _remove_closed(node: Node, closed: PackedStringArray) -> void:
	for child: Node in node.get_children():
		var name_text: String = child.name
		var remove: bool = false
		for suffix: String in closed:
			if name_text.ends_with(suffix):
				remove = true
		if remove:
			node.remove_child(child)
			child.free()
		else:
			_remove_closed(child, closed)
