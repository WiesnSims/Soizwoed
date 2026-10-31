class_name Throwable
extends WorldItem
## Something you light and throw (DESIGN.md §7): the Böller (a bang that draws creatures and
## scares Bergmandl), the Rauchbombe "Bierzelt" (a stinking cloud creatures keep out of) and
## Dynamit (a big blast that often brings the roof down).
## The host lights it when thrown, every peer hears the fuse, the host sets it off.

enum Effect { BANG, SMOKE, DYNAMIT }

@export var effect: Effect = Effect.BANG

var lit: bool = false

var _fuse: AudioStreamPlayer3D
var _spark: OmniLight3D


func _ready() -> void:
	super()
	_fuse = AudioStreamPlayer3D.new()
	_fuse.bus = &"SFX"
	_fuse.max_distance = 20.0
	_fuse.stream = Audio.stream("boeller_fuse")
	add_child(_fuse)
	_spark = OmniLight3D.new()
	_spark.light_color = Color(1.0, 0.7, 0.35)
	_spark.light_energy = 0.8
	_spark.omni_range = 2.5
	_spark.position = Vector3.UP * 0.12
	_spark.visible = false
	add_child(_spark)


func interaction_text(player: Player) -> String:
	return "" if lit else super(player)


func fuse_seconds() -> float:
	match effect:
		Effect.BANG:
			return Balance.config.boeller_fuse_seconds
		Effect.DYNAMIT:
			return Balance.config.dynamit_fuse_seconds
	return Balance.config.rauchbombe_fuse_seconds


## Host: thrown from `at` with `velocity`; goes off when the fuse has burnt down.
func host_throw(at: Transform3D, velocity: Vector3) -> void:
	host_release(at, velocity)
	_light.rpc()
	await get_tree().create_timer(fuse_seconds()).timeout
	if not is_inside_tree() or state != State.FREE:
		return
	match effect:
		Effect.BANG:
			Game.instance.host_bang(global_position)
		Effect.DYNAMIT:
			Game.instance.host_dynamit(global_position)
		_:
			Game.instance.host_smoke(global_position)
	host_vanish()


@rpc("authority", "call_local", "reliable")
func _light() -> void:
	lit = true
	_spark.visible = true
	if _fuse.stream != null:
		_fuse.play()
