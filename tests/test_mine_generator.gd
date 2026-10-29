extends GutTest

const CHUNKS: ChunkSet = preload("res://world/chunks/oberer_stollen/oberer_stollen.tres")

var params: MineParams


func before_each() -> void:
	params = MineParams.from_balance(BalanceConfig.new(), 0)


func test_rotate_mask_turns_clockwise() -> void:
	assert_eq(GridDir.rotate_mask(GridDir.N, 1), GridDir.E)
	assert_eq(GridDir.rotate_mask(GridDir.W, 1), GridDir.N)
	assert_eq(GridDir.rotate_mask(GridDir.N | GridDir.E, 2), GridDir.S | GridDir.W)
	assert_eq(GridDir.rotate_mask(GridDir.E, -1), GridDir.N)


func test_rotation_y_turns_north_to_east() -> void:
	var turned: Vector3 = Basis(Vector3.UP, GridDir.rotation_y(1)) * Vector3.FORWARD
	assert_almost_eq(turned.x, 1.0, 0.0001)
	assert_almost_eq(turned.z, 0.0, 0.0001)


func test_same_seed_same_layout() -> void:
	var a: MineLayout = MineGenerator.generate(1234, params, CHUNKS)
	var b: MineLayout = MineGenerator.generate(1234, params, CHUNKS)
	assert_eq(a.signature(), b.signature())


func test_different_seeds_differ() -> void:
	var a: MineLayout = MineGenerator.generate(1, params, CHUNKS)
	var b: MineLayout = MineGenerator.generate(2, params, CHUNKS)
	assert_ne(a.signature(), b.signature())


func test_every_cell_reachable_from_the_lift() -> void:
	for seed_value: int in range(40):
		var layout: MineLayout = MineGenerator.generate(seed_value, params, CHUNKS)
		assert_eq(layout.depth.size(), layout.cells.size(), "seed %d has unreachable cells" % seed_value)


func test_connections_are_two_way() -> void:
	var layout: MineLayout = MineGenerator.generate(77, params, CHUNKS)
	for cell: Vector2i in layout.cells:
		for dir: int in GridDir.ALL:
			if layout.is_open(cell, dir):
				assert_true(layout.is_open(cell + GridDir.offset(dir), GridDir.opposite(dir)))


func test_station_is_the_start_with_one_exit() -> void:
	for seed_value: int in range(20):
		var layout: MineLayout = MineGenerator.generate(seed_value, params, CHUNKS)
		assert_eq(layout.cells[layout.start], GridDir.S)
		assert_true(CHUNKS.entries[layout.chunk_index[layout.start]].is_station)


func test_main_path_has_requested_length() -> void:
	var layout: MineLayout = MineGenerator.generate(5, params, CHUNKS)
	assert_eq(layout.main_path.size(), params.main_length + 1)


func test_every_chunk_covers_its_cell() -> void:
	for seed_value: int in range(40):
		var layout: MineLayout = MineGenerator.generate(seed_value, params, CHUNKS)
		for cell: Vector2i in layout.cells:
			var entry: ChunkEntry = CHUNKS.entries[layout.chunk_index[cell]]
			var turned: int = GridDir.rotate_mask(entry.openings, layout.chunk_rotation[cell])
			assert_eq(turned & layout.cells[cell], layout.cells[cell], "seed %d cell %s" % [seed_value, cell])
			assert_true(int(layout.depth[cell]) >= entry.min_depth)


func test_later_cycles_make_bigger_mines() -> void:
	var small: MineLayout = MineGenerator.generate(9, MineParams.from_balance(BalanceConfig.new(), 0), CHUNKS)
	var big: MineLayout = MineGenerator.generate(9, MineParams.from_balance(BalanceConfig.new(), 5), CHUNKS)
	assert_gt(big.cells.size(), small.cells.size())


func test_salt_walls_close_open_passages_only() -> void:
	var walls: int = 0
	for seed_value: int in range(40):
		var layout: MineLayout = MineGenerator.generate(seed_value, params, CHUNKS)
		for wall: Vector3i in layout.walls:
			var cell: Vector2i = Vector2i(wall.x, wall.y)
			assert_true(layout.is_open(cell, wall.z), "seed %d wall %s on a closed side" % [seed_value, wall])
			assert_ne(cell, layout.start, "seed %d walls in the station" % seed_value)
			walls += 1
	assert_gt(walls, 0, "no salt walls in 40 mines")


func test_no_salt_walls_when_switched_off() -> void:
	params.wall_loop_chance = 0.0
	params.wall_dead_end_chance = 0.0
	for seed_value: int in range(10):
		assert_eq(MineGenerator.generate(seed_value, params, CHUNKS).walls.size(), 0)
