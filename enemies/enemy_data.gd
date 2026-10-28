class_name EnemyData
extends Resource
## One creature type. New creatures = a new .tres of this type plus its behaviour scene.

@export var id: StringName = &""
## Translation key of the shown name.
@export var name_key: String = ""
@export var scene: PackedScene
## Cost against the shift's enemy budget.
@export var budget_cost: float = 1.0
@export var max_health: int = 50
@export var move_speed: float = 3.0
## Spoken lines; empty for creatures that do not talk (Tatzelwurm).
@export var voice_lines: Array[VoiceLine] = []


func lines_for(moment: VoiceLine.Moment) -> Array[VoiceLine]:
	var result: Array[VoiceLine] = []
	for line: VoiceLine in voice_lines:
		if line.moment == moment:
			result.append(line)
	return result
