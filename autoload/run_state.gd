class_name RunState
extends RefCounted
## Pure logic of one run (no nodes, no networking), so it can be unit tested. A run is a chain of
## shifts; every shift the company wants its Fundstück (DESIGN.md §2). Delivered, the crew keeps
## its job and the next shift is harder; not delivered (timer out, everyone dead, given up), the
## crew is fired and the run is over. Sold loot and the Fundstück's bonus become money for the
## Waffenkammer; run upgrades hold for the whole crew until the run ends.

var config: BalanceConfig
var player_count: int = 1
## The shift being played or coming next, 0-based (the difficulty grows with it, §8).
var shift_index: int = 0
var money: int = 0
var total_earned: int = 0
var shifts_survived: int = 0
## Ehrenzeichen earned in this run (they will go into the saved profile, §7).
var ehrenzeichen: int = 0
var fired: bool = false
## Run upgrades bought: upgrade id -> level.
var upgrades: Dictionary = {}


func _init(balance: BalanceConfig, players: int) -> void:
	config = balance
	player_count = players


## Ends a shift: the loot that rode up is sold; with the Fundstück delivered the bonus and the
## Ehrenzeichen are paid and the next shift comes, without it the crew is fired.
func finish_shift(loot_value: int, delivered: bool, bonus: int = 0, honours: int = 0) -> void:
	assert(not fired, "run is already over")
	var earned: int = loot_value + (bonus if delivered else 0)
	money += earned
	total_earned += earned
	if not delivered:
		fired = true
		return
	ehrenzeichen += honours
	shifts_survived += 1
	shift_index += 1


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


func upgrade_level(id: StringName) -> int:
	return int(upgrades.get(id, 0))


## Buys the next level of `upgrade` if there is one and the crew can pay for it.
func buy_upgrade(upgrade: RunUpgrade) -> bool:
	var level: int = upgrade_level(upgrade.id)
	if level >= upgrade.max_level() or not spend(upgrade.price_after(level)):
		return false
	upgrades[upgrade.id] = level + 1
	return true


## Score shown at the end of a run: shifts survived (money earned breaks ties).
func score() -> Dictionary:
	return {"shifts": shifts_survived, "money": total_earned, "ehrenzeichen": ehrenzeichen}
