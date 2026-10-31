class_name BalanceConfig
extends Resource
## Every balance number of the game. The one instance lives in res://balance.tres.
## Per-player-count arrays are indexed by player_count - 1; counts above the array
## length use the last entry (keeps the design open for up to 6 players).

@export_group("Fundstück")
## The company's cash bonus for a delivered Fundstück: base + per shift, times the section's
## loot multiplier (DESIGN.md §5).
@export var fundstueck_bonus_base: int = 150
@export var fundstueck_bonus_per_shift: int = 40
## Ehrenzeichen per delivered Fundstück (DESIGN.md §7): base, one more every this many shifts,
## the section's bonus (BiomeRule) and one more for a boss.
@export var ehrenzeichen_base: int = 1
@export var ehrenzeichen_every_shifts: int = 3
@export var ehrenzeichen_boss: int = 1
## Rückweg-timer (DESIGN.md §2): a base plus seconds per metre of the way from the Fundort to
## the lift, shrinking per shift down to a share; the extra share for small crews.
@export var rueckweg_base_seconds: float = 90.0
@export var rueckweg_seconds_per_metre: float = 1.25
@export var rueckweg_shrink_per_shift: float = 0.04
@export var rueckweg_min_share: float = 0.65
@export var rueckweg_bonus_by_players: Array[float] = [0.4, 0.15, 0.0, 0.0]
## After the alarm: a wave every this many seconds, spending this much enemy budget (before the
## crew factor), as long as fewer than the crew's limit are alive.
@export var wave_seconds: float = 30.0
@export var wave_budget_base: float = 3.0
@export var wave_budget_per_shift: float = 0.5
@export var wave_max_alive_by_players: Array[float] = [5.0, 7.0, 9.0, 10.0]
## Waves come out of the rock at least this far from every miner, out of their sight.
@export var wave_min_distance: float = 14.0
## Every creature within this reach senses the carrier, every this many seconds.
@export var alarm_pulse_seconds: float = 3.0
@export var alarm_pulse_reach: float = 45.0
## The Schichtmeister comes when this many seconds of the Rückweg are left.
@export var schichtmeister_rueckweg_left: float = 30.0
## Pulling the mine lever without the Fundstück: a second pull within this long gives up.
@export var give_up_confirm_seconds: float = 6.0

@export_group("Difficulty per shift")
## Boss chance per shift (0-based); shifts after the list always have one (DESIGN.md §8).
@export var boss_chance_by_shift: Array[float] = [0.0, 0.35, 0.7]
@export var boss_health_by_players: Array[float] = [0.5, 0.7, 0.85, 1.0]
@export var boss_health_per_shift: float = 0.12
## Creature health and damage grow by these shares per shift, up to these factors.
@export var enemy_health_per_shift: float = 0.05
@export var enemy_health_max: float = 2.0
@export var enemy_damage_per_shift: float = 0.04
@export var enemy_damage_max: float = 1.6
## Ammo boxes in the mine: per crew size (per miner) and scarcer every shift down to a share.
@export var ammo_found_by_players: Array[float] = [1.2, 1.0, 0.9, 0.8]
@export var ammo_scarcity_per_shift: float = 0.05
@export var ammo_scarcity_min: float = 0.5

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
## The main path (lift to Fundort) and the branches grow by these per shift (rounded down).
@export var mine_main_length_base: int = 7
@export var mine_main_length_per_shift: float = 0.5
@export var mine_main_length_max: int = 14
@export var mine_branches_base: int = 3
@export var mine_branches_per_shift: float = 0.5
@export var mine_branches_max: int = 7
@export var mine_branch_max_length: int = 3
@export var mine_loop_chance: float = 0.4
@export var mine_max_loops: int = 3
## A loop's new passage is closed by a salt wall (a shortcut for the Spitzhacke) with this chance;
## the way into a dead end (a hidden niche) with the other.
@export var salt_wall_loop_chance: float = 0.5
@export var salt_wall_dead_end_chance: float = 0.25

