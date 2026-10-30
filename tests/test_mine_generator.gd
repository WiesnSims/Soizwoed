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


func test_later_shifts_make_bigger_mines() -> void:
	var small: MineLayout = MineGenerator.generate(9, MineParams.from_balance(BalanceConfig.new(), 0), CHUNKS)
	var big: MineLayout = MineGenerator.generate(9, MineParams.from_balance(BalanceConfig.new(), 10), CHUNKS)
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


func test_salzsee_chunks_cover_every_cell() -> void:
	var lake_set: ChunkSet = load("res://world/chunks/salzsee/salzsee.tres")
	var lakes: int = 0
	for seed_value: int in range(40):
		var layout: MineLayout = MineGenerator.generate(seed_value, params, lake_set)
		assert_eq(layout.depth.size(), layout.cells.size(), "seed %d has unreachable cells" % seed_value)
		assert_true(lake_set.entries[layout.chunk_index[layout.start]].is_station)
		for cell: Vector2i in layout.cells:
			var entry: ChunkEntry = lake_set.entries[layout.chunk_index[cell]]
			var turned: int = GridDir.rotate_mask(entry.openings, layout.chunk_rotation[cell])
			assert_eq(turned & layout.cells[cell], layout.cells[cell], "seed %d cell %s" % [seed_value, cell])
			lakes += 1 if entry.scene.resource_path.ends_with("lake.tscn") else 0
	assert_gt(lakes, 10, "hardly any lake caverns in 40 Salzsee mines")


func test_tiefe_has_at_most_one_shrine_and_covers_every_cell() -> void:
	var deep_set: ChunkSet = load("res://world/chunks/die_tiefe/die_tiefe.tres")
	var config: BalanceConfig = load("res://balance.tres")
	var with_shrine: int = 0
	for seed_value: int in range(40):
		var layout: MineLayout = MineGenerator.generate(seed_value, MineParams.from_balance(config, 2), deep_set)
		assert_eq(layout.depth.size(), layout.cells.size(), "seed %d has unreachable cells" % seed_value)
		var shrines: int = 0
		for cell: Vector2i in layout.cells:
			var entry: ChunkEntry = deep_set.entries[layout.chunk_index[cell]]
			var turned: int = GridDir.rotate_mask(entry.openings, layout.chunk_rotation[cell])
			assert_eq(turned & layout.cells[cell], layout.cells[cell], "seed %d cell %s" % [seed_value, cell])
			assert_false(entry.rails, "no rails in Die Tiefe")
			shrines += 1 if entry.scene.resource_path.ends_with("salzmann.tscn") else 0
		assert_lte(shrines, 1, "seed %d has %d shrines" % [seed_value, shrines])
		with_shrine += shrines
	assert_gt(with_shrine, 24, "the Mann im Salz should be in most Tiefe mines")


func test_every_section_has_rules_and_creatures() -> void:
	var config: BalanceConfig = load("res://balance.tres")
	for path: String in ["res://world/chunks/oberer_stollen/oberer_stollen.tres", "res://world/chunks/salzsee/salzsee.tres",
			"res://world/chunks/die_tiefe/die_tiefe.tres"]:
		var chunk_set: ChunkSet = load(path)
		assert_not_null(config.biome_rule(chunk_set.id), "no BiomeRule for %s" % chunk_set.id)
		assert_false(chunk_set.creatures.is_empty())
		for id: StringName in chunk_set.creatures:
			assert_not_null(config.spawn_rule(id), "%s: no spawn rule for %s" % [chunk_set.id, id])


## DESIGN.md §4: the end of the main path is the Fundort – a dead end with its own chunk, once per
## mine, in every section, and nothing else (branches, loops, salt walls) touches it.
func test_fundort_is_the_dead_end_of_the_main_path() -> void:
	for path: String in ["res://world/chunks/oberer_stollen/oberer_stollen.tres", "res://world/chunks/salzsee/salzsee.tres",
			"res://world/chunks/die_tiefe/die_tiefe.tres"]:
		var chunk_set: ChunkSet = load(path)
		for seed_value: int in range(30):
			var layout: MineLayout = MineGenerator.generate(seed_value, params, chunk_set)
			var label: String = "%s seed %d" % [chunk_set.id, seed_value]
			assert_eq(layout.fundort, layout.main_path[-1], label)
			assert_eq(layout.neighbors(layout.fundort).size(), 1, "%s: the Fundort is a dead end" % label)
			var fundorte: int = 0
			for cell: Vector2i in layout.cells:
				var entry: ChunkEntry = chunk_set.entries[layout.chunk_index[cell]]
				fundorte += 1 if entry.is_fundort else 0
				assert_eq(entry.is_fundort, cell == layout.fundort, "%s cell %s" % [label, cell])
			assert_eq(fundorte, 1, label)
			for wall: Vector3i in layout.walls:
				var walled: Vector2i = Vector2i(wall.x, wall.y)
				assert_false(walled == layout.fundort or walled + GridDir.offset(wall.z) == layout.fundort, "%s: a salt wall at the Fundort" % label)
