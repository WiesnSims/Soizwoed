class_name BalanceConfig
extends Resource
## Every balance number of the game. The one instance lives in res://balance.tres.
## Per-player-count arrays are indexed by player_count - 1; counts above the array
## length use the last entry (keeps the design open for up to 6 players).

@export_group("Quota")
@export var quota_base: int = 150
@export var quota_growth: float = 1.4
@export var shifts_per_cycle: int = 3
@export var quota_mult_by_players: Array[float] = [0.45, 0.65, 0.85, 1.0]

@export_group("Shift")
@export var shift_base_seconds: float = 780.0
@export var shift_bonus_seconds_by_players: Array[float] = [120.0, 60.0, 0.0, 0.0]
@export var whistle_grace_seconds: float = 60.0

@export_group("Spawning")
@export var enemy_budget_by_players: Array[float] = [0.5, 0.7, 0.85, 1.0]
@export var loot_density_by_players: Array[float] = [0.6, 0.75, 0.9, 1.0]

@export_group("Player")
@export var player_max_health: int = 100
@export var inventory_slots: int = 4
@export var solo_free_schubkarre: bool = true

@export_group("Creature voices")
## Minimum seconds between two lines of the same creature.
@export var voice_cooldown_per_creature: float = 10.0
## Minimum seconds between any two creature lines in the whole mine.
@export var voice_global_gap: float = 2.0
## Lines are only picked when a player is within this distance.
@export var voice_max_distance: float = 25.0


func quota_for_cycle(cycle: int, player_count: int) -> int:
	var raw: float = quota_base * pow(quota_growth, cycle) * by_players(quota_mult_by_players, player_count)
	return int(round(raw))


func shift_seconds(player_count: int) -> float:
	return shift_base_seconds + by_players(shift_bonus_seconds_by_players, player_count)


func enemy_budget_mult(player_count: int) -> float:
	return by_players(enemy_budget_by_players, player_count)


func loot_density_mult(player_count: int) -> float:
	return by_players(loot_density_by_players, player_count)


static func by_players(values: Array[float], player_count: int) -> float:
	assert(not values.is_empty())
	var index: int = clampi(player_count, 1, values.size()) - 1
	return values[index]
