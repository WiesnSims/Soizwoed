class_name WeaponMath
extends RefCounted
## The arithmetic of guns, kept pure so it can be unit tested: spread, pellet directions,
## damage falloff, reloading, friendly fire.


## The cone half-angle (degrees) a shot flies in right now.
static func spread(weapon: WeaponData, aiming: bool, moving: bool, crouching: bool) -> float:
	var cone: float = weapon.spread_ads if aiming else weapon.spread_hip
	if moving:
		cone *= weapon.spread_moving
	if crouching:
		cone *= weapon.spread_crouched
	return cone


## `count` directions inside a cone of `half_angle` degrees around `forward`, spread evenly
## over the cone's area (not bunched in the middle).
static func pellet_directions(forward: Vector3, half_angle: float, count: int, rng: RandomNumberGenerator) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var axis: Vector3 = forward.normalized()
	var side: Vector3 = axis.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = axis.cross(Vector3.RIGHT)
	side = side.normalized()
	for i: int in count:
		var off: float = deg_to_rad(half_angle) * sqrt(rng.randf())
		var around: float = rng.randf() * TAU
		var tilted: Vector3 = axis.rotated(side, off)
		result.append(tilted.rotated(axis, around).normalized())
	return result


## Damage of one pellet hitting at `distance` m (0 beyond the range).
static func damage_at(weapon: WeaponData, distance: float) -> int:
	if distance > weapon.range:
		return 0
	if distance <= weapon.falloff_start:
		return weapon.damage
	var t: float = (distance - weapon.falloff_start) / maxf(0.001, weapon.range - weapon.falloff_start)
	return maxi(1, roundi(weapon.damage * lerpf(1.0, weapon.falloff_min, t)))


## How many rounds one reload step moves from the counter into the magazine.
static func rounds_to_load(weapon: WeaponData, in_magazine: int, reserve: int) -> int:
	var room: int = weapon.magazine - in_magazine
	if room <= 0 or reserve <= 0:
		return 0
	return mini(1 if weapon.reload_per_round else room, reserve)


## Damage a teammate takes from your shot (friendly fire, DESIGN.md §3). Never 0 for a hit.
static func friendly_damage(damage: int, share: float) -> int:
	if damage <= 0 or share <= 0.0:
		return 0
	return maxi(1, roundi(damage * share))
