extends GutTest
## The pocket layout (owner decision): 1–3 weapons, 4 a throwable, 5–9 everything else, and the
## hands for one medium or heavy thing.

const LIGHT: int = ItemData.WeightClass.LIGHT
const MEDIUM: int = ItemData.WeightClass.MEDIUM
const HEAVY: int = ItemData.WeightClass.HEAVY
const WEAPON: int = ItemData.SlotKind.WEAPON
const THROWABLE: int = ItemData.SlotKind.THROWABLE
const ITEM: int = ItemData.SlotKind.ITEM

var inventory: Inventory


func before_each() -> void:
	var config: BalanceConfig = BalanceConfig.new()
	inventory = Inventory.new(Inventory.layout(config))
	inventory.set_open_slots(Inventory.base_slots(config))  # the extra pockets are locked


func _thing() -> RefCounted:
	return RefCounted.new()


func test_layout_is_three_one_five() -> void:
	# Plus the two extra pockets (keys 0 and ß), locked until earned.
	assert_eq(inventory.slot_kinds, PackedInt32Array([WEAPON, WEAPON, WEAPON, THROWABLE, ITEM, ITEM, ITEM, ITEM, ITEM, ITEM, ITEM]))
	assert_eq(inventory.open_slots, 9)


func test_weapons_fill_slots_1_to_3_then_stop() -> void:
	for i: int in 3:
		assert_eq(inventory.add(_thing(), LIGHT, WEAPON), i)
	assert_eq(inventory.add(_thing(), LIGHT, WEAPON), Inventory.NONE, "no gun in an item pocket")


func test_items_never_take_weapon_slots() -> void:
	for i: int in 5:
		assert_eq(inventory.add(_thing(), LIGHT, ITEM), 4 + i)
	assert_eq(inventory.add(_thing(), LIGHT, ITEM), Inventory.NONE)
	assert_eq(inventory.slots[0], null)


func test_second_throwable_goes_into_an_item_pocket() -> void:
	assert_eq(inventory.add(_thing(), LIGHT, THROWABLE), 3)
	assert_eq(inventory.add(_thing(), LIGHT, THROWABLE), 4)


func test_selected_slot_of_the_right_kind_comes_first() -> void:
	inventory.select(6)
	assert_eq(inventory.add(_thing(), LIGHT, ITEM), 6)
	assert_eq(inventory.add(_thing(), LIGHT, WEAPON), 0, "the selected slot is an item pocket")


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
	inventory.add(small, LIGHT, WEAPON)
	assert_eq(inventory.active_item(), small)
	inventory.add(big, HEAVY)
	assert_eq(inventory.active_item(), big)
	inventory.remove(big)
	assert_eq(inventory.active_item(), small)


func test_select_wraps() -> void:
	inventory.select(-1)
	assert_eq(inventory.selected, 8)
	inventory.select(2)
	inventory.select(9)
	assert_eq(inventory.selected, 2, "a locked extra pocket cannot be selected")
	inventory.set_open_slots(10)
	inventory.select(9)
	assert_eq(inventory.selected, 9, "once open it can")


func test_wheel_skips_empty_slots() -> void:
	inventory.add(_thing(), LIGHT, WEAPON)
	inventory.add(_thing(), LIGHT, ITEM)
	inventory.select(0)
	inventory.select_next(1)
	assert_eq(inventory.selected, 4)
	inventory.select_next(1)
	assert_eq(inventory.selected, 0, "around to the gun again")
	inventory.select_next(-1)
	assert_eq(inventory.selected, 4)


func test_all_items_and_clear() -> void:
	inventory.add(_thing(), LIGHT)
	inventory.add(_thing(), HEAVY)
	assert_eq(inventory.all_items().size(), 2)
	inventory.clear()
	assert_eq(inventory.all_items().size(), 0)


func test_heavy_carried_together_is_almost_normal_speed() -> void:
	var config: BalanceConfig = BalanceConfig.new()
	inventory.add(_thing(), HEAVY)
	assert_eq(inventory.speed_factor(config), config.carry_heavy_speed)
	inventory.shared_carry = true
	assert_eq(inventory.speed_factor(config), config.carry_together_speed)
	assert_false(inventory.can_sprint(), "no sprinting with a salt block, even together")


func test_letting_go_ends_carrying_together() -> void:
	var block: RefCounted = _thing()
	inventory.add(block, HEAVY)
	inventory.shared_carry = true
	inventory.remove(block)
	assert_false(inventory.shared_carry)


func test_item_kinds() -> void:
	var catalog: ItemCatalog = load("res://items/item_catalog.tres")
	assert_eq(catalog.by_id(&"dienstpistole").slot_kind(), ItemData.SlotKind.WEAPON)
	assert_eq(catalog.by_id(&"spitzhacke").slot_kind(), ItemData.SlotKind.WEAPON)
	assert_eq(catalog.by_id(&"boeller").slot_kind(), ItemData.SlotKind.THROWABLE)
	assert_eq(catalog.by_id(&"obstler").slot_kind(), ItemData.SlotKind.ITEM)
	assert_eq(catalog.by_id(&"salzkristall").slot_kind(), ItemData.SlotKind.ITEM)
