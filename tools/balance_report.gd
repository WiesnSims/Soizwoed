extends SceneTree
## Balance overview: for every shift (as the run goes on), crew size and mine section – the loot
## value one shift holds on average, the Fundstück's bonus, the enemy budget and creature health,
## the boss chance and the Rückweg-timer against the time it takes to carry the Fundstück back.
##     godot --headless -s tools/balance_report.gd
## The same estimates back tests/test_balance.gd. They are expectations over the loot table (an
## average depth of AVERAGE_DEPTH steps, relics counted with how often their chunk turns up) and
## an estimate of the way back (the main path, cell centre to cell centre, times WAY_FACTOR), not
## a simulation of real mines.

const AVERAGE_DEPTH: int = 3
const MAX_DEPTH: int = 6
## Share of mines that have the relic chunk (tests/test_mine_generator.gd checks it is most).
const RELIC_CHANCE: float = 0.85
const RELIC_DEPTH: int = 5
## The way along the main path is longer than cell centre to cell centre (bends, rooms).
const WAY_FACTOR: float = 1.25
const BIOME_PATHS: PackedStringArray = ["res://world/chunks/oberer_stollen/oberer_stollen.tres",
		"res://world/chunks/salzsee/salzsee.tres", "res://world/chunks/die_tiefe/die_tiefe.tres"]


func _initialize() -> void:
	var config: BalanceConfig = load("res://balance.tres")
	var catalog: ItemCatalog = load("res://items/item_catalog.tres")
	var sections: Array[ChunkSet] = []
	for path: String in BIOME_PATHS:
		sections.append(load(path) as ChunkSet)
	for players: int in [1, 2, 3, 4]:
		print("%d miner(s)" % players)
		for shift: int in 12:
			var line: String = "  shift %2d: enemies %4.1f, health x%.2f, boss %3.0f %%, ammo boxes %d |" % [shift + 1,
					config.enemy_budget(shift, players), config.enemy_health_mult(players, shift), config.boss_chance(shift) * 100.0,
					config.ammo_box_count(shift, players)]
			for section: ChunkSet in sections:
				var rule: BiomeRule = config.biome_rule(section.id)
				if shift < rule.unlock_shift:
					line += "  %s –" % section.id
					continue
				var way: float = way_metres(config, section, shift)
				line += "  %s %4.0f S + %3d S, way %3.0f m: %3.0f s (carry %3.0f s)" % [section.id,
						shift_value(config, catalog, section, shift, players), config.fundstueck_bonus(shift, rule.loot_value_mult),
						way, config.rueckweg_seconds(shift, players, way), carry_seconds(config, way, players == 1)]
			print(line)
	quit()


## Estimated length of the way from the Fundort to the lift (m) in shift `shift`.
static func way_metres(config: BalanceConfig, section: ChunkSet, shift: int) -> float:
	return MineParams.from_balance(config, shift).main_length * section.cell_size * WAY_FACTOR


## Seconds to carry a heavy Fundstück that far: alone (half speed) or together.
static func carry_seconds(config: BalanceConfig, metres: float, alone: bool) -> float:
	return metres / (config.walk_speed * (config.carry_heavy_speed if alone else config.carry_together_speed))


## Average value of the loot (and relics) in one shift's mine.
static func shift_value(config: BalanceConfig, catalog: ItemCatalog, section: ChunkSet, shift: int, players: int) -> float:
	var rule: BiomeRule = config.biome_rule(section.id)
	var per_item: float = 0.0
	for depth: int in MAX_DEPTH + 1:
		per_item += _item_value(catalog, section.id, depth)
	per_item = per_item / (MAX_DEPTH + 1) * (1.0 + AVERAGE_DEPTH * config.loot_value_per_depth) * rule.loot_value_mult
	var total: float = per_item * config.loot_count(shift, players)
	if section.id == &"die_tiefe":
		var relic: ItemData = catalog.by_id(&"mann_im_salz")
		total += RELIC_CHANCE * (relic.value_min + relic.value_max) / 2.0 * (1.0 + RELIC_DEPTH * config.loot_value_per_depth) * rule.loot_value_mult
	return total


static func _item_value(catalog: ItemCatalog, section: StringName, depth: int) -> float:
	var weights: float = 0.0
	var value: float = 0.0
	for data: ItemData in catalog.loot():
		if data.min_depth <= depth and data.spawns_in(section):
			weights += data.spawn_weight
			value += data.spawn_weight * (data.value_min + data.value_max) / 2.0
	return value / weights if weights > 0.0 else 0.0
