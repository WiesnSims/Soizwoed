class_name CreatureSpawnRule
extends Resource
## How the shift's enemy budget is spent on one creature type (lives in balance.tres).

@export var id: StringName = &""
## Cost against the shift's enemy budget, per creature.
@export var budget_cost: float = 1.0
## How likely the spawner picks this creature against the others of the biome.
@export var weight: float = 1.0
## Only spawns from this shift on (0-based: 0 = the first).
@export var min_shift: int = 0
@export var group_min: int = 1
@export var group_max: int = 1
## At most this many alive at once (0 = no limit).
@export var max_alive: int = 0


## Whether one more group may spawn now.
func allowed(shift: int, alive: int, budget_left: float) -> bool:
	if shift < min_shift or weight <= 0.0 or budget_left < budget_cost:
		return false
	return max_alive <= 0 or alive < max_alive


## How many to spawn in one group: `roll` is the random group size, capped by budget and limit.
func group_size(roll: int, alive: int, budget_left: float) -> int:
	var size: int = clampi(roll, group_min, group_max)
	if budget_cost > 0.0:
		size = mini(size, floori(budget_left / budget_cost))
	if max_alive > 0:
		size = mini(size, max_alive - alive)
	return maxi(0, size)
