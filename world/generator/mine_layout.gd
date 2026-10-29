class_name MineLayout
extends RefCounted
## The generated mine as data: which grid cells exist, how they connect, which chunk sits in
## each cell and how it is turned. Built identically on every peer from the same seed.

## Vector2i -> int (GridDir mask of open sides)
var cells: Dictionary = {}
var start: Vector2i = Vector2i.ZERO
## The main path from the start, in order (the "spine" of the mine).
var main_path: Array[Vector2i] = []
## Vector2i -> int, steps from the start along open connections.
var depth: Dictionary = {}
## Vector2i -> int, index into the ChunkSet entries.
var chunk_index: Dictionary = {}
## Vector2i -> int, quarter turns clockwise.
var chunk_rotation: Dictionary = {}
## Salt walls closing a passage: Vector3i(cell.x, cell.y, dir) for the side of cell they close.
var walls: Array[Vector3i] = []


func has_cell(cell: Vector2i) -> bool:
	return cells.has(cell)


func add_cell(cell: Vector2i) -> void:
	if not cells.has(cell):
		cells[cell] = 0


func connect_cells(cell: Vector2i, dir: int) -> void:
	var other: Vector2i = cell + GridDir.offset(dir)
	add_cell(cell)
	add_cell(other)
	cells[cell] = int(cells[cell]) | dir
	cells[other] = int(cells[other]) | GridDir.opposite(dir)


func is_open(cell: Vector2i, dir: int) -> bool:
	return cells.has(cell) and (int(cells[cell]) & dir) != 0


func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir: int in GridDir.ALL:
		if is_open(cell, dir):
			result.append(cell + GridDir.offset(dir))
	return result


## Steps from the start to every reachable cell (breadth-first).
func compute_depth() -> void:
	depth.clear()
	depth[start] = 0
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for next: Vector2i in neighbors(cell):
			if not depth.has(next):
				depth[next] = int(depth[cell]) + 1
				queue.append(next)


func max_depth() -> int:
	var deepest: int = 0
	for value: int in depth.values():
		deepest = maxi(deepest, value)
	return deepest


## A text fingerprint of the whole layout, for "same seed, same mine" checks.
func signature() -> String:
	var parts: PackedStringArray = []
	for cell: Vector2i in cells:
		parts.append("%d,%d:%d:%d:%d" % [cell.x, cell.y, cells[cell], chunk_index.get(cell, -1), chunk_rotation.get(cell, 0)])
	for wall: Vector3i in walls:
		parts.append("w%d,%d,%d" % [wall.x, wall.y, wall.z])
	return ";".join(parts)