@export_group("Spawning")
@export var enemy_budget_by_players: Array[float] = [0.45, 0.7, 0.85, 1.0]
@export var loot_density_by_players: Array[float] = [0.6, 0.75, 0.9, 1.0]
## Loot pieces in a shift before the player-count factor: base + per_shift * shift.
@export var loot_count_base: float = 16.0
@export var loot_count_per_shift: float = 0.7
## Each step of depth from the lift adds this share to a piece's value.
@export var loot_value_per_depth: float = 0.05
## Enemy budget before the player-count factor: base + per_shift * shift.
@export var enemy_budget_base: float = 9.0
@export var enemy_budget_per_shift: float = 1.5
## Creatures only spawn this many steps from the lift or deeper.
@export var enemy_min_depth: int = 2
## Share of the budget spawned when the shift starts; the rest trickles in.
@export var enemy_start_share: float = 0.5
@export var enemy_trickle_seconds: float = 90.0

@export_group("Player")
@export var player_max_health: int = 100
## Pocket slots (owner decision): keys 1–3 weapons, 4 a throwable, 5–9 everything else.
@export var weapon_slots: int = 3
@export var throwable_slots: int = 1
@export var item_slots: int = 5
## Extra pocket slots that start locked (keys 0 and ß): the Knappenbrief's Grubentaschn opens
## the first for its owner, the Waffenkammer's Rucksack the second for the whole crew.
@export var extra_slots: int = 2
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

@export_group("Combat")
## Share of a shot's damage that hits a teammate (friendly fire, owner decision: on, 33 %).
@export var friendly_fire: float = 0.33
## Most of each ammo type a miner can carry.
@export var ammo_cap_pistole: int = 48
@export var ammo_cap_schrot: int = 20
@export var ammo_cap_gewehr: int = 20
@export var ammo_cap_leucht: int = 6
## The company's ration at the start of every shift: whoever has less gets topped up to this.
@export var ration_pistole: int = 24
## Handing ammo to a teammate (G while looking at them): how close, and the share of your
## rounds of that type that goes over (rounded up).
@export var hand_ammo_distance: float = 2.5
@export var hand_ammo_share: float = 0.5
## "Notration" (owner decision): a creature killed by a miner who is nearly out of ammo drops
## a few rounds. Nearly out = every gun they carry has at most this many rounds left (magazine
## plus spare) – only then; and how many rounds the drop holds.
@export var notration_left_pistole: int = 4
@export var notration_left_schrot: int = 1
@export var notration_left_gewehr: int = 1
@export var notration_pistole: int = 5
@export var notration_schrot: int = 2
@export var notration_gewehr: int = 2
## Ammo boxes lying in a mine per miner (at least one), before the section's share.
@export var ammo_boxes_per_player: float = 3.5
## Moving while aiming down the sights is this much slower.
@export var ads_move_speed: float = 0.6
## Downed (co-op, DESIGN.md §3): seconds until a downed miner bleeds out, crawling speed,
## how long a teammate holds E to get them up, and the health they get up with.
@export var downed_seconds: float = 20.0
@export var downed_crawl_speed: float = 0.8
@export var help_up_seconds: float = 3.0
@export var help_up_health: int = 30
## Solo instead: once per shift, a hit that would kill leaves 1 health and this many seconds
## of invulnerability ("Zweite Luft").
@export var second_wind_seconds: float = 3.0
## Creature health for 1–4 miners (solo is easier, DESIGN.md §8).
@export var enemy_health_by_players: Array[float] = [0.7, 0.85, 0.95, 1.0]
## Armour (Lederschurz, Grubenhelm): this share of every hit goes into the armour's points
## instead of health, until they are used up. Refilled before every shift.
@export var armour_absorb: float = 0.5
## The carrier of the Fundstück can still shove with an elbow (hands full): this much damage.
@export var shove_damage: int = 6
## A hit on a creature's weak spot (a dog's head) does this many times the damage; creatures
## with armour and a special weak spot (Percht, Tatzelwurm, bosses) have their own numbers.
@export var weak_spot_mult: float = 1.5

@export_group("Leuchtpistole")
## The flare (DESIGN.md §7): flies this fast with this share of gravity, hurts what it hits
## and sets it alight (seconds, damage per second), then burns where it lies, lighting this far.
@export var flare_speed: float = 30.0
@export var flare_gravity_share: float = 0.35
@export var flare_damage: int = 18
@export var flare_burn_seconds: float = 5.0
@export var flare_burn_dps: float = 7.0
@export var flare_light_seconds: float = 20.0
@export var flare_light_range: float = 11.0
## Creatures (and firedamp) this close to a burning flare catch fire.
@export var flare_ignite_radius: float = 1.4
## A flare in the Schichtmeister's face stuns him this long.
@export var flare_stun_seconds: float = 5.0

