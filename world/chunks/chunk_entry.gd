class_name ChunkEntry
extends Resource
## One chunk the generator may place. `openings` are the sides the chunk can open in its
## own (unturned) orientation; it fits any cell whose open sides are a subset of them after
## turning. Unused openings are walled up by the chunk itself.

@export var scene: PackedScene
@export_flags("N", "E", "S", "W") var openings: int = 0
@export var weight: float = 1.0
## Only placed this many steps from the start or deeper.
@export var min_depth: int = 0
## The Förderkorb station: only used for the start cell.
@export var is_station: bool = false
## The track may run through it (no pits or water in the way).
@export var rails: bool = true
## Firedamp and brine may be put in it.
@export var hazards: bool = true
## At most this many in one mine (0 = no limit), e.g. the Salzmann shrine.
@export var max_count: int = 0
