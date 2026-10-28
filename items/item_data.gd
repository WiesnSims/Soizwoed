class_name ItemData
extends Resource
## One loot item, tool or consumable. New content = a new .tres of this type plus its scene
## (a WorldItem). Loot spawns by `spawn_weight` from `min_depth` steps from the lift.

enum Kind { LOOT, TOOL, CONSUMABLE }
enum WeightClass { LIGHT, MEDIUM, HEAVY }

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
@export var scene: PackedScene
## Melee damage when used as a weapon (0 = not a weapon).
@export var melee_damage: int = 0