@export_group("Dynamit")
## The miners' own dynamite (thrown from slot 4): fuse, blast and how often the roof comes
## down with it and blocks the tunnel (DESIGN.md §4: rockfall blocks pursuers).
@export var dynamit_fuse_seconds: float = 3.0
@export var dynamit_radius: float = 5.5
@export var dynamit_damage: int = 110
@export var dynamit_roof_chance: float = 0.6

@export_group("Elites")
## "Raunacht" variants (DESIGN.md §6): from this shift (0-based) a creature may spawn as one,
## with this chance (growing per shift up to a limit); more health, faster, harder hits, and
## it drops a box of ammo when it dies.
@export var elite_first_shift: int = 4
@export var elite_chance_base: float = 0.12
@export var elite_chance_per_shift: float = 0.04
@export var elite_chance_max: float = 0.4
@export var elite_health_mult: float = 1.8
@export var elite_speed_mult: float = 1.2
@export var elite_damage_mult: float = 1.25

@export_group("Knocked down")
## A Percht's charge or a bell shockwave throws a miner: pushed this fast (m/s), on the floor
## and unable to act this long.
@export var knockdown_push: float = 7.0
@export var knockdown_seconds: float = 1.3

@export_group("Run upgrades")
## Everything the Waffenkammer sells besides items (DESIGN.md §7), for the whole crew and the
## rest of the run.
@export var run_upgrades: Array[RunUpgrade] = []

@export_group("Knappenbrief")
## The permanent upgrades bought with Ehrenzeichen (DESIGN.md §7), kept in each player's profile.
@export var perks: Array[Perk] = []
## Lamp colours a miner can wear (Perk target -> colour), mixed into the lamp's own colour.
@export var lamp_colours: Dictionary = {&"mond": Color(0.7, 0.82, 1.0), &"gruenspan": Color(0.5, 1.0, 0.6)}

@export_group("Crew")
## Pings (middle mouse): how far they reach, how long the mark stays, how often a miner can ping.
@export var ping_distance: float = 80.0
@export var ping_seconds: float = 5.0
@export var ping_cooldown: float = 0.4

@export_group("Überstunden")
## From this shift on (0-based) every shift adds a random modifier on top of the ones before
## (DESIGN.md §8): the kinds, and their numbers.
@export var overtime_first_shift: int = 9
@export var overtime_kinds: Array[StringName] = [&"finster", &"bergmandl", &"eile", &"panzerhunde", &"knapp", &"frueh", &"raunacht", &"zaach"]
## "eile": the Rückweg-timer is this much of what it would be.
@export var overtime_timer_mult: float = 0.75
## "panzerhunde": Grubenhunde take this share of the damage.
@export var overtime_dog_damage_taken: float = 0.6
## "knapp": this share of the ammo boxes lies in the mine.
@export var overtime_ammo_mult: float = 0.6
## "frueh": the Grubenpfeife blows after this share of the shift.
@export var overtime_whistle_mult: float = 0.5
## "raunacht": this much more elite chance.
@export var overtime_elite_bonus: float = 0.25
## "zaach": creatures have this many times the health.
@export var overtime_health_mult: float = 1.25

@export_group("Da Bergkini")
@export var bergkini_health: int = 420
@export var bergkini_speed: float = 3.0
## It wakes when a miner comes this close in sight, or anyone hits it.
@export var bergkini_wake_distance: float = 16.0
## Dynamite: thrown every few seconds (random around this) at miners up to this far.
@export var bergkini_throw_seconds: float = 3.6
@export var bergkini_throw_range: float = 18.0
@export var dynamite_fuse_seconds: float = 2.2
@export var dynamite_radius: float = 4.0
@export var dynamite_damage: int = 45
## Calls this many Bergmandl every this many seconds while fewer than the limit are around.
@export var bergkini_summon_seconds: float = 16.0
@export var bergkini_summon_count: int = 2
@export var bergkini_summon_max: int = 4
## A slap for whoever gets too close.
@export var bergkini_slap_damage: int = 20
@export var bergkini_slap_distance: float = 1.9
@export var bergkini_slap_cooldown: float = 1.6
## Changes cover after this many seconds, or when hit this much.
@export var bergkini_cover_seconds: float = 7.0
@export var bergkini_cover_after_damage: int = 60

