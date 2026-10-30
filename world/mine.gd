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
## The track along the main path (null where the section has none).
var rails: RailLine
## Firedamp, brine and rockfalls (DESIGN.md §4).
var hazards: Hazards
var seed_value: int = 0


func build(new_seed: int, params: MineParams, new_chunk_set: ChunkSet) -> void:
	seed_value = new_seed
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
	_build_walls()
	if chunk_set.has_rails:
		_build_rails()


## Places the hazards for this shift and section (after build).
func add_hazards(shift: int, rule: BiomeRule) -> void:
	hazards = Hazards.new()
	hazards.name = "Hazards"
	add_child(hazards)
	hazards.build(self, shift, rule)


func cell_centre(cell: Vector2i) -> Vector3:
	return Vector3(cell.x, 0.0, cell.y) * chunk_set.cell_size


## The salt walls from the layout, each across the passage between two cells, with the waypoint
## there switched off until it is broken.
func _build_walls() -> void:
	for wall: Vector3i in layout.walls:
		var cell: Vector2i = Vector2i(wall.x, wall.y)
		var dir: int = wall.z
		var offset: Vector2i = GridDir.offset(dir)
		var at: Vector3 = cell_centre(cell) + Vector3(offset.x, 0.0, offset.y) * chunk_set.cell_size * 0.5
		at += CaveMesher.wander(at, seed_value)
		var breakable: Breakable = Breakable.new()
		breakable.name = "Wall_%d_%d_%d" % [wall.x, wall.y, wall.z]
		breakable.size = Vector3(chunk_set.passage_size.x + 2.2, chunk_set.passage_size.y + 1.0, 0.7)
		breakable.rotation.y = 0.0 if offset.x == 0 else PI / 2.0
		breakable.position = at - Vector3.UP * 0.2
		add_child(breakable)
		var closest: int = nav.get_closest_point(at)
		if nav.get_point_position(closest).distance_to(at) < 2.5:
			nav.set_point_disabled(closest, true)
			breakable.nav_point = closest


## The track from just outside the Förderkorb along the main path, until a chunk that takes no
## rails. Decorative rails and carts of those chunks make way for it.
func _build_rails() -> void:
	var anchor: Marker3D = station.find_child("LiftAnchor", true, false) as Marker3D
	var corners: PackedVector3Array = [anchor.global_position + anchor.global_basis.z * -(Foerderkorb.HALF_WIDTH + 1.0)]
	var path: Array[Vector2i] = layout.main_path
	for i: int in path.size():
		var cell: Vector2i = path[i]
		var entry: ChunkEntry = chunk_set.entries[layout.chunk_index[cell]]
		if i > 0:
			if not entry.rails:
				break
			corners.append(cell_centre(cell))
			_clear_decorative_rails(chunks[cell])
		if i < path.size() - 1:
			var next_entry: ChunkEntry = chunk_set.entries[layout.chunk_index[path[i + 1]]]
			if next_entry.rails or i == 0:
				corners.append((cell_centre(cell) + cell_centre(path[i + 1])) / 2.0)
			if not next_entry.rails:
				break
	if corners.size() < 2:
		return
	rails = RailLine.new()
	rails.name = "Rails"
	add_child(rails)
	rails.build(corners, seed_value)


static func _clear_decorative_rails(chunk: Chunk) -> void:
	var props: Node = chunk.find_child("Props", false)
	if props == null:
		return
	for prop: Node in props.get_children():
		if prop.name.begins_with("Rails") or prop.name == "Cart":
			prop.queue_free()


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


## Waypoints: every chunk links its nav points to its centre point ("Nav_C"), or to the point
## named in their `link` metadata (paths around a lake); points at the same spot (the shared
## edge of two chunks) are merged.
func _build_nav() -> void:
	var id_of: Dictionary = {}
	for cell: Vector2i in layout.cells:
		var chunk: Chunk = chunks[cell]
		var ids: Dictionary = {}  # marker name -> point id
		var links: Array[Array] = []  # [point id, name of the point it links to]
		for marker: Marker3D in chunk.markers(&"nav_point"):
			var key: Vector3i = Vector3i((marker.global_position * 4.0).round())
			if not id_of.has(key):
				var new_id: int = nav.get_available_point_id()
				nav.add_point(new_id, marker.global_position)
				id_of[key] = new_id
			ids[String(marker.name)] = id_of[key]
			if marker.name != "Nav_C":
				links.append([id_of[key], str(marker.get_meta(&"link", "Nav_C"))])
		assert(ids.has("Nav_C"), "%s has no Nav_C" % chunk.name)
		for link: Array in links:
			nav.connect_points(link[0], ids.get(link[1], ids["Nav_C"]))


func nav_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	return nav.get_point_path(nav.get_closest_point(from), nav.get_closest_point(to))
