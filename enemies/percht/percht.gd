class_name Percht
extends Creature
## A Schiachpercht from the deep (DESIGN.md §6, Die Tiefe only): big, slow, all shaggy fur and
## a carved mask with horns, and near-unkillable. It patrols the tunnels, and the cowbells on
## its belt announce it from far away.
##
## Its rule: it sees a lit lamp from far off, a miner in the dark only close up, and a crouching
## miner in the dark hardly at all. Once it sees you it comes faster than you walk – but not as
## fast as you sprint (and sprinting is loud). Out of sight for a few seconds, it searches where
## it last saw you, then goes back to its rounds. Noises draw it: a Böller or a bell sends it
## the wrong way. Counter: avoid it, hide (lamp off, duck), distract it with noise.

enum State { PATROL, INVESTIGATE, HUNT, SEARCH }

const SIGHT_CHECK_SECONDS: float = 0.25
const STRIKE_DISTANCE: float = 1.9
## It sees what is in front of it (half-angle, degrees), or anything right next to it.
const SIGHT_HALF_ANGLE: float = 70.0
const CLOSE_SENSE: float = 2.5
const STEP_SECONDS_WALK: float = 0.75
const STEP_SECONDS_RUN: float = 0.45

## Synced: hunting someone right now (louder, faster bells on every peer).
var net_hunting: bool = false

var state: State = State.PATROL
var _target: Player
var _goal: Vector3 = Vector3.INF
var _last_seen: Vector3 = Vector3.INF
var _unseen_time: float = 0.0
var _search_left: float = 0.0
var _strike_left: float = 0.0
var _sight_left: float = 0.0
var _last_position: Vector3
var _step_left: float = 0.0
var _sway: float = 0.0

@onready var body: Node3D = $Body
@onready var bells: AudioStreamPlayer3D = $Bells
@onready var steps: AudioStreamPlayer3D = $Steps


func _ready() -> void:
	super()
	health = _config.percht_health
	_last_position = global_position
	_build_body()
	var jingle: AudioStreamOggVorbis = Audio.stream("percht_bells") as AudioStreamOggVorbis
	if jingle != null:
		jingle.loop = true
	bells.stream = jingle
	bells.play()


func _process(delta: float) -> void:
	super(delta)
	var moved: float = Vector2(global_position.x - _last_position.x, global_position.z - _last_position.z).length() / maxf(delta, 0.0001)
	_last_position = global_position
	var walking: bool = moved > 0.4
	# The bells jingle with every step: louder and quicker on the hunt, almost still when it stops.
	bells.volume_db = lerpf(bells.volume_db, (4.0 if net_hunting else -2.0) if walking else -14.0, clampf(delta * 3.0, 0.0, 1.0))
	bells.pitch_scale = 1.15 if net_hunting else 1.0
	if walking:
		_step_left -= delta
		if _step_left <= 0.0:
			_step_left = STEP_SECONDS_RUN if net_hunting else STEP_SECONDS_WALK
			Audio.play_on(steps, "percht_steps", 0.06)
	_sway += delta * (moved * 1.6 + 0.6)
	body.rotation.z = sin(_sway) * 0.05
	body.position.y = absf(sin(_sway)) * 0.04


func _think(delta: float) -> void:
	_strike_left -= delta
	_sight_left -= delta
	if _sight_left <= 0.0:
		_sight_left = SIGHT_CHECK_SECONDS
		var seen: Player = _spot()
		if seen != null:
			if state != State.HUNT:
				say(VoiceLine.Moment.SPOT, true)
				print("[percht] hunting P%d" % seen.peer_id)
			_target = seen
			_last_seen = seen.global_position
			_unseen_time = 0.0
			_set_state(State.HUNT)
		elif state == State.HUNT:
			_unseen_time += SIGHT_CHECK_SECONDS
	match state:
		State.PATROL:
			if _goal == Vector3.INF or walk_to(_goal, _config.percht_patrol_speed, delta):
				_goal = far_point(10.0) if randf() < 0.5 else _random_waypoint()
			if randf() < _config.voice_idle_chance * delta:
				say(VoiceLine.Moment.IDLE)
		State.INVESTIGATE:
			if walk_to(_goal, _config.percht_investigate_speed, delta):
				_search_left = _config.percht_search_seconds * 0.5
				_set_state(State.SEARCH)
		State.HUNT:
			_hunt(delta)
		State.SEARCH:
			_search_left -= delta
			# Stands and turns, sniffing, then goes back on its rounds.
			_halt(delta)
			rotation.y += delta * 0.9
			if _search_left <= 0.0:
				_goal = Vector3.INF
				_set_state(State.PATROL)