@export_group("D'Seemuada")
## The giant Tatzelwurm in the Salzsee Fundort's lake (DESIGN.md §6 bosses): swims under the
## surface, comes up at the shore nearest a miner, bites whoever is within reach of the water
## or spits brine at whoever is further, then goes under again.
@export var seemuada_health: int = 520
@export var seemuada_swim_speed: float = 3.5
@export var seemuada_surface_seconds: float = 4.5
@export var seemuada_under_seconds: float = 2.5
@export var seemuada_bite_reach: float = 4.2
@export var seemuada_bite_damage: int = 40
@export var seemuada_bite_cooldown: float = 1.8
@export var seemuada_spit_range: float = 20.0
@export var seemuada_spit_damage: int = 14
@export var seemuada_spit_cooldown: float = 1.6
## Its head takes this many times the damage, the scaly neck this share; it dives after this
## much in one go up.
@export var seemuada_head_mult: float = 2.0
@export var seemuada_neck_mult: float = 0.5
@export var seemuada_pain_dive: int = 120

@export_group("Die Schiachpercht")
## The Percht as Die Tiefe's boss: more health, the bell shockwave (a wind-up, then everyone
## within the radius is hurt and knocked down unless rock is between), and her pack of dogs.
@export var schiachpercht_health: int = 1100
@export var schiachpercht_shockwave_seconds: float = 9.0
@export var schiachpercht_shockwave_windup: float = 1.3
@export var schiachpercht_shockwave_radius: float = 7.0
@export var schiachpercht_shockwave_damage: int = 30
@export var schiachpercht_dogs_seconds: float = 18.0
@export var schiachpercht_dogs: int = 3
@export var schiachpercht_dogs_max: int = 5

@export_group("Shout (Plärren)")
@export var shout_radius: float = 14.0
@export var shout_cooldown: float = 3.0
## The Jodler emote carries this far (m) and can only be sung every this many seconds.
@export var noise_jodler: float = 60.0
@export var jodler_cooldown: float = 8.0

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
## Stones: thrown at miners between these distances (m), every few seconds, for this damage.
@export var bergmandl_throw_min: float = 4.0
@export var bergmandl_throw_max: float = 14.0
@export var bergmandl_throw_seconds: float = 3.5
@export var bergmandl_stone_damage: int = 8
## Thrown stones fly this fast (m/s).
@export var stone_speed: float = 13.0

@export_group("Creature spawning")
## How the enemy budget is spent per creature type (group sizes, limits, first shift).
@export var creature_spawn_rules: Array[CreatureSpawnRule] = []
## Mine sections: unlock shift, loot and enemy multipliers.
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

@export_group("Loot")
## The Kuckucksuhr cuckoos every this many seconds (random between the two) and is heard this
## far (m) by creatures that listen.
@export var cuckoo_interval_min: float = 25.0
@export var cuckoo_interval_max: float = 60.0
@export var noise_cuckoo: float = 30.0
## Stück vom Mann im Salz: while someone carries it (or wheels it), creatures sense it every
## `curse_pulse_seconds`, from further away the longer it is carried.
@export var curse_pulse_seconds: float = 3.0
@export var curse_reach_start: float = 15.0
@export var curse_reach_per_second: float = 0.4
@export var curse_reach_max: float = 50.0
## Alte Jausenbox: chance there is still a Speckbrot inside.
@export var speckbrot_chance: float = 0.5
@export var speckbrot_heal: int = 15
@export var speckbrot_eat_seconds: float = 2.5
## A hundred years old: the chance it makes you sick, and how much that costs over how long.
## Food poisoning never kills (it stops at 1 health).
@export var speckbrot_poison_chance: float = 0.35
@export var speckbrot_poison_damage: int = 20
@export var speckbrot_poison_seconds: float = 10.0
## Wunderheilerin-Salbe: brings a miner back if used on their body within this many seconds of
## their death (DESIGN.md §3), with this much health.
@export var revive_window_seconds: float = 30.0
@export var revive_health: int = 40

