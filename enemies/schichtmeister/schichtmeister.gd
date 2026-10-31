class_name Schichtmeister
extends Creature
## The ghost of a dead foreman (DESIGN.md §6). Game spawns him a little after the whistle when
## miners are still down (or when the Rückweg is nearly up); he runs down whoever is outside the
## Förderkorb, faster than anyone can sprint, and one touch puts you down. He never sets foot in
## the cage. He cannot be killed: bullets and picks only make him stagger. The Alphorn stuns him,
## a flare in his face blinds him for a while, and he won't walk into a "Bierzelt" cloud.
## Counter: be quick.

const TOUCH_DISTANCE: float = 1.1
const RETARGET_SECONDS: float = 0.4
const STEP_SECONDS: float = 0.28

var _target: Player
var _retarget_left: float = 0.0
var _seen: Dictionary = {}  # peer id -> true once he called them out
var _last_position: Vector3
var _step_left: float = 0.0

@onready var body: Node3D = $Body
@onready var steps: AudioStreamPlayer3D = $Steps


func _ready() -> void:
	super()
	health = 1
	_last_position = global_position
	_build_body()
	if multiplayer.is_server():
		say.call_deferred(VoiceLine.Moment.ACTION, true)


func _process(delta: float) -> void:
	super(delta)
	var moved: float = Vector2(global_position.x - _last_position.x, global_position.z - _last_position.z).length()
	_last_position = global_position
	if moved / maxf(delta, 0.0001) > 1.0:
		_step_left -= delta
		if _step_left <= 0.0:
			_step_left = STEP_SECONDS
			Audio.play_on(steps, "meister_steps", 0.05)
	# A slow sway, like a hanged lamp.
	body.rotation.z = sin(Time.get_ticks_msec() / 700.0) * 0.04


func _think(delta: float) -> void:
	_retarget_left -= delta
	if _retarget_left <= 0.0:
		_retarget_left = RETARGET_SECONDS
		_target = _pick_target()
	if _target == null:
		_halt(delta)
		if randf() < _config.voice_idle_chance * delta:
			say(VoiceLine.Moment.IDLE)
		return
	if not _seen.has(_target.peer_id) and can_see(_target.global_position + Vector3.UP * 1.5):
		_seen[_target.peer_id] = true
		say(VoiceLine.Moment.SPOT, true)
	var game: Game = Game.instance
	var ahead: Vector3 = global_position + (_target.global_position - global_position).normalized() * 0.8
	if game.in_mine_cage(ahead):
		_halt(delta)  # the cage is the one place he cannot go
		return
	walk_to(_target.global_position, _config.schichtmeister_speed, delta)
	if global_position.distance_to(_target.global_position) < TOUCH_DISTANCE and not game.in_mine_cage(_target.global_position):
		say(VoiceLine.Moment.DIE, true)
		game.host_damage_player(_target, _config.schichtmeister_damage)
		_target = null


## The nearest living miner outside the cage.
func _pick_target() -> Player:
	var best: Player = null
	var best_distance: float = INF
	for player: Player in Game.instance.players():
		if not player.alive or player.downed or player.global_position.y > Game.HUB_FLOOR_ABOVE or Game.instance.in_mine_cage(player.global_position):
			continue
		var distance: float = player.global_position.distance_to(global_position)
		if distance < best_distance:
			best = player
			best_distance = distance
	return best


## Bullets and picks: he only staggers.
func host_hit(_damage: int, _from: Vector3) -> void:
	say(VoiceLine.Moment.HIT)
	host_stun(_config.schichtmeister_hit_stagger)


## A flare in the face: blinded, he stands there for a while (DESIGN.md §6).
func host_flared(_damage: int, _from: Vector3) -> void:
	say(VoiceLine.Moment.HIT, true)
	host_stun(_config.flare_stun_seconds)
	print("[schichtmeister] blinded by a flare")


## Ghosts do not burn.
func host_ignite(_seconds: float, _dps: float) -> void:
	pass


func _build_body() -> void:
	var coat: StandardMaterial3D = BodyParts.ghost(Color(0.42, 0.5, 0.62, 0.55), 0.6)
	var face: StandardMaterial3D = BodyParts.ghost(Color(0.75, 0.82, 0.9, 0.7), 1.0)
	var brass: StandardMaterial3D = BodyParts.ghost(Color(0.8, 0.7, 0.4, 0.7), 1.2)
	BodyParts.add(body, BodyParts.capsule(0.32, 1.45), coat, Vector3(0, 0.95, 0))
	BodyParts.add(body, BodyParts.cylinder(0.33, 0.42, 0.5), coat, Vector3(0, 0.45, 0))  # coat skirt
	BodyParts.add(body, BodyParts.sphere(0.17), face, Vector3(0, 1.8, -0.02))
	# The tall miner's shako with its brass badge.
	BodyParts.add(body, BodyParts.cylinder(0.15, 0.17, 0.32), coat, Vector3(0, 2.05, 0))
	BodyParts.add(body, BodyParts.cylinder(0.2, 0.2, 0.03), coat, Vector3(0, 1.9, -0.03))
	BodyParts.add(body, BodyParts.sphere(0.035, 8), brass, Vector3(0, 2.06, -0.16))
	for side: float in [-1.0, 1.0]:
		BodyParts.add(body, BodyParts.capsule(0.07, 0.75), coat, Vector3(side * 0.38, 1.15, -0.12), Vector3(-35, 0, side * 8))
		BodyParts.add(body, BodyParts.sphere(0.025, 8), BodyParts.glow(Color(0.6, 0.85, 1.0), 6.0), Vector3(side * 0.06, 1.83, -0.15))
	# He carries his old lamp: a pale, cold light you see coming down the tunnel.
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.light_color = Color(0.55, 0.75, 1.0)
	lamp.light_energy = 1.4
	lamp.omni_range = 6.0
	lamp.omni_attenuation = 2.0
	lamp.position = Vector3(0.38, 0.8, -0.45)
	body.add_child(lamp)
	BodyParts.add(body, BodyParts.cylinder(0.05, 0.06, 0.16), brass, lamp.position)
	BodyParts.no_shadows(body)
