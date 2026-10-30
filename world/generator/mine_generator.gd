class_name MineGenerator
extends RefCounted
## Seeded mine layout generator. Pure logic (no nodes): every peer gets the same layout from
## the same seed, params and chunk set.
##
## 1. The Förderkorb station sits at the start cell and opens south only.
## 2. A self-avoiding random walk from it makes the main path.
## 3. Branches grow off random cells (dead ends).
## 4. Some neighbouring cells get joined to make loops (to escape creatures).
## 5. Some loop passages and dead-end entrances get a salt wall (Spitzhacke shortcuts, niches).
## 6. Each cell gets a chunk whose openings cover the cell's open sides.

const WALK_ATTEMPTS: int = 64
## A straight step is this many times as likely as a turn: long corridors, not zig-zag.
const STRAIGHT_BIAS: float = 2.0


static func generate(seed_value: int, params: MineParams, chunks: ChunkSet) -> MineLayout:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var layout: MineLayout = MineLayout.new()
	layout.add_cell(layout.start)
	_carve_main_path(layout, rng, params.main_length)
	for _i: int in params.branch_count:
		_carve_branch(layout, rng, params.branch_max_length)
	_add_loops(layout, rng, params)
	layout.compute_depth()
	_add_dead_end_walls(layout, rng, params)
	_pick_chunks(layout, rng, chunks)
	return layout


static func _carve_main_path(layout: MineLayout, rng: RandomNumberGenerator, length: int) -> void:
	var best: Array[Vector2i] = []
	for _attempt: int in WALK_ATTEMPTS:
		var path: Array[Vector2i] = _random_walk(rng, layout.start, GridDir.S, length, layout)
		if path.size() > best.size():
			best = path
		if best.size() >= length + 1:
			break
	layout.main_path = best
	for i: int in range(1, best.size()):
		layout.connect_cells(best[i - 1], _dir_between(best[i - 1], best[i]))


## A self-avoiding walk of up to `length` steps; the first step goes `first_dir`.
static func _random_walk(rng: RandomNumberGenerator, from: Vector2i, first_dir: int, length: int, layout: MineLayout) -> Array[Vector2i]:
	var path: Array[Vector2i] = [from]
	var taken: Dictionary = {from: true}
	var dir: int = first_dir
	for step: int in length:
		var choices: Array[int] = []
		var weights: PackedFloat32Array = []
		for candidate: int in GridDir.ALL:
			if step == 0 and candidate != first_dir:
				continue
			var next: Vector2i = path[-1] + GridDir.offset(candidate)
			if taken.has(next) or layout.has_cell(next):
				continue
			choices.append(candidate)
			weights.append(STRAIGHT_BIAS if candidate == dir else 1.0)
		if choices.is_empty():
			break
		dir = choices[rng.rand_weighted(weights)]
		var cell: Vector2i = path[-1] + GridDir.offset(dir)
		path.append(cell)
		taken[cell] = true
	return path


static func _carve_branch(layout: MineLayout, rng: RandomNumberGenerator, max_length: int) -> void:
	var origins: Array[Vector2i] = []
	for cell: Vector2i in layout.cells:
		if cell != layout.start:
			origins.append(cell)
	if origins.is_empty():
		return
	var origin: Vector2i = origins[rng.randi_range(0, origins.size() - 1)]
	var free_dirs: Array[int] = []
	for dir: int in GridDir.ALL:
		if not layout.has_cell(origin + GridDir.offset(dir)):
			free_dirs.append(dir)
	if free_dirs.is_empty():
		return
	var first_dir: int = free_dirs[rng.randi_range(0, free_dirs.size() - 1)]
	var path: Array[Vector2i] = _random_walk(rng, origin, first_dir, rng.randi_range(1, max_length), layout)
	for i: int in range(1, path.size()):
		layout.connect_cells(path[i - 1], _dir_between(path[i - 1], path[i]))


