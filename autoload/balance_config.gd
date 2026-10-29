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
## A loop's new passage is closed by a salt wall (a shortcut for the Spitzhacke) with this chance;
## the way into a dead end (a hidden niche) with the other.
@export var salt_wall_loop_chance: float = 0.5
@export var salt_wall_dead_end_chance: float = 0.25

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
## Two players carrying one heavy item together (DESIGN.md §3): speed factor for both, and how
## far apart they may get before the helper loses their grip.
@export var carry_together_speed: float = 0.95
@export var carry_together_max_distance: float = 2.8
## Landing faster than this (m/s) hurts; every m/s above it costs this much health.
@export var fall_damage_min_speed: float = 8.0
@export var fall_damage_per_speed: float = 12.0
## A dead miner's body carried back to the lift pays this "Sterbegeld" (DESIGN.md §3).
@export var sterbegeld: int = 60
## Seconds the shift goes on after the last living player died, before the lift goes up.
@export var all_dead_delay: float = 4.0

@export_group("Lamp")
@export var lamp_fuel_seconds: float = 480.0
@export var lamp_low_fuel_share: float = 0.15
@export var lamp_energy: float = 1.9
## How far the lamp's beam reaches (m).
@export var lamp_range: float = 14.0
## Half-angle of the beam (degrees): the carbide lamp's reflector, the Stirnlampe's lens.
@export var lamp_beam_degrees: float = 38.0
@export var stirnlampe_beam_degrees: float = 30.0
## The beam is this many times lamp_energy; the glow around the miner this much, this far.
@export var lamp_beam_energy: float = 1.7
@export var lamp_glow_energy: float = 0.22
@export var lamp_glow_range: float = 4.5
## A Karbidpatrone refills this share of the tank.
@export var karbid_refill_share: float = 0.6

@export_group("Shout (Plärren)")
@export var shout_radius: float = 14.0
@export var shout_cooldown: float = 3.0

@export_group("Voice chat")
## Proximity voice: full volume up close, silent beyond this distance (m).
@export var voice_chat_range: float = 30.0
@export var voice_chat_volume_db: float = 4.0
## Speaking louder than this (peak, 0–1) for `voice_shout_seconds` counts as a shout
## ("Plärren") and scares Bergmandl, like the shout key.
@export var voice_shout_level: float = 0.6
@export var voice_shout_seconds: float = 0.25

@export_group("Bergmandl")
@export var bergmandl_health: int = 30
@export var bergmandl_speed: float = 3.2
@export var bergmandl_flee_speed: float = 5.4
@export var bergmandl_sight: float = 14.0
@export var bergmandl_steal_from_hands_chance: float = 0.35
@export var bergmandl_scared_seconds: float = 8.0

@export_group("Creature spawning")
## How the enemy budget is spent per creature type (group sizes, limits, first cycle).
@export var creature_spawn_rules: Array[CreatureSpawnRule] = []
## Mine sections: unlock cycle, loot and enemy multipliers.
@export var biome_rules: Array[BiomeRule] = []

@export_group("Noise")
## How far (m) creatures that listen (Tatzelwurm) notice each kind of noise or vibration.
@export var noise_walk: float = 6.0
@export var noise_sprint: float = 22.0
@export var noise_landing: float = 10.0
@export var noise_heavy_drop: float = 20.0
@export var noise_shout: float = 25.0
@export var noise_schubkarre: float = 12.0
@export var noise_rail_cart: float = 20.0
@export var noise_boeller: float = 35.0
@export var noise_alphorn: float = 80.0
@export var noise_explosion: float = 60.0
@export var noise_bell: float = 40.0
## How often the host turns each player's movement into a noise (s).
@export var noise_step_seconds: float = 0.5

@export_group("Tools")
@export var stirnlampe_battery_seconds: float = 720.0
@export var stirnlampe_energy: float = 2.1
@export var stirnlampe_range: float = 16.0
@export var alphorn_cone_degrees: float = 70.0
@export var alphorn_range: float = 20.0
@export var alphorn_stun_seconds: float = 6.0
@export var alphorn_cooldown: float = 12.0
@export var boeller_fuse_seconds: float = 2.5
@export var boeller_radius: float = 3.0
@export var boeller_damage: int = 20
## Bergmandl this close to a bang run off like after a shout.
@export var boeller_scare_radius: float = 12.0
@export var throw_tool_speed: float = 9.0
@export var rauchbombe_fuse_seconds: float = 1.2
@export var obstler_heal: int = 25
@export var obstler_wobble_seconds: float = 20.0
@export var leberkaese_heal: int = 40
@export var leberkaese_eat_seconds: float = 4.0
@export var rauchbombe_radius: float = 5.0
@export var rauchbombe_seconds: float = 35.0
@export var seil_length: float = 7.0
@export var climb_speed: float = 2.0
## Climbing with a heavy item in your hands is this much slower.
@export var climb_heavy_factor: float = 0.4
@export var rail_cart_push_speed: float = 0.85
@export var rail_cart_capacity: int = 6
@export var pfeiferl_cart_speed: float = 3.0
@export var salt_wall_health: int = 100
@export var rubble_health: int = 60
@export var pfeiferl_cooldown: float = 4.0
## Funkgerät: creatures this close to either end put static on the line.
@export var funk_static_distance: float = 10.0
## Teammates' voices over the Funkgerät never get quieter than this (dB), at any distance.
@export var funk_volume_db: float = -6.0

