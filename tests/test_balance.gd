extends GutTest

var config: BalanceConfig


func before_each() -> void:
	config = BalanceConfig.new()


func test_balance_tres_loads() -> void:
	var loaded: BalanceConfig = load("res://balance.tres") as BalanceConfig
	assert_not_null(loaded)
	assert_false(loaded.run_upgrades.is_empty())


func test_player_scaling_matches_design() -> void:
	assert_almost_eq(config.enemy_budget_mult(1), 0.45, 0.001)
	assert_almost_eq(config.enemy_budget_mult(4), 1.0, 0.001)
	assert_almost_eq(config.loot_density_mult(2), 0.75, 0.001)


func test_player_count_above_table_uses_last_entry() -> void:
	assert_almost_eq(config.enemy_budget_mult(6), 1.0, 0.001)


func test_player_count_below_one_uses_first_entry() -> void:
	assert_almost_eq(config.enemy_budget_mult(0), 0.45, 0.001)


func test_shift_length_solo_gets_two_extra_minutes() -> void:
	assert_almost_eq(config.shift_seconds(1), config.shift_base_seconds + 120.0, 0.001)
	assert_almost_eq(config.shift_seconds(3), config.shift_base_seconds, 0.001)


func test_difficulty_grows_every_shift() -> void:
	for players: int in [1, 4]:
		assert_gt(config.enemy_budget(5, players), config.enemy_budget(0, players))
		assert_gt(config.enemy_health_mult(players, 5), config.enemy_health_mult(players, 0))
		assert_gt(config.wave_budget(5, players), config.wave_budget(0, players))
		assert_lt(config.rueckweg_seconds(5, players, 100.0), config.rueckweg_seconds(0, players, 100.0))
		assert_lte(config.ammo_box_count(8, players), config.ammo_box_count(0, players))
	assert_gt(config.enemy_damage_mult(5), 1.0)
	assert_lte(config.enemy_health_mult(4, 1000), config.enemy_health_max)


func test_boss_chance_follows_the_design() -> void:
	assert_eq(config.boss_chance(0), 0.0, "never in the first shift")
	assert_gt(config.boss_chance(1), 0.0, "maybe from shift 2")
	assert_eq(config.boss_chance(3), 1.0, "always from shift 4")
	assert_eq(config.boss_chance(20), 1.0)
	assert_almost_eq(config.boss_health_mult(0, 1), 0.5, 0.001, "solo bosses have half the health")


func test_small_crews_get_more_time_for_the_way_back() -> void:
	assert_almost_eq(config.rueckweg_seconds(0, 1, 100.0), config.rueckweg_seconds(0, 4, 100.0) * 1.4, 0.01)
	assert_gt(config.rueckweg_seconds(0, 4, 200.0), config.rueckweg_seconds(0, 4, 100.0), "a longer way gets more time")


func test_armour_takes_its_share_until_it_is_gone() -> void:
	assert_eq(config.armour_split(40, 100), Vector2i(20, 20))
	assert_eq(config.armour_split(40, 5), Vector2i(35, 5))
	assert_eq(config.armour_split(40, 0), Vector2i(40, 0))


func test_upgrades_raise_caps_and_armour() -> void:
	var real: BalanceConfig = load("res://balance.tres")
	var cap: RunUpgrade = null
	var armour: int = 0
	var levels: Dictionary = {}
	for upgrade: RunUpgrade in real.run_upgrades:
		assert_false(upgrade.prices.is_empty(), "%s has no price" % upgrade.id)
		levels[upgrade.id] = upgrade.max_level()
		if upgrade.effect == RunUpgrade.Effect.AMMO_CAP and upgrade.target == &"pistole":
			cap = upgrade
		if upgrade.effect == RunUpgrade.Effect.ARMOUR:
			armour += roundi(upgrade.total(upgrade.max_level()))
	assert_not_null(cap)
	assert_eq(real.ammo_cap(&"pistole", levels), real.ammo_cap_pistole + roundi(cap.total(cap.max_level())))
	assert_eq(real.ammo_cap(&"pistole"), real.ammo_cap_pistole, "no upgrades, no change")
	assert_eq(real.armour_points(levels), armour)
	assert_gt(armour, 0)
	assert_gt(real.lamp_range_mult(levels), 1.0)


