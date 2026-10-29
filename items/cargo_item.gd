class_name CargoItem
extends WorldItem
## Something loot rides in: the Schubkarre and the rail cart (Hunt). Loot sits on slot nodes
## (`Slot1`, `Slot2`, ... children); a heavy item takes `heavy_units` of the capacity. Loot
## that comes to rest in the bed is loaded on its own (host).

const CATCH_SECONDS: float = 0.25

var cargo: Array[WorldItem] = []
var slots: Array[Node3D] = []

var _catch_left: float = 0.0


func _ready() -> void:
	super()
	# Moves before its cargo each frame, so the load never trails behind.
	process_priority = -1
	for child: Node in get_children():
		if child.name.begins_with("Slot"):
			slots.append(child as Node3D)


## How many units it holds, and what a heavy item counts as. Override.
func capacity() -> int:
	return 3


func heavy_units() -> int:
	return 3


## Where loot counts as lying in the bed, in the item's own space. Override.
func bed() -> AABB:
	return AABB()


func units(item: WorldItem) -> int:
	return heavy_units() if item.data.weight_class == ItemData.WeightClass.HEAVY else 1


func used_units() -> int:
	var total: int = 0
	for item: WorldItem in cargo:
		total += units(item)
	return total


func can_load(item: WorldItem) -> bool:
	return used_units() + units(item) <= capacity()


## The first free slot to put `item` on.
func free_slot(_item: WorldItem) -> Node3D:
	for slot: Node3D in slots:
		var taken: bool = false
		for loaded: WorldItem in cargo:
			if loaded.follow == slot:
				taken = true
		if not taken:
			return slot
	return null


## Loads the loot the player is holding; false when there is nothing to load.
func try_load_from(player: Player) -> bool:
	var carried: WorldItem = player.inventory.hands as WorldItem
	if carried == null or carried == self or not carried.is_loot():
		return false
	Game.instance.request_load_cart.rpc_id(1, get_path(), carried.get_path())
	return true


## What looking at it says when you hold loot in your hands or pocket ("" = nothing to load).
func load_prompt(player: Player) -> String:
	var carried: WorldItem = player.inventory.hands as WorldItem
	if carried != null and carried.is_loot():
		return load_text() if can_load(carried) else full_text()
	return ""


func load_text() -> String:
	return tr("PROMPT_LOAD_CART")


func full_text() -> String:
	return tr("PROMPT_CART_FULL")


func _physics_process(delta: float) -> void:
	super(delta)
	if multiplayer.is_server() and (state == State.FREE or state == State.HELD):
		_catch_left -= delta
		if _catch_left <= 0.0:
			_catch_left = CATCH_SECONDS
			_catch_loot()


## Host: loot lying still in the bed (dropped or thrown in) gets loaded properly.
func _catch_loot() -> void:
	var box: AABB = bed()
	for node: Node in get_tree().get_nodes_in_group(&"items"):
		var item: WorldItem = node as WorldItem
		if item == null or item == self or item.state != State.FREE or not item.is_loot():
			continue
		if item.linear_velocity.length() > 1.5 or not box.has_point(to_local(item.global_position)):
			continue
		if can_load(item):
			item.host_cart(free_slot(item))
