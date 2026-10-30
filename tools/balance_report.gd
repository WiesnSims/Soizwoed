extends SceneTree
## Balance overview: for every quota cycle, crew size and mine section, how much loot value one
## shift holds on average and what share of it a crew has to bring up to make the quota.
##     godot --headless -s tools/balance_report.gd
## The same estimate backs tests/test_balance.gd. It is an expectation over the loot table (an
## average depth of AVERAGE_DEPTH steps, relics counted with how often their chunk turns up),
## not a simulation of real mines.

const AVERAGE_DEPTH: int = 3
const MAX_DEPTH: int = 6
## Share of mines that have the relic chunk (tests/test_mine_generator.gd checks it is most).
const RELIC_CHANCE: float = 0.85
const RELIC_DEPTH: int = 5
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
		for cycle: int in 7:
			var quota: int = config.quota_for_cycle(cycle, players)
			var line: String = "  cycle %d, quota %5d S:" % [cycle + 1, quota]
			for section: ChunkSet in sections:
				var rule: BiomeRule = config.biome_rule(section.id)
				if cycle < rule.unlock_cycle:
					line += "  %s  –" % section.id
					continue
				var value: float = shift_value(config, catalog, section, cycle, players)
				line += "  %s %5.0f S/shift, need %3.0f %%" % [section.id, value, quota_share(config, catalog, section, cycle, players) * 100.0]
			print(line)
	quit()


## Average value of the loot (and relics) in one shift's mine.
static func shift_value(config: BalanceConfig, catalog: ItemCatalog, section: ChunkSet, cycle: int, players: int) -> float:
	var rule: BiomeRule = config.biome_rule(section.id)
	var per_item: float = 0.0
	for depth: int in MAX_DEPTH + 1:
		per_item += _item_value(catalog, section.id, depth)
	per_item = per_item / (MAX_DEPTH + 1) * (1.0 + AVERAGE_DEPTH * config.loot_value_per_depth) * rule.loot_value_mult
	var total: float = per_item * config.loot_count(cycle, players)
	if section.id == &"die_tiefe":
		var relic: ItemData = catalog.by_id(&"mann_im_salz")
		total += RELIC_CHANCE * (relic.value_min + relic.value_max) / 2.0 * (1.0 + RELIC_DEPTH * config.loot_value_per_depth) * rule.loot_value_mult
	return total


## Share of all the loot of a cycle's shifts the crew must sell to make the quota.
static func quota_share(config: BalanceConfig, catalog: ItemCatalog, section: ChunkSet, cycle: int, players: int) -> float:
	return config.quota_for_cycle(cycle, players) / (config.shifts_per_cycle * shift_value(config, catalog, section, cycle, players))


static func _item_value(catalog: ItemCatalog, section: StringName, depth: int) -> float:
	var weights: float = 0.0
	var value: float = 0.0
	for data: ItemData in catalog.loot():
		if data.min_depth <= depth and data.spawns_in(section):
			weights += data.spawn_weight
			value += data.spawn_weight * (data.value_min + data.value_max) / 2.0
	return value / weights if weights > 0.0 else 0.0
