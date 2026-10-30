class_name Inventory
extends RefCounted
## What a player carries (owner decision after the M6 playtest): slots by kind – keys 1–3 for
## weapons, 4 for something to throw, 5–9 for everything else – plus both hands for one medium
## or heavy item (or the Schubkarre). A second throwable goes into a free item slot. Pure logic;
## holds whatever objects the game gives it, with their weight class.

signal changed

const NONE: int = -1
const HANDS: int = -2

var slots: Array = []
var slot_weights: PackedInt32Array = []
## ItemData.SlotKind of each slot.
var slot_kinds: PackedInt32Array = []
var hands: Object = null
var hands_weight: int = ItemData.WeightClass.LIGHT
## True while the item in the hands is carried by two players together.
var shared_carry: bool = false
var selected: int = 0


func _init(kinds: PackedInt32Array) -> void:
	slot_kinds = kinds
	slots.resize(kinds.size())
	slot_weights.resize(kinds.size())


## The slot layout from balance.tres: weapons, throwables, then items.
static func layout(config: BalanceConfig) -> PackedInt32Array:
	var kinds: PackedInt32Array = []
	for i: int in config.weapon_slots:
		kinds.append(ItemData.SlotKind.WEAPON)
	for i: int in config.throwable_slots:
		kinds.append(ItemData.SlotKind.THROWABLE)
	for i: int in config.item_slots:
		kinds.append(ItemData.SlotKind.ITEM)
	return kinds


## Where an item would go: a slot index, HANDS, or NONE when it does not fit.
func place_for(weight: int, kind: int = ItemData.SlotKind.ITEM) -> int:
	if weight != ItemData.WeightClass.LIGHT:
		return HANDS if hands == null else NONE
	var place: int = free_slot(kind)
	if place == NONE and kind == ItemData.SlotKind.THROWABLE:
		place = free_slot(ItemData.SlotKind.ITEM)
	return place


## A free slot of `kind`: the selected one if it fits, else the first.
func free_slot(kind: int) -> int:
	if slots[selected] == null and slot_kinds[selected] == kind:
		return selected
	for i: int in slots.size():
		if slots[i] == null and slot_kinds[i] == kind:
			return i
	return NONE


func add(item: Object, weight: int, kind: int = ItemData.SlotKind.ITEM) -> int:
	var place: int = place_for(weight, kind)
	if place == HANDS:
		hands = item
		hands_weight = weight
	elif place != NONE:
		slots[place] = item
		slot_weights[place] = weight
	if place != NONE:
		changed.emit()
	return place


## Puts `item` exactly where the host decided (`place` from place_for on the host's copy).
func put(item: Object, weight: int, place: int) -> void:
	if place == HANDS:
		hands = item
		hands_weight = weight
	elif place >= 0 and place < slots.size():
		slots[place] = item
		slot_weights[place] = weight
	changed.emit()


func remove(item: Object) -> bool:
	if hands == item:
		hands = null
		shared_carry = false
		changed.emit()
		return true
	var index: int = slots.find(item)
	if index == NONE:
		return false
	slots[index] = null
	changed.emit()
	return true


## The item a drop or use acts on: the hands first, else the selected slot.
func active_item() -> Object:
	return hands if hands != null else slots[selected]


func select(index: int) -> void:
	selected = posmod(index, slots.size())
	changed.emit()


## The mouse wheel: the next slot with something in it (`step` 1 or -1), like in other
## shooters; stays put when everything else is empty.
func select_next(step: int) -> void:
	for i: int in range(1, slots.size() + 1):
		var index: int = posmod(selected + step * i, slots.size())
		if slots[index] != null:
			select(index)
			return


func hands_busy() -> bool:
	return hands != null


## Movement factor and whether sprinting is allowed, from what the hands carry.
func speed_factor(config: BalanceConfig) -> float:
	if hands == null:
		return 1.0
	if hands_weight == ItemData.WeightClass.HEAVY:
		return config.carry_together_speed if shared_carry else config.carry_heavy_speed
	return config.carry_medium_speed


func can_sprint() -> bool:
	return hands == null or hands_weight != ItemData.WeightClass.HEAVY


func all_items() -> Array:
	var result: Array = []
	if hands != null:
		result.append(hands)
	for item: Object in slots:
		if item != null:
			result.append(item)
	return result


func clear() -> void:
	hands = null
	shared_carry = false
	for i: int in slots.size():
		slots[i] = null
	changed.emit()