static func _add_loops(layout: MineLayout, rng: RandomNumberGenerator, params: MineParams) -> void:
	var candidates: Array[Array] = []
	for cell: Vector2i in layout.cells:
		if cell == layout.start:
			continue
		for dir: int in [GridDir.E, GridDir.S]:
			var other: Vector2i = cell + GridDir.offset(dir)
			if other != layout.start and layout.has_cell(other) and not layout.is_open(cell, dir):
				candidates.append([cell, dir])
	var added: int = 0
	for i: int in candidates.size():
		if added >= params.max_loops:
			break
		var j: int = rng.randi_range(i, candidates.size() - 1)
		var picked: Array = candidates[j]
		candidates[j] = candidates[i]
		candidates[i] = picked
		if rng.randf() < params.loop_chance:
			layout.connect_cells(picked[0], picked[1])
			added += 1
			if rng.randf() < params.wall_loop_chance:
				layout.walls.append(Vector3i(picked[0].x, picked[0].y, picked[1]))


## A dead end two or more steps from the lift may hide behind a salt wall: a niche for whoever
## brought a Spitzhacke. The wall stands on the neighbour's side of the passage.
static func _add_dead_end_walls(layout: MineLayout, rng: RandomNumberGenerator, params: MineParams) -> void:
	for cell: Vector2i in layout.cells:
		var mask: int = layout.cells[cell]
		var open: Array[int] = []
		for dir: int in GridDir.ALL:
			if mask & dir:
				open.append(dir)
		if cell == layout.start or open.size() != 1 or int(layout.depth.get(cell, 0)) < 2:
			continue
		if rng.randf() < params.wall_dead_end_chance:
			var into: Vector2i = cell + GridDir.offset(open[0])
			layout.walls.append(Vector3i(into.x, into.y, GridDir.opposite(open[0])))


static func _pick_chunks(layout: MineLayout, rng: RandomNumberGenerator, chunks: ChunkSet) -> void:
	var placed: Dictionary = {}  # entry index -> how many so far
	for cell: Vector2i in layout.cells:
		var mask: int = layout.cells[cell]
		var is_start: bool = cell == layout.start
		var options: Array[Vector2i] = []  # (entry index, rotation)
		var weights: PackedFloat32Array = []
		for index: int in chunks.entries.size():
			var entry: ChunkEntry = chunks.entries[index]
			if entry.is_station != is_start or int(layout.depth.get(cell, 0)) < entry.min_depth:
				continue
			if entry.max_count > 0 and int(placed.get(index, 0)) >= entry.max_count:
				continue
			var fit: Vector2i = _best_rotation(entry.openings, mask)
			if fit.x < 0:
				continue
			options.append(Vector2i(index, fit.x))
			weights.append(entry.weight * (1.0 if fit.y == 1 else chunks.superset_weight))
		assert(not options.is_empty(), "no chunk fits cell %s mask %d" % [cell, mask])
		var choice: Vector2i = options[rng.rand_weighted(weights)]
		layout.chunk_index[cell] = choice.x
		placed[choice.x] = int(placed.get(choice.x, 0)) + 1
		layout.chunk_rotation[cell] = choice.y


## (rotation, 1 if exact else 0), or (-1, 0) when the openings cannot cover `mask`.
## Exact fits win over supersets; among equals the lowest rotation wins (deterministic).
static func _best_rotation(openings: int, mask: int) -> Vector2i:
	var superset: int = -1
	for steps: int in 4:
		var turned: int = GridDir.rotate_mask(openings, steps)
		if turned == mask:
			return Vector2i(steps, 1)
		if superset < 0 and (turned & mask) == mask:
			superset = steps
	return Vector2i(superset, 0)


static func _dir_between(a: Vector2i, b: Vector2i) -> int:
	for dir: int in GridDir.ALL:
		if a + GridDir.offset(dir) == b:
			return dir
	assert(false, "cells are not neighbours")
	return 0