@export_group("Hazards")
## Share of hazard spots that hold a firedamp pocket, plus this much per cycle.
@export var gas_share: float = 0.3
@export var gas_share_per_cycle: float = 0.05
@export var gas_radius: float = 3.0
## Seconds between an open flame entering the gas and the bang (time to put the lamp out).
@export var gas_fuse_seconds: float = 1.0
@export var gas_explosion_radius: float = 7.0
@export var gas_explosion_damage: int = 90
## The carbide flame flares this far from a pocket (the old miners' warning).
@export var gas_warning_distance: float = 2.5
@export var rockfall_interval: float = 75.0
@export var rockfall_chance: float = 0.5
@export var rockfall_warning_seconds: float = 2.5
@export var rockfall_radius: float = 2.2
@export var rockfall_damage: int = 45
## Share of rockfalls in tunnels that leave a pile blocking the way.
@export var rockfall_block_chance: float = 0.35
@export var brine_speed: float = 0.6
@export var brine_radius: float = 2.2
## Rotten ladders and bridges give way after this long under someone carrying something heavy.
@export var rotten_break_seconds: float = 0.6
## Brine splashing into the carbide lamp: it burns this many times faster.
@export var brine_lamp_drain: float = 3.0
@export var swim_speed: float = 1.6
## Seconds in deep water before something down there gets hold of you.
@export var deep_water_grace: float = 2.0
@export var deep_water_damage_per_second: float = 12.0
## Seconds the Salzsee ferry takes to cross.
@export var ferry_seconds: float = 7.0

@export_group("Tatzelwurm")
@export var tatzelwurm_health: int = 120
@export var tatzelwurm_speed: float = 4.5
@export var tatzelwurm_roam_speed: float = 1.5
@export var tatzelwurm_surface_seconds: float = 6.0
@export var tatzelwurm_lunge_distance: float = 3.2
@export var tatzelwurm_bite_damage: int = 55
## Players moving faster than this near a surfaced Tatzelwurm get lunged at (crouching is safe).
@export var tatzelwurm_motion_threshold: float = 2.2
@export var tatzelwurm_dive_seconds: float = 10.0

@export_group("Kasermandl")
@export var kasermandl_creep_speed: float = 2.2
@export var kasermandl_rush_speed: float = 4.8
@export var kasermandl_strike_damage: int = 35
@export var kasermandl_strike_cooldown: float = 12.0
## A lamp freezes it up to this share of the lamp's range; a hanging lantern this far (m).
@export var kasermandl_lamp_share: float = 0.9
@export var kasermandl_lantern_range: float = 6.0

@export_group("Schichtmeister")
## Seconds after the whistle until he comes for whoever is still down.
@export var schichtmeister_delay: float = 12.0
@export var schichtmeister_speed: float = 6.4
@export var schichtmeister_damage: int = 100

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


func spawn_rule(id: StringName) -> CreatureSpawnRule:
	for rule: CreatureSpawnRule in creature_spawn_rules:
		if rule.id == id:
			return rule
	return null


func biome_rule(id: StringName) -> BiomeRule:
	for rule: BiomeRule in biome_rules:
		if rule.id == id:
			return rule
	return null


## Share of hazard spots with a firedamp pocket in this cycle.
func gas_share_for_cycle(cycle: int) -> float:
	return clampf(gas_share + gas_share_per_cycle * cycle, 0.0, 0.8)


## Damage of an explosion at `distance` m: full at the centre, none at the edge.
func explosion_damage(distance: float, radius: float, full: int) -> int:
	if distance >= radius:
		return 0
	return ceili(full * (1.0 - distance / radius))


## Health lost when landing at `speed` m/s (0 for a soft landing).
func fall_damage(speed: float) -> int:
	if speed <= fall_damage_min_speed:
		return 0
	return ceili((speed - fall_damage_min_speed) * fall_damage_per_speed)


static func by_players(values: Array[float], player_count: int) -> float:
	assert(not values.is_empty())
	var index: int = clampi(player_count, 1, values.size()) - 1
	return values[index]
