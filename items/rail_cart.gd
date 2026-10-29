class_name RailCart
extends CargoItem
## A Hunt, the mine's rail cart (DESIGN.md §4, §7): rolls only along the RailLine, holds a lot
## (a heavy item counts as three), is loud. Press E to push it (it stays ahead of you on the
## track, G or walking off lets go) or blow the Grubenhund-Pfeiferl and it comes to you by
## itself. Host-moved, clients follow the host's transforms like any free item. It belongs to
## the mine: it never rides up and is gone after the shift.

const BED: AABB = AABB(Vector3(-0.45, 0.3, -0.7), Vector3(0.9, 0.9, 1.4))
## How far ahead of its pusher it runs, and when the pusher has lost it.
const PUSH_AHEAD: float = 1.4
const PUSH_LOSE: float = 3.2
## A called cart stops this far short of whoever whistled.
const CALL_SHORT: float = 1.6

## The pushing player (0: nobody). Same on every peer.
var pusher_peer: int = 0
## Host: where along the track it is, where it is heading and how fast.
var s: float = 0.0
var target_s: float = 0.0
var speed: float = 0.0
var moving: bool = false

var _last_position: Vector3

@onready var rattle: AudioStreamPlayer3D = $Rattle


func _ready() -> void:
	super()
	_last_position = global_position


func capacity() -> int:
	return Balance.config.rail_cart_capacity


func heavy_units() -> int:
	return 3


func bed() -> AABB:
	return BED


func load_text() -> String:
	return tr("PROMPT_LOAD_HUNT")


func full_text() -> String:
	return tr("PROMPT_HUNT_FULL")


func rails() -> RailLine:
	return Game.instance.mine.rails if Game.instance != null and Game.instance.mine != null else null


func interaction_text(player: Player) -> String:
	if state != State.FREE:
		return ""
	var loading: String = load_prompt(player)
	if loading != "":
		return loading
	if pusher_peer == player.peer_id:
		return tr("PROMPT_RAIL_LET_GO")
	return tr("PROMPT_RAIL_PUSH") if pusher_peer == 0 else ""


## Host: it stands on the track at distance `at` (spawned right there).
func host_place(at: float) -> void:
	s = at
	target_s = at


## Host: the Pfeiferl was blown at `where`: roll over to it on its own.
func host_call(where: Vector3) -> void:
	var line: RailLine = rails()
	if line == null:
		return
	host_set_pusher(0)
	var at: float = line.closest_s(where)
	target_s = at - signf(at - s) * CALL_SHORT
	speed = Balance.config.pfeiferl_cart_speed


func host_set_pusher(peer: int) -> void:
	if peer != pusher_peer:
		_apply_pusher.rpc(peer)


@rpc("authority", "call_local", "reliable")
func _apply_pusher(peer: int) -> void:
	pusher_peer = peer


func _physics_process(delta: float) -> void:
	super(delta)
	if multiplayer.is_server():
		_host_roll(delta)
	# Every peer: rattles while it rolls.
	var rolled: float = global_position.distance_to(_last_position) / maxf(delta, 0.0001)
	_last_position = global_position
	moving = rolled > 0.3
	if moving and not rattle.playing:
		rattle.play()
	elif not moving and rattle.playing:
		rattle.stop()


func _host_roll(delta: float) -> void:
	freeze = true  # moved along the track, never by physics
	var line: RailLine = rails()
	if line == null or state != State.FREE:
		return
	var pusher: Player = Game.instance.player_by_peer(pusher_peer) if pusher_peer != 0 else null
	if pusher_peer != 0 and (pusher == null or not pusher.alive or line.transform_at(s).origin.distance_to(pusher.global_position) > PUSH_LOSE):
		host_set_pusher(0)
		pusher = null
	if pusher != null:
		var at: float = line.closest_s(pusher.global_position)
		var ahead: float = signf(s - at) if absf(s - at) > 0.05 else 1.0
		target_s = at + ahead * PUSH_AHEAD
		speed = Balance.config.walk_speed * Balance.config.rail_cart_push_speed * 1.3
	target_s = clampf(target_s, 0.0, line.length())
	if is_equal_approx(s, target_s):
		sleeping = true
		return
	s = move_toward(s, target_s, speed * delta)
	global_transform = line.transform_at(s)
	sleeping = false
