extends GutTest

var config: BalanceConfig
var run: RunState


func before_each() -> void:
	config = BalanceConfig.new()
	run = RunState.new(config, 4)


func test_shift_inside_cycle_does_not_check_quota() -> void:
	assert_false(run.finish_shift(10))
	assert_eq(run.money, 10)
	assert_eq(run.shifts_left_in_cycle(), 2)


func test_meeting_quota_pays_it_and_starts_next_cycle() -> void:
	var quota: int = run.current_quota()
	run.finish_shift(quota)
	run.finish_shift(0)
	assert_true(run.finish_shift(25))
	assert_false(run.fired)
	assert_eq(run.money, 25)
	assert_eq(run.cycle, 1)
	assert_eq(run.cycles_survived, 1)
	assert_eq(run.shifts_done_in_cycle, 0)


func test_missing_quota_fires_the_crew() -> void:
	run.finish_shift(1)
	run.finish_shift(1)
	assert_true(run.finish_shift(1))
	assert_true(run.fired)
	assert_eq(run.score(), {"cycles": 0, "money": 3})


func test_spending_can_lose_the_quota() -> void:
	var quota: int = run.current_quota()
	run.finish_shift(quota)
	assert_true(run.spend(1))
	run.finish_shift(0)
	run.finish_shift(0)
	assert_true(run.fired)


func test_cannot_spend_more_than_money() -> void:
	run.finish_shift(5)
	assert_false(run.spend(6))
	assert_eq(run.money, 5)
