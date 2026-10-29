class_name EnemyData
extends Resource
## One creature type. New creatures = a new .tres of this type plus its behaviour scene, and a
## CreatureSpawnRule in balance.tres (how often, how many, from which cycle).

@export var id: StringName = &""
## Translation key of the shown name.
@export var name_key: String = ""
@export var scene: PackedScene
## Spoken lines; empty for creatures that do not talk (Tatzelwurm).
@export var voice_lines: Array[VoiceLine] = []


func lines_for(moment: VoiceLine.Moment) -> Array[VoiceLine]:
	var result: Array[VoiceLine] = []
	for line: VoiceLine in voice_lines:
		if line.moment == moment:
			result.append(line)
	return result