@export_group("Hazards")
## Share of hazard spots that hold a firedamp pocket, plus this much per shift.
@export var gas_share: float = 0.3
@export var gas_share_per_shift: float = 0.02
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
@export var tatzelwurm_health: int = 150
@export var tatzelwurm_speed: float = 4.5
@export var tatzelwurm_roam_speed: float = 1.5
## Up out of the floor this long when nobody moves near it (the time to shoot its throat).
@export var tatzelwurm_surface_seconds: float = 8.0
@export var tatzelwurm_lunge_distance: float = 3.2
@export var tatzelwurm_bite_damage: int = 40
## Players moving faster than this near a surfaced Tatzelwurm get lunged at (crouching is safe).
@export var tatzelwurm_motion_threshold: float = 2.2
@export var tatzelwurm_dive_seconds: float = 10.0
## Its soft throat takes this many times the damage, its scales this share; after this much
## damage in one go up it dives.
@export var tatzelwurm_throat_mult: float = 2.5
@export var tatzelwurm_scale_mult: float = 0.35
@export var tatzelwurm_pain_dive: int = 70

@export_group("Kasermandl")
@export var kasermandl_health: int = 70
@export var kasermandl_creep_speed: float = 2.2
@export var kasermandl_rush_speed: float = 4.8
## Its touch drains this much health a second, for at most this long, then it slips away.
@export var kasermandl_drain_dps: float = 16.0
@export var kasermandl_drain_seconds: float = 2.5
@export var kasermandl_strike_cooldown: float = 8.0
## A lamp freezes it up to this share of the lamp's range; a hanging lantern this far (m).
@export var kasermandl_lamp_share: float = 0.9
@export var kasermandl_lantern_range: float = 6.0

@export_group("Schichtmeister")
## Seconds after the whistle until he comes for whoever is still down.
@export var schichtmeister_delay: float = 12.0
@export var schichtmeister_speed: float = 6.4
@export var schichtmeister_damage: int = 100
## Bullets and picks only make him stagger this long (he cannot be killed).
@export var schichtmeister_hit_stagger: float = 0.4

@export_group("Grubenhund")
@export var grubenhund_health: int = 55
## Hunting: faster than walking (3.4), a bit slower than sprinting (5.8).
@export var grubenhund_speed: float = 5.2
@export var grubenhund_roam_speed: float = 1.8
## It sees a lit lamp from this far, a miner in the dark from that far; crouching multiplies.
@export var grubenhund_sight_lit: float = 22.0
@export var grubenhund_sight_dark: float = 10.0
@export var grubenhund_crouch_factor: float = 0.5
@export var grubenhund_bite_damage: int = 12
@export var grubenhund_bite_cooldown: float = 1.3
@export var grubenhund_bite_distance: float = 1.5
## After a bite it springs back this long before coming again.
@export var grubenhund_backoff_seconds: float = 0.9
## Below 30 % health it runs off yelping once, this long.
@export var grubenhund_flee_seconds: float = 3.0
## Out of sight this long and it has lost the miner.
@export var grubenhund_lose_seconds: float = 5.0
## Dogs this close join when one finds a miner.
@export var grubenhund_pack_radius: float = 20.0

@export_group("Percht")
## Killable in v2, but armoured: hits on the carved mask do this many times the damage, hits
## anywhere else this share.
@export var percht_health: int = 650
@export var percht_mask_mult: float = 3.0
@export var percht_armour_mult: float = 0.25
## The charge: at a miner it sees between these distances, after a wind-up, in a straight
## line, knocking down whoever it hits; it stands dazed after running into rock.
@export var percht_charge_min: float = 5.0
@export var percht_charge_max: float = 14.0
@export var percht_charge_windup: float = 0.9
@export var percht_charge_speed: float = 10.0
@export var percht_charge_seconds: float = 1.2
@export var percht_charge_damage: int = 45
@export var percht_charge_cooldown: float = 7.0
@export var percht_wall_daze: float = 1.8
## It roars every this long while hunting and Grubenhunde come (this many, at most that many
## around).
@export var percht_roar_seconds: float = 22.0
@export var percht_roar_dogs: int = 2
@export var percht_roar_dogs_max: int = 4
@export var percht_patrol_speed: float = 1.6
@export var percht_investigate_speed: float = 2.4
## Faster than walking (3.4), slower than sprinting (5.8).
@export var percht_chase_speed: float = 4.0
## How far it sees a miner with a burning lamp, and one in the dark; crouching multiplies it.
@export var percht_sight_lit: float = 18.0
@export var percht_sight_dark: float = 6.0
@export var percht_crouch_factor: float = 0.4
## Out of sight this long and it has lost you; then it searches this long.
@export var percht_lose_seconds: float = 4.0
@export var percht_search_seconds: float = 8.0
@export var percht_damage: int = 60
@export var percht_strike_cooldown: float = 2.5

