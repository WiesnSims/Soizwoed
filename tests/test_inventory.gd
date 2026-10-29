extends GutTest

const LIGHT: int = ItemData.WeightClass.LIGHT
const MEDIUM: int = ItemData.WeightClass.MEDIUM
const HEAVY: int = ItemData.WeightClass.HEAVY

var inventory: Inventory


func before_each() -> void:
	inventory = Inventory.new(4)


func _thing() -> RefCounted:
	return RefCounted.new()


func test_light_items_fill_slots_then_stop() -> void:
	for i: int in 4:
		assert_ne(inventory.add(_thing(), LIGHT), Inventory.NONE)
	assert_eq(inventory.add(_thing(), LIGHT), Inventory.NONE)


func test_light_item_goes_to_selected_slot_first() -> void:
	inventory.select(2)
	assert_eq(inventory.add(_thing(), LIGHT), 2)


func test_heavy_goes_to_hands_once() -> void:
	assert_eq(inventory.add(_thing(), HEAVY), Inventory.HANDS)
	assert_eq(inventory.add(_thing(), MEDIUM), Inventory.NONE)
	assert_true(inventory.hands_busy())


func test_heavy_slows_and_blocks_sprint() -> void:
	var config: BalanceConfig = BalanceConfig.new()
	inventory.add(_thing(), HEAVY)
	assert_lt(inventory.speed_factor(config), 1.0)
	assert_false(inventory.can_sprint())


func test_medium_allows_sprint() -> void:
	inventory.add(_thing(), MEDIUM)
	assert_true(inventory.can_sprint())


func test_active_item_prefers_hands() -> void:
	var small: RefCounted = _thing()
	var big: RefCounted = _thing()
	inventory.add(small, LIGHT)
	assert_eq(inventory.active_item(), small)
	inventory.add(big, HEAVY)
	assert_eq(inventory.active_item(), big)
	inventory.remove(big)
	assert_eq(inventory.active_item(), small)


func test_select_wraps() -> void:
	inventory.select(-1)
	assert_eq(inventory.selected, 3)
	inventory.select(4)
	assert_eq(inventory.selected, 0)


func test_all_items_and_clear() -> void:
	inventory.add(_thing(), LIGHT)
	inventory.add(_thing(), HEAVY)
	assert_eq(inventory.all_items().size(), 2)
	inventory.clear()
	assert_eq(inventory.all_items().size(), 0)
