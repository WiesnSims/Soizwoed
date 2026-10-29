class_name BalanceConfig
extends Resource
## Every balance number of the game. The one instance lives in res://balance.tres.
## Per-player-count arrays are indexed by player_count - 1; counts above the array
## length use the last entry (keeps the design open for up to 6 players).

@export_group("Quota")
@export var quota_base: int = 1500
@export var quota_growth: float = 1.4
@export var shifts_per_cycle: int = 3
@export var quota_mult_by_players: Array[float] = [0.45, 0.65, 0.85, 1.0]

@export_group("Shift")
@export var shift_base_seconds: float = 780.0
@export var shift_bonus_seconds_by_players: Array[float] = [120.0, 60.0, 0.0, 0.0]
@export var whistle_grace_seconds: float = 60.0
## In-world clock: the shift runs from this hour to shift_end_hour.
@export var shift_start_hour: float = 6.0
@export var shift_end_hour: float = 14.0
## Hold time on the lift lever to send the Förderkorb up early.
@export var lift_lever_hold_seconds: float = 1.5

@export_group("Mine generation")
@export var mine_main_length_base: int = 7
@export var mine_main_length_per_cycle: int = 1
@export var mine_main_length_max: int = 14
@export var mine_branches_base: int = 3
@export var mine_branches_max: int = 7
@export var mine_branch_max_length: int = 3
@export var mine_loop_chance: float = 0.4
@export var mine_max_loops: int = 3

@export_group("Spawning")
@export var enemy_budget_by_players: Array[float] = [0.5, 0.7, 0.85, 1.0]
@export var loot_density_by_players: Array[float] = [0.6, 0.75, 0.9, 1.0]
## Loot pieces in a shift before the player-count factor: base + per_cycle * cycle.
@export var loot_count_base: float = 16.0
@export var loot_count_per_cycle: float = 2.0
## Each step of depth from the lift adds this share to a piece's value.
@export var loot_value_per_depth: float = 0.05
## Enemy budget before the player-count factor: base + per_cycle * cycle.
@export var enemy_budget_base: float = 6.0
@export var enemy_budget_per_cycle: float = 2.0
## Creatures only spawn this many steps from the lift or deeper.
@export var enemy_min_depth: int = 2
## Share of the budget spawned when the shift starts; the rest trickles in.
@export var enemy_start_share: float = 0.5
@export var enemy_trickle_seconds: float = 90.0

@export_group("Player")
@export var player_max_health: int = 100
@export var inventory_slots: int = 4
@export var solo_free_schubkarre: bool = true
@export var walk_speed: float = 3.4
@export var sprint_speed: float = 5.8
@export var crouch_speed: float = 1.8
@export var jump_velocity: float = 4.2
@export var stamina_seconds: float = 6.0
@export var stamina_regen_per_second: float = 0.22
@export var carry_medium_speed: float = 0.9
@export var carry_heavy_speed: float = 0.5
@export var schubkarre_speed: float = 0.85
@export var schubkarre_capacity_medium: int = 3
@export var interact_distance: float = 2.6
@export var watschn_damage: int = 8
@export var throw_speed: float = 5.0

@export_group("Lamp")
@export var lamp_fuel_seconds: float = 480.0
@export var lamp_low_fuel_share: float = 0.15
@export var lamp_energy: float = 2.3
@export var lamp_range: float = 11.0
## A Karbidpatrone refills this share of the tank.
@export var karbid_refill_share: float = 0.6

@export_group("Shout (Plärren)")
@export var shout_radius: float = 14.0
@export var shout_cooldown: float = 3.0

@export_group("Bergmandl")
@export var bergmandl_health: int = 30
@export var bergmandl_speed: float = 3.2
@export var bergmandl_flee_speed: float = 5.4
@export var bergmandl_sight: float = 14.0
@export var bergmandl_steal_from_hands_chance: float = 0.35
@export var bergmandl_scared_seconds: float = 8.0
@export var bergmandl_group_min: int = 2
@export var bergmandl_group_max: int = 3

@export_group("Creature voices")
## Minimum seconds between two lines of the same creature.
@export var voice_cooldown_per_creature: float = 10.0
## Minimum seconds between any two creature lines in the whole mine.
@export var voice_global_gap: float = 2.0
## Lines are only picked when a player is within this distance.
@export var voice_max_distance: float = 25.0
## Chance per second that an unseen creature mutters an idle line.
@export var voice_idle_chance: float = 0.04


func quota_for_cycle(cycle: int, player_count: int) -> int:
	var raw: float = quota_base * pow(quota_growth, cycle) * by_players(quota_mult_by_players, player_count)
	return int(round(raw))


func shift_seconds(player_count: int) -> float:
	return shift_base_seconds + by_players(shift_bonus_seconds_by_players, player_count)


func enemy_budget_mult(player_count: int) -> float:
	return by_players(enemy_budget_by_players, player_count)


func loot_density_mult(player_count: int) -> float:
	return by_players(loot_density_by_players, player_count)


func loot_count(cycle: int, player_count: int) -> int:
	return roundi((loot_count_base + loot_count_per_cycle * cycle) * loot_density_mult(player_count))


func enemy_budget(cycle: int, player_count: int) -> float:
	return (enemy_budget_base + enemy_budget_per_cycle * cycle) * enemy_budget_mult(player_count)


static func by_players(values: Array[float], player_count: int) -> float:
	assert(not values.is_empty())
	var index: int = clampi(player_count, 1, values.size()) - 1
	return values[index]
