extends GutTest
## Creature spawn rules, biome rules and hazard maths from balance.tres.

var config: BalanceConfig = load("res://balance.tres") as BalanceConfig


func test_every_biome_creature_has_a_rule() -> void:
	var stollen: ChunkSet = load("res://world/chunks/oberer_stollen/oberer_stollen.tres") as ChunkSet
	assert_false(stollen.creatures.is_empty())
	for id: StringName in stollen.creatures:
		assert_not_null(config.spawn_rule(id), "no spawn rule for %s" % id)
	assert_not_null(config.biome_rule(stollen.id), "no biome rule for %s" % stollen.id)


func test_bergmandl_come_in_gangs() -> void:
	var rule: CreatureSpawnRule = config.spawn_rule(&"bergmandl")
	assert_eq(rule.group_size(3, 0, 10.0), 3)
	assert_eq(rule.group_size(1, 0, 10.0), rule.group_min, "rolls are clamped to the group size")
	assert_eq(rule.group_size(3, 0, 2.0), 2, "the budget caps the group")


func test_max_alive_limits_spawning() -> void:
	var rule: CreatureSpawnRule = config.spawn_rule(&"tatzelwurm")
	assert_true(rule.allowed(0, 0, 10.0))
	assert_false(rule.allowed(0, 1, 10.0), "only one Tatzelwurm at a time")
	assert_false(rule.allowed(0, 0, rule.budget_cost - 0.1), "not enough budget left")


func test_schichtmeister_is_never_budget_spawned() -> void:
	var rule: CreatureSpawnRule = config.spawn_rule(&"schichtmeister")
	assert_false(rule.allowed(5, 0, 100.0))
	assert_eq(rule.group_size(1, 0, 100.0), 1, "zero cost does not divide by zero")


func test_min_cycle_holds_creatures_back() -> void:
	var rule: CreatureSpawnRule = CreatureSpawnRule.new()
	rule.min_cycle = 2
	assert_false(rule.allowed(1, 0, 10.0))
	assert_true(rule.allowed(2, 0, 10.0))


func test_salzsee_is_richer_and_unlocks_later() -> void:
	var salzsee: BiomeRule = config.biome_rule(&"salzsee")
	assert_gt(salzsee.unlock_cycle, 0)
	assert_gt(salzsee.loot_value_mult, 1.0)


func test_explosion_damage_falls_off() -> void:
	assert_eq(config.explosion_damage(0.0, 7.0, 90), 90)
	assert_eq(config.explosion_damage(3.5, 7.0, 90), 45)
	assert_eq(config.explosion_damage(7.0, 7.0, 90), 0)


func test_gas_share_grows_but_is_capped() -> void:
	assert_almost_eq(config.gas_share_for_cycle(0), config.gas_share, 0.0001)
	assert_gt(config.gas_share_for_cycle(3), config.gas_share_for_cycle(0))
	assert_lte(config.gas_share_for_cycle(100), 0.8)
