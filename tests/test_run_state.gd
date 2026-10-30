extends GutTest

var config: BalanceConfig
var run: RunState


func before_each() -> void:
	config = BalanceConfig.new()
	run = RunState.new(config, 4)


func test_delivered_fundstueck_pays_and_starts_the_next_shift() -> void:
	run.finish_shift(40, true, 150, 2)
	assert_false(run.fired)
	assert_eq(run.money, 190)
	assert_eq(run.shift_index, 1)
	assert_eq(run.shifts_survived, 1)
	assert_eq(run.ehrenzeichen, 2)


func test_no_fundstueck_fires_the_crew() -> void:
	run.finish_shift(40, true, 150, 1)
	run.finish_shift(25, false, 150, 1)
	assert_true(run.fired)
	assert_eq(run.shift_index, 1, "the failed shift does not count")
	assert_eq(run.money, 215, "loot that rode up is still sold, the bonus is not paid")
	assert_eq(run.score(), {"shifts": 1, "money": 215, "ehrenzeichen": 1})


func test_cannot_spend_more_than_money() -> void:
	run.finish_shift(5, true)
	assert_false(run.spend(6))
	assert_eq(run.money, 5)


func test_cheat_money_is_spendable_but_not_scored() -> void:
	run.add_cheat_money(1000)
	assert_eq(run.money, 1000)
	assert_true(run.spend(320))
	assert_eq(run.score().money, 0)


func test_upgrades_are_bought_level_by_level() -> void:
	var upgrade: RunUpgrade = RunUpgrade.new()
	upgrade.id = &"test"
	upgrade.prices = [100, 200]
	run.add_cheat_money(250)
	assert_true(run.buy_upgrade(upgrade))
	assert_eq(run.upgrade_level(&"test"), 1)
	assert_false(run.buy_upgrade(upgrade), "150 left, the next level costs 200")
	run.add_cheat_money(100)
	assert_true(run.buy_upgrade(upgrade))
	assert_false(run.buy_upgrade(upgrade), "maxed out")
	assert_eq(run.upgrade_level(&"test"), 2)
	assert_eq(run.money, 50)