func test_weapon_upgrades_change_a_copy() -> void:
	var real: BalanceConfig = load("res://balance.tres")
	var pistol: ItemData = (load("res://items/item_catalog.tres") as ItemCatalog).by_id(&"dienstpistole")
	var base: WeaponData = pistol.get_meta(&"base_weapon", pistol.weapon)
	var levels: Dictionary = {&"pistole_damage": 1, &"pistole_magazine": 1, &"pistole_reload": 1, &"pistole_spread": 1}
	var better: WeaponData = RunUpgrade.upgraded_weapon(base, &"dienstpistole", real.run_upgrades, levels)
	assert_gt(better.damage, base.damage)
	assert_gt(better.magazine, base.magazine)
	assert_lt(better.reload_seconds, base.reload_seconds)
	assert_lt(better.spread_ads, base.spread_ads)
	assert_eq(RunUpgrade.upgraded_weapon(base, &"salzschrot_flinte", real.run_upgrades, levels).damage, base.damage, "other guns stay")


func test_fundstueck_pays_more_later_and_deeper() -> void:
	assert_gt(config.fundstueck_bonus(4, 1.0), config.fundstueck_bonus(0, 1.0))
	assert_gt(config.fundstueck_bonus(0, 1.45), config.fundstueck_bonus(0, 1.0))
	assert_eq(config.ehrenzeichen(0, 0, false), config.ehrenzeichen_base)
	assert_gt(config.ehrenzeichen(6, 2, true), config.ehrenzeichen(0, 0, false))


func test_soft_landings_do_not_hurt() -> void:
	assert_eq(config.fall_damage(config.jump_velocity), 0, "landing from a jump")
	assert_eq(config.fall_damage(config.fall_damage_min_speed), 0)


func test_hard_landings_hurt_more_the_faster() -> void:
	var low: int = config.fall_damage(config.fall_damage_min_speed + 1.0)
	var high: int = config.fall_damage(config.fall_damage_min_speed + 6.0)
	assert_gt(low, 0)
	assert_gt(high, low)
	assert_gte(config.fall_damage(30.0), config.player_max_health, "a long fall kills")


## The way back is always possible (DESIGN.md §2): even alone with a heavy Fundstück at half
## speed, in every section and shift, the Rückweg-timer leaves time to spare.
func test_rueckweg_always_leaves_time_to_spare() -> void:
	var report: GDScript = load("res://tools/balance_report.gd")
	var real: BalanceConfig = load("res://balance.tres")
	for path: String in report.BIOME_PATHS:
		var section: ChunkSet = load(path)
		for shift: int in 20:
			for players: int in [1, 2, 4]:
				var way: float = report.way_metres(real, section, shift)
				var timer: float = real.rueckweg_seconds(shift, players, way)
				var carry: float = report.carry_seconds(real, way, players == 1)
				assert_gt(timer, carry * 1.5, "%s, shift %d, %d miner(s): %.0f s for %.0f s of carrying" % [section.id, shift + 1, players, timer, carry])


## Deeper sections are worth the trouble: more loot value per shift in the same shift.
func test_deeper_sections_hold_more() -> void:
	var report: GDScript = load("res://tools/balance_report.gd")
	var real: BalanceConfig = load("res://balance.tres")
	var catalog: ItemCatalog = load("res://items/item_catalog.tres")
	var last: float = 0.0
	for path: String in report.BIOME_PATHS:
		var value: float = report.shift_value(real, catalog, load(path), 3, 2)
		assert_gt(value, last * 1.2, path)
		last = value
