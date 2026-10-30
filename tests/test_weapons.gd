extends GutTest
## Weapon arithmetic (WeaponMath) and the gun data the game ships with.

var pistol: WeaponData
var flinte: WeaponData


func before_each() -> void:
	pistol = (load("res://items/data/dienstpistole.tres") as ItemData).weapon
	flinte = (load("res://items/data/salzschrot_flinte.tres") as ItemData).weapon


func test_guns_are_data() -> void:
	assert_eq(pistol.ammo_type, &"pistole")
	assert_eq(pistol.magazine, 8)
	assert_true(pistol.usable_downed, "the pistol works lying down")
	assert_eq(flinte.pellets, 8)
	assert_true(flinte.reload_per_round)
	assert_false(flinte.usable_downed)


func test_spread_narrows_when_aiming_and_crouching() -> void:
	var hip: float = WeaponMath.spread(pistol, false, false, false)
	assert_lt(WeaponMath.spread(pistol, true, false, false), hip)
	assert_gt(WeaponMath.spread(pistol, false, true, false), hip)
	assert_lt(WeaponMath.spread(pistol, false, false, true), hip)


func test_pellets_stay_inside_the_cone() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var forward: Vector3 = Vector3(0.3, -0.2, -1.0).normalized()
	var directions: Array[Vector3] = WeaponMath.pellet_directions(forward, 7.0, 200, rng)
	assert_eq(directions.size(), 200)
	var widest: float = 0.0
	for direction: Vector3 in directions:
		widest = maxf(widest, rad_to_deg(direction.angle_to(forward)))
	assert_lte(widest, 7.01)
	assert_gt(widest, 5.0, "pellets use the whole cone")


func test_straight_up_still_works() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for direction: Vector3 in WeaponMath.pellet_directions(Vector3.UP, 3.0, 10, rng):
		assert_almost_eq(direction.length(), 1.0, 0.001)


func test_damage_falls_off_with_distance() -> void:
	assert_eq(WeaponMath.damage_at(flinte, 2.0), flinte.damage)
	assert_eq(WeaponMath.damage_at(flinte, flinte.range + 1.0), 0)
	var far: int = WeaponMath.damage_at(flinte, flinte.range)
	assert_lt(far, flinte.damage)
	assert_gte(far, 1)
	assert_eq(WeaponMath.damage_at(pistol, pistol.falloff_start), pistol.damage)


func test_reload_takes_what_fits_and_what_is_there() -> void:
	assert_eq(WeaponMath.rounds_to_load(pistol, 3, 20), 5)
	assert_eq(WeaponMath.rounds_to_load(pistol, 3, 2), 2)
	assert_eq(WeaponMath.rounds_to_load(pistol, 8, 20), 0)
	assert_eq(WeaponMath.rounds_to_load(pistol, 0, 0), 0)
	assert_eq(WeaponMath.rounds_to_load(flinte, 0, 5), 1, "the shotgun loads shell by shell")


func test_friendly_fire_is_a_third() -> void:
	var share: float = (load("res://balance.tres") as BalanceConfig).friendly_fire
	assert_almost_eq(share, 0.33, 0.001)
	assert_eq(WeaponMath.friendly_damage(30, share), 10)
	assert_eq(WeaponMath.friendly_damage(1, share), 1, "a hit always hurts a little")
	assert_eq(WeaponMath.friendly_damage(0, share), 0)


func test_shotgun_beats_pistol_close_and_loses_far() -> void:
	var close_flinte: int = WeaponMath.damage_at(flinte, 3.0) * flinte.pellets
	var close_pistol: int = WeaponMath.damage_at(pistol, 3.0)
	assert_gt(close_flinte, close_pistol * 3)
	assert_eq(WeaponMath.damage_at(flinte, 30.0), 0)
	assert_gt(WeaponMath.damage_at(pistol, 30.0), 0)
