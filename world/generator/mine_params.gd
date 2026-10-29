class_name MineParams
extends RefCounted
## How big and tangled a mine gets. Built from balance.tres for a cycle and player count.

var main_length: int = 8
var branch_count: int = 3
var branch_max_length: int = 3
var loop_chance: float = 0.35
var max_loops: int = 2
## Chance that a loop's new passage, or the way into a dead end, is closed by a salt wall.
var wall_loop_chance: float = 0.5
var wall_dead_end_chance: float = 0.25


static func from_balance(config: BalanceConfig, cycle: int) -> MineParams:
	var params: MineParams = MineParams.new()
	params.main_length = mini(config.mine_main_length_base + cycle * config.mine_main_length_per_cycle, config.mine_main_length_max)
	params.branch_count = mini(config.mine_branches_base + cycle, config.mine_branches_max)
	params.branch_max_length = config.mine_branch_max_length
	params.loop_chance = config.mine_loop_chance
	params.max_loops = config.mine_max_loops
	params.wall_loop_chance = config.salt_wall_loop_chance
	params.wall_dead_end_chance = config.salt_wall_dead_end_chance
	return params