func _hunt(delta: float) -> void:
	if _target == null or not is_instance_valid(_target) or not _target.alive or _target.global_position.y > Game.HUB_FLOOR_ABOVE:
		_target = null
		_set_state(State.SEARCH)
		_search_left = _config.percht_search_seconds
		return
	if _unseen_time >= _config.percht_lose_seconds:
		say(VoiceLine.Moment.FLEE)
		print("[percht] lost P%d" % _target.peer_id)
		_target = null
		_goal = _last_seen
		_search_left = _config.percht_search_seconds
		_set_state(State.INVESTIGATE)
		return
	var game: Game = Game.instance
	var chase_to: Vector3 = _target.global_position if _unseen_time <= 0.0 else _last_seen
	var ahead: Vector3 = global_position + (chase_to - global_position).normalized() * 1.2
	if game.in_mine_cage(ahead) or game.in_mine_cage(chase_to):
		_halt(delta)  # the Förderkorb is too small and too holy for it
		return
	walk_to(chase_to, _config.percht_chase_speed, delta)
	if _strike_left <= 0.0 and global_position.distance_to(_target.global_position) < STRIKE_DISTANCE and not game.in_mine_cage(_target.global_position):
		_strike_left = _config.percht_strike_cooldown
		say(VoiceLine.Moment.ACTION, true)
		play_sound.rpc("percht_roar", 4.0)
		game.host_damage_player(_target, _config.percht_damage)
		print("[percht] struck P%d" % _target.peer_id)


## The miner it can see right now, if any (nearest first).
func _spot() -> Player:
	var best: Player = null
	var best_distance: float = INF
	var eyes: Vector3 = global_position + Vector3.UP * 2.2
	var forward: Vector3 = -global_basis.z
	for player: Player in Game.instance.players():
		if not player.alive or player.global_position.y > Game.HUB_FLOOR_ABOVE or Game.instance.in_mine_cage(player.global_position):
			continue
		var chest: Vector3 = player.global_position + Vector3.UP * (0.8 if player.crouching else 1.3)
		var distance: float = eyes.distance_to(chest)
		if distance > sight_distance(player.light_range() > 0.0, player.crouching) or distance >= best_distance:
			continue
		var flat: Vector3 = chest - eyes
		flat.y = 0.0
		if distance > CLOSE_SENSE and flat.normalized().dot(forward) < cos(deg_to_rad(SIGHT_HALF_ANGLE)) and state != State.HUNT:
			continue
		if not _clear(eyes, chest):
			continue
		best = player
		best_distance = distance
	return best


## How far it sees a miner: a burning lamp from far away, in the dark only close up, and
## crouching in the dark hardly at all.
func sight_distance(lamp_lit: bool, crouching: bool) -> float:
	var reach: float = _config.percht_sight_lit if lamp_lit else _config.percht_sight_dark
	return reach * (_config.percht_crouch_factor if crouching else 1.0)


func _clear(from: Vector3, to: Vector3) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _random_waypoint() -> Vector3:
	var nav: AStar3D = Game.instance.mine.nav
	var ids: PackedInt64Array = nav.get_point_ids()
	return nav.get_point_position(ids[randi() % ids.size()])


func _set_state(new_state: State) -> void:
	state = new_state
	net_hunting = new_state == State.HUNT


## A noise: it goes to have a look – unless it is already after someone it can see.
func host_heard(where: Vector3, _reach: float) -> void:
	if state == State.HUNT and _unseen_time <= 0.0:
		return
	if in_smoke(where) or Game.instance.in_mine_cage(where):
		return
	_goal = where
	_target = null
	_set_state(State.INVESTIGATE)


func host_shouted_at(from: Vector3) -> void:
	host_heard(from, 0.0)


## Picks and blasts only make it angry; enough of them and it goes back into the dark.
func host_hit(damage: int, from: Vector3) -> void:
	health -= damage
	say(VoiceLine.Moment.HIT, true)
	if health <= 0:
		host_vanish(VoiceLine.Moment.FLEE, "percht_roar")
		print("[percht] driven off")
		return
	if state != State.HUNT:
		host_heard(from, 0.0)


