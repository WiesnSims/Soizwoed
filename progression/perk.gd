class_name Perk
extends Resource
## One entry on the Knappenbrief (DESIGN.md §7 "Permanent upgrades"): bought with Ehrenzeichen,
## kept forever in the player's own profile. Each level costs its own price; every level adds
## `per_level`. Cosmetics have one level and change only how a miner looks. The perks live in
## balance.tres (BalanceConfig.perks).

enum Effect {
	## Health points on top of the base.
	MAX_HEALTH,
	## A gun (`target`: item id) in the kit before every shift; one level. The owner picks which
	## of the bought ones to take along.
	START_WEAPON,
	## Rounds of `target` (ammo type) the kit tops the counter up to.
	START_AMMO,
	## Money the crew's till gets when this miner joins a run.
	START_MONEY,
	## Armour points on top of the crew's at the start of every shift.
	START_ARMOUR,
	## Helping a teammate up is quicker, as a share taken off.
	REVIVE_SPEED,
	## One more pocket slot (key 0).
	POCKET_SLOT,
	## A hat (`target`: hat id) others see on your head; one level.
	HAT,
	## A lamp colour (`target`: colour id); one level.
	LAMP_COLOUR,
}

@export var id: StringName = &""
## Translation keys: the name, and `name_key + "_DESC"` says what it does.
@export var name_key: String = ""
@export var effect: Effect = Effect.MAX_HEALTH
@export var target: StringName = &""
@export var per_level: float = 0.0
## The price of each level in Ehrenzeichen, in order; the number of prices is the highest level.
@export var prices: Array[int] = []
## The item whose picture the card shows (empty: a drawn icon).
@export var icon_item: StringName = &""


func max_level() -> int:
	return prices.size()


## The price of the next level after `level` (0 when it is maxed out).
func price_after(level: int) -> int:
	return prices[level] if level >= 0 and level < prices.size() else 0


## What `level` levels add up to.
func total(level: int) -> float:
	return per_level * clampi(level, 0, max_level())


## Cosmetics and start weapons are worn or taken along by choice once bought.
func is_choice() -> bool:
	return effect in [Effect.START_WEAPON, Effect.HAT, Effect.LAMP_COLOUR]


func is_cosmetic() -> bool:
	return effect in [Effect.HAT, Effect.LAMP_COLOUR]
