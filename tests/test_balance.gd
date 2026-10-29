extends GutTest

var config: BalanceConfig


func before_each() -> void:
	config = BalanceConfig.new()


func test_balance_tres_loads() -> void:
	var loaded: BalanceConfig = load("res://balance.tres") as BalanceConfig
	assert_not_null(loaded)
	assert_eq(loaded.shifts_per_cycle, 3)


func test_player_scaling_matches_design() -> void:
	assert_almost_eq(config.enemy_budget_mult(1), 0.5, 0.001)
	assert_almost_eq(config.enemy_budget_mult(4), 1.0, 0.001)
	assert_almost_eq(config.loot_density_mult(2), 0.75, 0.001)


func test_player_count_above_table_uses_last_entry() -> void:
	assert_almost_eq(config.enemy_budget_mult(6), 1.0, 0.001)


func test_player_count_below_one_uses_first_entry() -> void:
	assert_almost_eq(config.enemy_budget_mult(0), 0.5, 0.001)


func test_shift_length_solo_gets_two_extra_minutes() -> void:
	assert_almost_eq(config.shift_seconds(1), config.shift_base_seconds + 120.0, 0.001)
	assert_almost_eq(config.shift_seconds(3), config.shift_base_seconds, 0.001)


func test_quota_grows_each_cycle() -> void:
	assert_eq(config.quota_for_cycle(0, 4), config.quota_base)
	assert_eq(config.quota_for_cycle(1, 4), int(round(config.quota_base * config.quota_growth)))
	assert_gt(config.quota_for_cycle(2, 4), config.quota_for_cycle(1, 4))


func test_solo_quota_is_scaled_down() -> void:
	assert_eq(config.quota_for_cycle(0, 1), int(round(config.quota_base * 0.45)))


func test_soft_landings_do_not_hurt() -> void:
	assert_eq(config.fall_damage(config.jump_velocity), 0, "landing from a jump")
	assert_eq(config.fall_damage(config.fall_damage_min_speed), 0)


func test_hard_landings_hurt_more_the_faster() -> void:
	var low: int = config.fall_damage(config.fall_damage_min_speed + 1.0)
	var high: int = config.fall_damage(config.fall_damage_min_speed + 6.0)
	assert_gt(low, 0)
	assert_gt(high, low)
	assert_gte(config.fall_damage(30.0), config.player_max_health, "a long fall kills")