@export_group("Salzweibl")
@export var salzweibl_health: int = 45
## Its grip: the miner it caught is pinned (can't move or act) and loses this much health a
## second until a teammate shoots or shoves it off, or for at most this long (solo, co-op).
@export var salzweibl_pin_dps: float = 9.0
@export var salzweibl_pin_seconds_solo: float = 4.0
@export var salzweibl_pin_seconds: float = 14.0
@export var salzweibl_strike_distance: float = 2.0
## A miner with a teammate this close is not alone: it will not strike, it flees.
@export var salzweibl_together_distance: float = 7.0
## It calls every this many seconds (random between the two) while its miner is in range.
@export var salzweibl_call_min: float = 8.0
@export var salzweibl_call_max: float = 14.0
@export var salzweibl_call_range: float = 35.0
## Where it waits: this far from the miner it lures (m).
@export var salzweibl_lure_min: float = 10.0
@export var salzweibl_lure_max: float = 25.0
## After striking or fleeing it is gone this long, then waits somewhere new.
@export var salzweibl_hide_seconds: float = 25.0
## Voice snippets it keeps of each miner (only miners who allow it, DECISIONS.md).
@export var salzweibl_snippet_min_seconds: float = 0.6
@export var salzweibl_snippet_max_seconds: float = 4.0
@export var salzweibl_snippets_kept: int = 6

@export_group("Creature voices")
## Minimum seconds between two lines of the same creature.
@export var voice_cooldown_per_creature: float = 10.0
## Minimum seconds between any two creature lines in the whole mine.
@export var voice_global_gap: float = 2.0
## Lines are only picked when a player is within this distance.
@export var voice_max_distance: float = 25.0
## Chance per second that an unseen creature mutters an idle line.
@export var voice_idle_chance: float = 0.04


func shift_seconds(player_count: int) -> float:
	return shift_base_seconds + by_players(shift_bonus_seconds_by_players, player_count)


## Creature health for the crew size, growing with the shift (DESIGN.md §8).
func enemy_health_mult(player_count: int, shift: int = 0) -> float:
	return by_players(enemy_health_by_players, player_count) * minf(enemy_health_max, 1.0 + enemy_health_per_shift * shift)


## Creature damage grows with the shift.
func enemy_damage_mult(shift: int) -> float:
	return minf(enemy_damage_max, 1.0 + enemy_damage_per_shift * shift)


## Chance that the Fundstück of shift `shift` (0-based) is guarded by a boss.
func boss_chance(shift: int) -> float:
	return boss_chance_by_shift[shift] if shift >= 0 and shift < boss_chance_by_shift.size() else 1.0


## A boss's health factor: the crew size (solo bosses are half as tough) and the shift.
func boss_health_mult(shift: int, player_count: int) -> float:
	return by_players(boss_health_by_players, player_count) * (1.0 + boss_health_per_shift * shift)


## Seconds for the way back with the Fundstück over `metres` of mine (DESIGN.md §2): scales with
## the way so it is always possible, shrinks with the shift, more for small crews.
func rueckweg_seconds(shift: int, player_count: int, metres: float) -> float:
	var shrink: float = maxf(rueckweg_min_share, 1.0 - rueckweg_shrink_per_shift * shift)
	return (rueckweg_base_seconds + metres * rueckweg_seconds_per_metre) * shrink * (1.0 + by_players(rueckweg_bonus_by_players, player_count))


## Enemy budget of one wave after the alarm (always at least one creature's worth).
func wave_budget(shift: int, player_count: int) -> float:
	return maxf(1.0, (wave_budget_base + wave_budget_per_shift * shift) * enemy_budget_mult(player_count))


## No new wave while this many creatures are alive.
func wave_max_alive(player_count: int) -> int:
	return roundi(by_players(wave_max_alive_by_players, player_count))


