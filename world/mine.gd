class_name Mine
extends Node3D
## A generated mine: chunks placed from a MineLayout, plus a waypoint graph for creatures.
## Built locally on every peer from the same seed; spawned things come from the host.

var layout: MineLayout
var chunk_set: ChunkSet
var chunks: Dictionary = {}  # Vector2i -> Chunk
var nav: AStar3D = AStar3D.new()
var station: Chunk
## The lanterns hanging in the mine (their light freezes the Kasermandl).
var lights: Array[OmniLight3D] = []


func build(seed_value: int, params: MineParams, new_chunk_set: ChunkSet) -> void:
	chunk_set = new_chunk_set
	layout = MineGenerator.generate(seed_value, params, chunk_set)
	var half_cell: float = chunk_set.cell_size / 2.0
	for cell: Vector2i in layout.cells:
		var entry: ChunkEntry = chunk_set.entries[layout.chunk_index[cell]]
		var chunk: Chunk = entry.scene.instantiate() as Chunk
		var steps: int = layout.chunk_rotation[cell]
		chunk.name = "Chunk_%d_%d" % [cell.x, cell.y]
		chunk.cell = cell
		chunk.position = Vector3(cell.x, 0.0, cell.y) * chunk_set.cell_size
		chunk.rotation.y = GridDir.rotation_y(steps)
		chunk.setup(layout.cells[cell], steps)
		add_child(chunk)
		chunk.build_cave(half_cell, seed_value)
		chunks[cell] = chunk
		if cell == layout.start:
			station = chunk
	for node: Node in find_children("*", "OmniLight3D", true, false):
		lights.append(node as OmniLight3D)
	_build_nav()


func cell_depth(chunk: Chunk) -> int:
	return int(layout.depth.get(chunk.cell, 0))


## All markers of a group with the depth of the chunk they are in: [[Marker3D, depth], ...]
## in a stable order (same on every peer).
func markers_with_depth(group: StringName) -> Array[Array]:
	var result: Array[Array] = []
	for cell: Vector2i in layout.cells:
		var chunk: Chunk = chunks[cell]
		for marker: Marker3D in chunk.markers(group):
			result.append([marker, int(layout.depth.get(cell, 0))])
	return result


## Waypoints: every chunk links its nav points to its centre point ("Nav_C"); points at
## the same spot (the shared edge of two chunks) are merged.
func _build_nav() -> void:
	var id_of: Dictionary = {}
	for cell: Vector2i in layout.cells:
		var chunk: Chunk = chunks[cell]
		var centre_id: int = -1
		var others: Array[int] = []
		for marker: Marker3D in chunk.markers(&"nav_point"):
			var key: Vector3i = Vector3i((marker.global_position * 4.0).round())
			if not id_of.has(key):
				var new_id: int = nav.get_available_point_id()
				nav.add_point(new_id, marker.global_position)
				id_of[key] = new_id
			if marker.name == "Nav_C":
				centre_id = id_of[key]
			else:
				others.append(id_of[key])
		assert(centre_id >= 0, "%s has no Nav_C" % chunk.name)
		for other: int in others:
			nav.connect_points(centre_id, other)


func nav_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	return nav.get_point_path(nav.get_closest_point(from), nav.get_closest_point(to))
