class_name Schubkarre
extends WorldItem
## The wheelbarrow: pushed with both hands, carries one heavy or up to three smaller loot
## items at near-normal speed (DESIGN.md §7). Loot is loaded by looking at it while pushing,
## or by looking at the parked barrow while holding loot. Loud on gravel.

var cargo: Array[WorldItem] = []

@onready var slots: Array[Node3D] = [$Slot1, $Slot2, $Slot3]
@onready var rattle: AudioStreamPlayer3D = $Rattle


func interaction_text(player: Player) -> String:
	if state != State.FREE:
		return ""
	var carried: WorldItem = player.inventory.hands as WorldItem
	if carried != null and carried.is_loot():
		return tr("PROMPT_LOAD_CART") if can_load(carried) else tr("PROMPT_CART_FULL")
	return tr("PROMPT_PUSH_CART")


## Loads the loot the player is holding; false when there is nothing to load.
func try_load_from(player: Player) -> bool:
	var carried: WorldItem = player.inventory.hands as WorldItem
	if carried == null or carried == self or not carried.is_loot():
		return false
	Game.instance.request_load_cart.rpc_id(1, get_path(), carried.get_path())
	return true


func units(item: WorldItem) -> int:
	return Balance.config.schubkarre_capacity_medium if item.data.weight_class == ItemData.WeightClass.HEAVY else 1


func used_units() -> int:
	var total: int = 0
	for item: WorldItem in cargo:
		total += units(item)
	return total


func can_load(item: WorldItem) -> bool:
	return used_units() + units(item) <= Balance.config.schubkarre_capacity_medium


## The first free slot to put `item` on (a heavy item takes the middle).
func free_slot(item: WorldItem) -> Node3D:
	if units(item) > 1:
		return slots[1]
	for slot: Node3D in slots:
		var taken: bool = false
		for loaded: WorldItem in cargo:
			if loaded.follow == slot:
				taken = true
		if not taken:
			return slot
	return null


func _physics_process(delta: float) -> void:
	super(delta)
	var moving: bool = state == State.HELD and follow != null
	if moving:
		var player: Player = Game.instance.player_by_peer(holder_peer)
		moving = player != null and Vector2(player.velocity.x, player.velocity.z).length() > 0.5
	if moving and not rattle.playing:
		rattle.play()
	elif not moving and rattle.playing:
		rattle.stop()
