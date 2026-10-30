class_name RunUpgrade
extends Resource
## One upgrade the Waffenkammer sells for money (DESIGN.md §7 "Run upgrades"): it holds for the
## whole crew until the run ends. Each level costs its own price; every level adds `per_level`
## to what it changes. The upgrades live in balance.tres (BalanceConfig.run_upgrades).

enum Effect {
	## A gun's damage per pellet, as a share (0.2 = +20 %).
	DAMAGE,
	## Rounds in a gun's magazine.
	MAGAZINE,
	## A gun's reload time, as a share taken off (0.2 = 20 % faster).
	RELOAD,
	## A gun's spread, as a share taken off.
	SPREAD,
	## Rounds of an ammo type a miner can carry.
	AMMO_CAP,
	## Armour points every miner starts the shift with.
	ARMOUR,
	## The lamp's reach, as a share.
	LAMP_RANGE,
}

@export var id: StringName = &""
## Translation keys: the name, and `name_key + "_DESC"` says what it does.
@export var name_key: String = ""
@export var effect: Effect = Effect.DAMAGE
## The gun's item id (weapon effects) or the ammo type (AMMO_CAP); empty otherwise.
@export var target: StringName = &""
@export var per_level: float = 0.2
## The price of each level, in order; the number of prices is the highest level.
@export var prices: Array[int] = []
## The item whose picture the shop card shows (empty: a drawn icon).
@export var icon_item: StringName = &""


func max_level() -> int:
	return prices.size()


## The price of the next level after `level` (0 when it is maxed out).
func price_after(level: int) -> int:
	return prices[level] if level >= 0 and level < prices.size() else 0


## What `level` levels add up to.
func total(level: int) -> float:
	return per_level * clampi(level, 0, max_level())


## Whether this upgrade changes the gun `weapon_id`.
func changes_weapon(weapon_id: StringName) -> bool:
	return target == weapon_id and effect in [Effect.DAMAGE, Effect.MAGAZINE, Effect.RELOAD, Effect.SPREAD]


## A copy of `base` with every weapon upgrade in `upgrades` for `weapon_id` applied at the
## crew's `levels` (upgrade id -> level). `base` itself is never changed.
static func upgraded_weapon(base: WeaponData, weapon_id: StringName, upgrades: Array[RunUpgrade], levels: Dictionary) -> WeaponData:
	var weapon: WeaponData = base.duplicate() as WeaponData
	for upgrade: RunUpgrade in upgrades:
		if not upgrade.changes_weapon(weapon_id):
			continue
		var amount: float = upgrade.total(int(levels.get(upgrade.id, 0)))
		match upgrade.effect:
			Effect.DAMAGE:
				weapon.damage = roundi(base.damage * (1.0 + amount))
			Effect.MAGAZINE:
				weapon.magazine = base.magazine + roundi(amount)
			Effect.RELOAD:
				weapon.reload_seconds = base.reload_seconds * maxf(0.2, 1.0 - amount)
			Effect.SPREAD:
				weapon.spread_hip = base.spread_hip * maxf(0.2, 1.0 - amount)
				weapon.spread_ads = base.spread_ads * maxf(0.2, 1.0 - amount)
	return weapon
