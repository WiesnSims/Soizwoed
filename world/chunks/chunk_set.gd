class_name ChunkSet
extends Resource
## All chunks of one biome (mine section), and which creatures live there. Its balance numbers
## (unlock cycle, loot and enemy multipliers) are a BiomeRule in balance.tres with the same id.

@export var id: StringName = &""
@export var biome_name_key: String = ""
@export var cell_size: float = 12.0
@export var entries: Array[ChunkEntry] = []
## A chunk using fewer of its openings than it has is this much less likely to be picked.
@export var superset_weight: float = 0.25
## Creature ids the shift's enemy budget is spent on (rules in balance.tres).
@export var creatures: Array[StringName] = []
## How much of the sound comes back from the rock (0 = dry tunnels, 1 = a cathedral).
@export_range(0.0, 1.0) var echo: float = 0.2
