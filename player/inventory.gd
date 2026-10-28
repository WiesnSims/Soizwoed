class_name Inventory
extends RefCounted
## What a player carries: `slot_count` small slots for light items and tools, plus both hands
## for one medium or heavy item (or the Schubkarre). Pure logic; holds whatever objects the
## game gives it, together with their weight class.

signal changed

const NONE: int = -1
const HANDS: int = -2

var slots: Array = []
var slot_weights: PackedInt32Array = []
var hands: Object = null
var hands_weight: int = ItemData.WeightClass.LIGHT
var selected: int = 0


func _init(slot_count: int) -> void:
	slots.resize(slot_count)
	slot_weights.resize(slot_count)


## Where `item` would go: a slot index, HANDS, or NONE when it does not fit.
func place_for(weight: int) -> int:
	if weight == ItemData.WeightClass.LIGHT:
		var free: int = slots.find(null)
		if free != NONE:
			# Prefer the selected slot when it is free, so the item shows in the hand.
			return selected if slots[selected] == null else free
		return NONE
	return HANDS if hands == null else NONE


func add(item: Object, weight: int) -> int:
	var place: int = place_for(weight)
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


func hands_busy() -> bool:
	return hands != null


## Movement factor and whether sprinting is allowed, from what the hands carry.
func speed_factor(config: BalanceConfig) -> float:
	if hands == null:
		return 1.0
	if hands_weight == ItemData.WeightClass.HEAVY:
		return config.carry_heavy_speed
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
	for i: int in slots.size():
		slots[i] = null
	changed.emit()
