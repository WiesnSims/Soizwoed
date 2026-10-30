class_name RunState
extends RefCounted
## Pure quota/money logic of one run (no nodes, no networking), so it can be unit tested.
## A run is a chain of quota cycles of `shifts_per_cycle` shifts each. Sold loot becomes
## money; at the end of each cycle the quota is paid out of the money. Not enough money
## means "Kündigung" and the run ends.

var config: BalanceConfig
var player_count: int = 1
var cycle: int = 0
var shifts_done_in_cycle: int = 0
var money: int = 0
var total_earned: int = 0
var cycles_survived: int = 0
var fired: bool = false


func _init(balance: BalanceConfig, players: int) -> void:
	config = balance
	player_count = players


func current_quota() -> int:
	return config.quota_for_cycle(cycle, player_count)


func shifts_left_in_cycle() -> int:
	return config.shifts_per_cycle - shifts_done_in_cycle


## Ends a shift that sold `loot_value` worth of loot. Returns true when this shift
## ended the cycle (a quota check happened); check `fired` for the result.
func finish_shift(loot_value: int) -> bool:
	assert(not fired, "run is already over")
	money += loot_value
	total_earned += loot_value
	shifts_done_in_cycle += 1
	if shifts_done_in_cycle < config.shifts_per_cycle:
		return false
	var quota: int = current_quota()
	if money >= quota:
		money -= quota
		cycles_survived += 1
		cycle += 1
		shifts_done_in_cycle = 0
	else:
		fired = true
	return true


## Test cheat: money that was not earned (not counted in the score).
func add_cheat_money(amount: int) -> void:
	money += amount


func can_afford(price: int) -> bool:
	return price <= money


func spend(price: int) -> bool:
	if not can_afford(price):
		return false
	money -= price
	return true


## Score shown at the end of a run: cycles survived + total money earned.
func score() -> Dictionary:
	return {"cycles": cycles_survived, "money": total_earned}
