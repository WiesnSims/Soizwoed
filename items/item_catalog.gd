class_name ItemCatalog
extends Resource
## Every item of the game. The loot spawner and the shop read from here.

@export var items: Array[Resource] = []


func by_id(id: StringName) -> ItemData:
	for item: Resource in items:
		var data: ItemData = item as ItemData
		if data.id == id:
			return data
	return null


func loot() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item: Resource in items:
		var data: ItemData = item as ItemData
		if data.kind == ItemData.Kind.LOOT and data.spawn_weight > 0.0:
			result.append(data)
	return result


func shop() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item: Resource in items:
		var data: ItemData = item as ItemData
		if data.price > 0:
			result.append(data)
	return result
