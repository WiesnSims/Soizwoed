extends GutTest


func _line(id: StringName, moment: VoiceLine.Moment) -> VoiceLine:
	var line: VoiceLine = VoiceLine.new()
	line.id = id
	line.moment = moment
	return line


func test_lines_for_moment() -> void:
	var data: EnemyData = EnemyData.new()
	data.voice_lines = [_line(&"a", VoiceLine.Moment.SPOT), _line(&"b", VoiceLine.Moment.HIT), _line(&"c", VoiceLine.Moment.SPOT)]
	var spot: Array[VoiceLine] = data.lines_for(VoiceLine.Moment.SPOT)
	assert_eq(spot.size(), 2)
	assert_eq(spot[0].id, &"a")
	assert_eq(spot[1].id, &"c")


func test_silent_creature_has_no_lines() -> void:
	assert_eq(EnemyData.new().lines_for(VoiceLine.Moment.IDLE).size(), 0)
