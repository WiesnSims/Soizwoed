class_name ItemData
extends Resource
## One loot item, tool or consumable. New content = a new .tres of this type plus its scene
## (a WorldItem). Loot spawns by `spawn_weight` from `min_depth` steps from the lift.

enum Kind { LOOT, TOOL, CONSUMABLE, AMMO }
enum WeightClass { LIGHT, MEDIUM, HEAVY }
## What the use key (left click) does with it in the hand (Player._use_active). The numbers
## behind each use live in balance.tres.
enum Use { NONE, REFILL_LAMP, HEADLAMP, ALPHORN, THROW, DRINK, EAT, ROPE, PFEIFERL, RADIO, WEAR, OPEN, EAT_OLD, REVIVE, SHOOT }
## Which pocket slots it goes in (Inventory): guns and the pick 1–3, throwables 4, the rest 5–9.
enum SlotKind { WEAPON, THROWABLE, ITEM }
## Something the item does by itself in the mine (host, Game._host_tick_specials).
enum Special { NONE, CUCKOO, CURSED }
## The shelves of the shop in the Gasthaus (ShopCategory order is the order of the tabs).
## UPGRADES holds the run upgrades (RunUpgrade), not items.
enum ShopCategory { WEAPONS, AMMO, THROWABLES, PROVISIONS, GEAR, UPGRADES }

@export var id: StringName = &""
## Translation key of the shown name.
@export var name_key: String = ""
@export var kind: Kind = Kind.LOOT
@export var weight_class: WeightClass = WeightClass.LIGHT
@export var value_min: int = 0
@export var value_max: int = 0
## Fragile items lose value on hard impacts.
@export var fragile: bool = false
## Share of the value lost per hard impact.
@export var fragile_loss: float = 0.25
## Price in the hub shop (tools and consumables); 0 = not sold.
@export var price: int = 0
@export var spawn_weight: float = 1.0
@export var min_depth: int = 0
## Only spawns in these mine sections (ChunkSet ids); empty = everywhere.
@export var biomes: Array[StringName] = []
@export var scene: PackedScene
## Melee damage when used as a weapon (0 = not a weapon).
@export var melee_damage: int = 0
## Its hits also break salt walls and rubble (the Spitzhacke).
@export var breaks_rock: bool = false
@export var use: Use = Use.NONE
@export var special: Special = Special.NONE
## A gun: how it shoots (its use is SHOOT).
@export var weapon: WeaponData
## The shift's Fundstück (DESIGN.md §5): one per shift from its section (`biomes`), never sold
## as loot or spawned by weight; the alarm pulses from it `pulse_mult` times as far.
@export var fundstueck: bool = false
@export var pulse_mult: float = 1.0
## Ammo boxes (kind AMMO): picking one up adds `ammo_amount` to the counter `ammo_type`.
@export var ammo_type: StringName = &""
@export var ammo_amount: int = 0


## Which shelf of the shop it is on.
func shop_category() -> ShopCategory:
	if kind == Kind.AMMO:
		return ShopCategory.AMMO
	match slot_kind():
		SlotKind.WEAPON:
			return ShopCategory.WEAPONS
		SlotKind.THROWABLE:
			return ShopCategory.THROWABLES
	if use == Use.DRINK or use == Use.EAT or use == Use.EAT_OLD or use == Use.REVIVE:
		return ShopCategory.PROVISIONS
	return ShopCategory.GEAR


func slot_kind() -> SlotKind:
	if weapon != null or (kind == Kind.TOOL and melee_damage > 0):
		return SlotKind.WEAPON
	if use == Use.THROW:
		return SlotKind.THROWABLE
	return SlotKind.ITEM


## Whether this loot may spawn in the mine section `biome`.
func spawns_in(biome: StringName) -> bool:
	return biomes.is_empty() or biome in biomes
