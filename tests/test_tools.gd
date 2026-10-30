extends GutTest
## Tool rules that need no running game.


func test_alphorn_cone_hits_what_is_in_front() -> void:
	assert_true(Game.in_cone(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, -10), 20.0, 70.0))
	assert_true(Game.in_cone(Vector3.ZERO, Vector3.FORWARD, Vector3(3, 0, -10), 20.0, 70.0))


func test_alphorn_cone_misses_behind_beside_and_far() -> void:
	assert_false(Game.in_cone(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, 10), 20.0, 70.0))
	assert_false(Game.in_cone(Vector3.ZERO, Vector3.FORWARD, Vector3(10, 0, -2), 20.0, 70.0))
	assert_false(Game.in_cone(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, -25), 20.0, 70.0))


func test_rail_line_measures_and_projects() -> void:
	var line: RailLine = RailLine.new()
	add_child_autofree(line)
	line.build(PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -10), Vector3(10, 0, -10)]), 1)
	# 20 m of corners, a little more or less where the track follows the walls' wander.
	assert_gt(line.length(), 17.0)
	assert_lt(line.length(), 24.0)
	var middle: float = line.closest_s(line.transform_at(line.length() / 2.0).origin + Vector3.UP * 0.5)
	assert_almost_eq(middle, line.length() / 2.0, 0.3)
	assert_eq(line.closest_s(Vector3(0, 0, 50)), 0.0)


func test_every_shop_tool_has_a_use_or_a_weapon() -> void:
	var catalog: ItemCatalog = load("res://items/item_catalog.tres")
	for data: ItemData in catalog.shop():
		if data.id == &"schubkarre" or data.kind == ItemData.Kind.AMMO:
			continue
		assert_true(data.use != ItemData.Use.NONE or data.melee_damage > 0, "%s does nothing when used" % data.id)