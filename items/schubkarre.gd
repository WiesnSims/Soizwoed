class_name Schubkarre
extends WorldItem
## The wheelbarrow: pushed with both hands, carries one heavy or up to three smaller loot
## items at near-normal speed (DESIGN.md §7). Loot gets in by looking at it while pushing,
## by looking at the parked barrow and pressing E (hands) or G (anything), or simply by
## landing in the bed. Loud on gravel.

## The bed in the barrow's own space: loot that comes to rest here is loaded.
const BED: AABB = AABB(Vector3(-0.45, 0.2, -0.55), Vector3(0.9, 0.8, 1.1))
const CATCH_SECONDS: float = 0.25

var cargo: Array[WorldItem] = []

var _catch_left: float = 0.0

@onready var slots: Array[Node3D] = [$Slot1, $Slot2, $Slot3]
@onready var rattle: AudioStreamPlayer3D = $Rattle


func _ready() -> void:
	super()
	# Moves before its cargo each frame, so the load never trails behind.
	process_priority = -1


func interaction_text(player: Player) -> String:
	if state != State.FREE:
		return ""
	var carried: WorldItem = player.inventory.hands as WorldItem
	if carried != null and carried.is_loot():
		return tr("PROMPT_LOAD_CART") if can_load(carried) else tr("PROMPT_CART_FULL")
	var pocket: WorldItem = player.inventory.slots[player.inventory.selected] as WorldItem
	if carried == null and pocket != null and pocket.is_loot() and can_load(pocket):
		return tr("PROMPT_PUSH_CART") + "   " + tr("PROMPT_CART_DROP_IN") % pocket.display_name()
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
	if multiplayer.is_server() and (state == State.FREE or state == State.HELD):
		_catch_left -= delta
		if _catch_left <= 0.0:
			_catch_left = CATCH_SECONDS
			_catch_loot()
	var moving: bool = state == State.HELD and follow != null
	if moving:
		var player: Player = Game.instance.player_by_peer(holder_peer)
		moving = player != null and Vector2(player.velocity.x, player.velocity.z).length() > 0.5
	if moving and not rattle.playing:
		rattle.play()
	elif not moving and rattle.playing:
		rattle.stop()


## Host: loot lying still in the bed (dropped or thrown in) gets loaded properly.
func _catch_loot() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"items"):
		var item: WorldItem = node as WorldItem
		if item == null or item == self or item.state != State.FREE or not item.is_loot():
			continue
		if item.linear_velocity.length() > 1.5 or not BED.has_point(to_local(item.global_position)):
			continue
		if can_load(item):
			item.host_cart(free_slot(item))
