class_name VoiceLine
extends Resource
## One spoken creature line (audio only, never shown as text). See DESIGN.md §6 "Creature voices".

enum Moment { SPOT, IDLE, ACTION, HIT, DIE, FLEE, SHOUTED_AT }

@export var id: StringName = &""
@export var moment: Moment = Moment.IDLE
@export var stream: AudioStream
