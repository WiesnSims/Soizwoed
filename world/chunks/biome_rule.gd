class_name BiomeRule
extends Resource
## Balance numbers of one mine section (lives in balance.tres; the chunks are in its ChunkSet).

@export var id: StringName = &""
## The section can be picked in the Gasthaus from this quota cycle on (0 = from the start).
@export var unlock_cycle: int = 0
## Loot values and the enemy budget are multiplied by these (deeper = richer and nastier).
@export var loot_value_mult: float = 1.0
@export var enemy_budget_mult: float = 1.0
