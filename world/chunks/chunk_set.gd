class_name ChunkSet
extends Resource
## All chunks of one biome.

@export var biome_name_key: String = ""
@export var cell_size: float = 12.0
@export var entries: Array[ChunkEntry] = []
## A chunk using fewer of its openings than it has is this much less likely to be picked.
@export var superset_weight: float = 0.25