func _build_body() -> void:
	var fur: StandardMaterial3D = BodyParts.rough(Color(0.2, 0.14, 0.09), 1.0, 1.0, 0.35)
	var fur_dark: StandardMaterial3D = BodyParts.rough(Color(0.1, 0.07, 0.05), 1.0, 1.0, 0.4)
	var wood: StandardMaterial3D = BodyParts.rough(Color(0.45, 0.12, 0.08), 0.6, 0.6, 0.1)
	var horn: StandardMaterial3D = BodyParts.rough(Color(0.82, 0.76, 0.62), 0.5, 0.4)
	var brass: StandardMaterial3D = StandardMaterial3D.new()
	brass.albedo_color = Color(0.7, 0.55, 0.25)
	brass.metallic = 0.9
	brass.roughness = 0.35
	# A great shaggy hulk, wider at the bottom: layers of sheepskin.
	BodyParts.add(body, BodyParts.cylinder(0.45, 0.75, 1.3), fur, Vector3(0, 0.65, 0))
	BodyParts.add(body, BodyParts.cylinder(0.6, 0.48, 0.9), fur_dark, Vector3(0, 1.6, 0))
	BodyParts.add(body, BodyParts.sphere(0.55, 16), fur, Vector3(0, 2.0, 0.05), Vector3.ZERO, Vector3(1.1, 0.7, 1.0))
	for side: float in [-1.0, 1.0]:
		BodyParts.add(body, BodyParts.capsule(0.17, 1.3), fur_dark, Vector3(side * 0.7, 1.35, -0.1), Vector3(-15, 0, side * 12))  # arms
		BodyParts.add(body, BodyParts.sphere(0.16, 10), wood, Vector3(side * 0.78, 0.72, -0.28))  # claws in gloves
	# The carved mask: red face, black brows, white teeth, a long red tongue.
	var mask: Node3D = Node3D.new()
	mask.position = Vector3(0, 2.25, -0.45)
	body.add_child(mask)
	BodyParts.add(mask, BodyParts.box(Vector3(0.5, 0.62, 0.18)), wood, Vector3.ZERO)
	BodyParts.add(mask, BodyParts.box(Vector3(0.18, 0.2, 0.18)), wood, Vector3(0, -0.02, -0.14))  # nose
	BodyParts.add(mask, BodyParts.box(Vector3(0.36, 0.06, 0.04)), BodyParts.rough(Color(0.05, 0.04, 0.03), 0.9, 0.0), Vector3(0, 0.15, -0.1))
	BodyParts.add(mask, BodyParts.box(Vector3(0.34, 0.06, 0.05)), horn, Vector3(0, -0.2, -0.09))
	BodyParts.add(mask, BodyParts.box(Vector3(0.09, 0.3, 0.03)), wood, Vector3(0, -0.4, -0.1), Vector3(-20, 0, 0))
	for side: float in [-1.0, 1.0]:
		BodyParts.add(mask, BodyParts.sphere(0.035, 8), BodyParts.glow(Color(1.0, 0.55, 0.2), 3.0), Vector3(side * 0.12, 0.07, -0.1))
		# Two pairs of horns, the big ones curling out and up.
		BodyParts.add(mask, BodyParts.cylinder(0.01, 0.07, 0.65, 8), horn, Vector3(side * 0.3, 0.45, 0.1), Vector3(-10, 0, side * -35))
		BodyParts.add(mask, BodyParts.cylinder(0.01, 0.05, 0.35, 8), horn, Vector3(side * 0.16, 0.42, 0.05), Vector3(-25, 0, side * -12))
	# The belt of cowbells.
	BodyParts.add(body, BodyParts.cylinder(0.62, 0.62, 0.1, 20), BodyParts.rough(Color(0.18, 0.1, 0.05), 0.7, 0.3), Vector3(0, 1.05, 0))
	for i: int in 7:
		var a: float = TAU * i / 7.0
		BodyParts.add(body, BodyParts.cylinder(0.07, 0.11, 0.2, 10), brass, Vector3(sin(a) * 0.66, 0.92, cos(a) * 0.66))
	BodyParts.no_shadows(body)
