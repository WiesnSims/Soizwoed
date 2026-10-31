class_name EnemyData
extends Resource
## One creature type. New creatures = a new .tres of this type plus its behaviour scene, and a
## CreatureSpawnRule in balance.tres (how often, how many, from which shift).

@export var id: StringName = &""
## Translation key of the shown name.
@export var name_key: String = ""
@export var scene: PackedScene
## Spoken lines; empty for creatures that do not talk (Tatzelwurm).
@export var voice_lines: Array[VoiceLine] = []
## Width of the blood pool where it dies (m; 0: it does not bleed – the Salzweibl is salt).
@export var blood_pool: float = 1.0
## Bosses: the music sting (assets/audio/music) when it starts to fight (DESIGN.md §10).
@export var sting: String = ""


func lines_for(moment: VoiceLine.Moment) -> Array[VoiceLine]:
	var result: Array[VoiceLine] = []
	for line: VoiceLine in voice_lines:
		if line.moment == moment:
			result.append(line)
	return result