## Ammo boxes lying in the mine: per miner, scaled per crew size, scarcer every shift (§8).
func ammo_box_count(shift: int, player_count: int) -> int:
	var scarcity: float = maxf(ammo_scarcity_min, 1.0 - ammo_scarcity_per_shift * shift)
	return maxi(1, roundi(ammo_boxes_per_player * player_count * by_players(ammo_found_by_players, player_count) * scarcity))


## The company's cash bonus for the Fundstück of shift `shift`.
func fundstueck_bonus(shift: int, loot_mult: float) -> int:
	return roundi((fundstueck_bonus_base + fundstueck_bonus_per_shift * shift) * loot_mult)


## Ehrenzeichen for delivering the Fundstück of shift `shift`.
func ehrenzeichen(shift: int, section_bonus: int, boss: bool) -> int:
	return ehrenzeichen_base + shift / maxi(1, ehrenzeichen_every_shifts) + section_bonus + (ehrenzeichen_boss if boss else 0)


## A hit of `amount` on a miner wearing `armour` points: [health lost, armour points lost].
func armour_split(amount: int, armour: int) -> Vector2i:
	var absorbed: int = mini(armour, roundi(amount * armour_absorb))
	return Vector2i(amount - absorbed, absorbed)


## How long the lamp's carbide and the Stirnlampe's battery last, from the crew's upgrades.
func lamp_fuel_mult(levels: Dictionary) -> float:
	var mult: float = 1.0
	for upgrade: RunUpgrade in run_upgrades:
		if upgrade.effect == RunUpgrade.Effect.LAMP_BATTERY:
			mult += upgrade.total(int(levels.get(upgrade.id, 0)))
	return mult


## Whether the crew's upgrades open the Rucksack slot.
func crew_pocket_slot(levels: Dictionary) -> bool:
	for upgrade: RunUpgrade in run_upgrades:
		if upgrade.effect == RunUpgrade.Effect.POCKET_SLOT and int(levels.get(upgrade.id, 0)) > 0:
			return true
	return false


func perk(id: StringName) -> Perk:
	for entry: Perk in perks:
		if entry.id == id:
			return entry
	return null


## Perk id -> Perk, for checking a saved profile.
func perks_by_id() -> Dictionary:
	var known: Dictionary = {}
	for entry: Perk in perks:
		known[entry.id] = entry
	return known


## What the perks at `levels` (perk id -> level) with `effect` add up to (only those aimed at
## `target`, when one is given).
func perk_total(effect: Perk.Effect, levels: Dictionary, target: StringName = &"") -> float:
	var sum: float = 0.0
	for entry: Perk in perks:
		if entry.effect == effect and (target == &"" or entry.target == target):
			sum += entry.total(int(levels.get(entry.id, 0)))
	return sum


## A miner's most health with these perks.
func max_health(levels: Dictionary) -> int:
	return player_max_health + roundi(perk_total(Perk.Effect.MAX_HEALTH, levels))


## Seconds to help a teammate up, for a helper with these perks.
func help_up_time(levels: Dictionary) -> float:
	return help_up_seconds * maxf(0.3, 1.0 - perk_total(Perk.Effect.REVIVE_SPEED, levels))


## The kit's ration of `ammo_type` for a miner with these perks: the company's plus their own.
func kit_ammo(ammo_type: StringName, levels: Dictionary) -> int:
	return (ration_pistole if ammo_type == &"pistole" else 0) + roundi(perk_total(Perk.Effect.START_AMMO, levels, ammo_type))


## The gun a start-weapon perk brings (empty for anything else or a perk not bought).
func start_weapon_item(perk_id: StringName, levels: Dictionary) -> StringName:
	var entry: Perk = perk(perk_id)
	if entry == null or entry.effect != Perk.Effect.START_WEAPON or int(levels.get(perk_id, 0)) <= 0:
		return &""
	return entry.target


## The colour a worn lamp-colour perk gives (white: none).
func lamp_tint(perk_id: StringName) -> Color:
	var entry: Perk = perk(perk_id)
	if entry == null or entry.effect != Perk.Effect.LAMP_COLOUR:
		return Color.WHITE
	return lamp_colours.get(entry.target, Color.WHITE)


## Picks the Überstunden modifier for a new shift: one of those not yet active (none left: none).
func roll_overtime(active: Array, rng: RandomNumberGenerator) -> StringName:
	var left: Array[StringName] = []
	for kind: StringName in overtime_kinds:
		if not active.has(kind):
			left.append(kind)
	return left[rng.randi_range(0, left.size() - 1)] if not left.is_empty() else &""


