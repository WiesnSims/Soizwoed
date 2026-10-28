class_name ItemData
extends Resource
## One loot item, tool or consumable. New content = a new .tres of this type.

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
## Price in the hub shop (tools and consumables).
@export var price: int = 0
@export var scene: PackedScene