func run_upgrade(id: StringName) -> RunUpgrade:
	for upgrade: RunUpgrade in run_upgrades:
		if upgrade.id == id:
			return upgrade
	return null


## The ammo cap of `ammo_type` plus what the crew's upgrades add (`levels`: upgrade id -> level).
func ammo_cap(ammo_type: StringName, levels: Dictionary = {}) -> int:
	var cap: int = 99
	match ammo_type:
		&"pistole":
			cap = ammo_cap_pistole
		&"schrot":
			cap = ammo_cap_schrot
		&"gewehr":
			cap = ammo_cap_gewehr
		&"leucht":
			cap = ammo_cap_leucht
	for upgrade: RunUpgrade in run_upgrades:
		if upgrade.effect == RunUpgrade.Effect.AMMO_CAP and upgrade.target == ammo_type:
			cap += roundi(upgrade.total(int(levels.get(upgrade.id, 0))))
	return cap


## Armour points a miner starts the shift with, from the crew's upgrades.
func armour_points(levels: Dictionary) -> int:
	var points: float = 0.0
	for upgrade: RunUpgrade in run_upgrades:
		if upgrade.effect == RunUpgrade.Effect.ARMOUR:
			points += upgrade.total(int(levels.get(upgrade.id, 0)))
	return roundi(points)


## The lamp's reach factor from the crew's upgrades.
func lamp_range_mult(levels: Dictionary) -> float:
	var mult: float = 1.0
	for upgrade: RunUpgrade in run_upgrades:
		if upgrade.effect == RunUpgrade.Effect.LAMP_RANGE:
			mult += upgrade.total(int(levels.get(upgrade.id, 0)))
	return mult


## Rounds of `ammo_type` left at which a miner counts as nearly out (Notration). Flares are
## no ammo to fight with: a flare gun never keeps anyone from counting as out.
func notration_left(ammo_type: StringName) -> int:
	match ammo_type:
		&"schrot":
			return notration_left_schrot
		&"gewehr":
			return notration_left_gewehr
		&"leucht":
			return 1 << 20
	return notration_left_pistole


## How many rounds a Notration drop of `ammo_type` holds.
func notration_rounds(ammo_type: StringName) -> int:
	match ammo_type:
		&"schrot":
			return notration_schrot
		&"gewehr":
			return notration_gewehr
	return notration_pistole


## Chance that a creature of shift `shift` (0-based) spawns as a Raunacht elite.
func elite_chance(shift: int) -> float:
	if shift < elite_first_shift:
		return 0.0
	return minf(elite_chance_max, elite_chance_base + elite_chance_per_shift * (shift - elite_first_shift))


## Whether a miner with these rounds left per ammo type (magazines plus spare, one entry per type
## of gun they carry) is nearly out of ammo: no gun at all, or every type at its Notration limit.
func notration_due(rounds_left: Dictionary) -> bool:
	for ammo_type: StringName in rounds_left:
		if int(rounds_left[ammo_type]) > notration_left(ammo_type):
			return false
	return true


## How many rounds go over when handing ammo: the share of what the giver has (rounded up),
## no more than the receiver can still carry.
func ammo_to_hand_over(giver_has: int, receiver_has: int, ammo_type: StringName, levels: Dictionary = {}) -> int:
	return clampi(ceili(giver_has * hand_ammo_share), 0, maxi(0, ammo_cap(ammo_type, levels) - receiver_has))


func enemy_budget_mult(player_count: int) -> float:
	return by_players(enemy_budget_by_players, player_count)


func loot_density_mult(player_count: int) -> float:
	return by_players(loot_density_by_players, player_count)


func loot_count(shift: int, player_count: int) -> int:
	return roundi((loot_count_base + loot_count_per_shift * shift) * loot_density_mult(player_count))


func enemy_budget(shift: int, player_count: int) -> float:
	return (enemy_budget_base + enemy_budget_per_shift * shift) * enemy_budget_mult(player_count)


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


## Share of hazard spots with a firedamp pocket in this shift.
func gas_share_for_shift(shift: int) -> float:
	return clampf(gas_share + gas_share_per_shift * shift, 0.0, 0.8)


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
