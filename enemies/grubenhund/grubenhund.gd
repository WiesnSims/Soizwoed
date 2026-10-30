class_name Grubenhund
extends Creature
## The everyday enemy (DESIGN.md §6, new in v2): the mine's dogs, dead and not lying down
## about it. Packs of 2–3, fast, mangy, glowing eyes. They see a lit lamp from far off and a
## miner in the dark only close up, and they come running at shots and noise.
##
## How they fight: rush in, bite, spring back and circle, then come again – hit and run, so a
## standing miner gets a moment to shoot. When one finds a miner, the whole pack comes. A badly
## hurt dog runs off yelping for a few seconds, then comes back.

enum State { ROAM, HUNT, BACK_OFF, INVESTIGATE, FLEE }

const SIGHT_CHECK_SECONDS: float = 0.3
const STEP_SECONDS: float = 0.18

var state: State = State.ROAM
var _target: Player
var _goal: Vector3 = Vector3.INF
var _last_seen: Vector3 = Vector3.INF
var _unseen_time: float = 0.0
var _bite_left: float = 0.0
var _state_time: float = 0.0
var _sight_left: float = 0.0
var _growl_left: float = 2.0
var _fled: bool = false
## Local presentation.
var _last_position: Vector3
var _step_left: float = 0.0
var _gait: float = 0.0
var _legs: Array[Node3D] = []

@onready var body: Node3D = $Body
@onready var steps: AudioStreamPlayer3D = $Steps


func _ready() -> void:
	super()
	health = scaled_health(_config.grubenhund_health)
	_last_position = global_position
	_build_body()


func _process(delta: float) -> void:
	super(delta)
	var speed: float = Vector2(global_position.x - _last_position.x, global_position.z - _last_position.z).length() / maxf(delta, 0.0001)
	_last_position = global_position
	if speed > 0.4:
		_gait += delta * speed * 3.2
		_step_left -= delta * clampf(speed / 3.0, 0.6, 2.0)
		if _step_left <= 0.0:
			_step_left = STEP_SECONDS
			Audio.play_on(steps, "dog_steps", 0.12)
	for i: int in _legs.size():
		_legs[i].rotation.x = sin(_gait + (PI if i % 2 == 0 else 0.0) + (PI / 2.0 if i >= 2 else 0.0)) * minf(0.7, speed * 0.15)
	body.position.y = absf(sin(_gait)) * minf(0.05, speed * 0.01)


func _think(delta: float) -> void:
	_state_time += delta
	_bite_left -= delta
	_sight_left -= delta
	if _sight_left <= 0.0:
		_sight_left = SIGHT_CHECK_SECONDS
		_look()
	match state:
		State.ROAM:
			if _goal == Vector3.INF or walk_to(_goal, _config.grubenhund_roam_speed, delta) or _state_time > 12.0:
				_goal = _roam_point()
				_state_time = 0.0
		State.INVESTIGATE:
			if walk_to(_goal, _config.grubenhund_roam_speed * 1.8, delta) or _state_time > 15.0:
				_set_state(State.ROAM)
		State.HUNT:
			_hunt(delta)
		State.BACK_OFF:
			walk_to(_goal, _config.grubenhund_speed, delta)
			if _state_time > _config.grubenhund_backoff_seconds:
				_set_state(State.HUNT)
		State.FLEE:
			walk_to(_goal, _config.grubenhund_speed, delta)
			if _state_time > _config.grubenhund_flee_seconds:
				_set_state(State.HUNT if _target != null else State.ROAM)


func _hunt(delta: float) -> void:
	if _target == null or not is_instance_valid(_target) or not _target.alive or _target.global_position.y > Game.HUB_FLOOR_ABOVE:
		_target = null
		_set_state(State.ROAM)
		return
	if _unseen_time > _config.grubenhund_lose_seconds:
		_goal = _last_seen
		_target = null
		_set_state(State.INVESTIGATE)
		return
	_growl_left -= delta
	if _growl_left <= 0.0:
		_growl_left = randf_range(2.5, 5.0)
		play_sound.rpc("dog_growl" if randf() < 0.6 else "dog_bark", -2.0)
	var game: Game = Game.instance
	if game.in_mine_cage(_target.global_position) and game.in_mine_cage(global_position + (_target.global_position - global_position).normalized()):
		_halt(delta)  # not into the Förderkorb
		return
	walk_to(_target.global_position if _unseen_time <= 0.0 else _last_seen, _config.grubenhund_speed, delta)
	if _bite_left <= 0.0 and global_position.distance_to(_target.global_position) < _config.grubenhund_bite_distance:
		_bite_left = _config.grubenhund_bite_cooldown
		play_sound.rpc("dog_bite", 2.0)
		game.host_damage_player(_target, _config.grubenhund_bite_damage)
		# Spring back to the side, then come again.
		var away: Vector3 = (global_position - _target.global_position)
		away.y = 0.0
		var side: Vector3 = away.normalized().cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
		_goal = global_position + (away.normalized() * 2.5 + side * 2.0)
		_set_state(State.BACK_OFF)


## Who it can see now: the nearest standing miner (downed ones only if nobody else is there).
func _look() -> void:
	var best: Player = null
	var best_score: float = INF
	var eyes: Vector3 = global_position + Vector3.UP * 0.6
	for player: Player in Game.instance.players():
		if not player.alive or player.global_position.y > Game.HUB_FLOOR_ABOVE:
			continue
		var chest: Vector3 = player.global_position + Vector3.UP * (0.7 if player.crouching or player.downed else 1.2)
		var distance: float = eyes.distance_to(chest)
		if distance > sight_distance(player.light_range() > 0.0, player.crouching) or not _clear(eyes, chest):
			continue
		var score: float = distance + (30.0 if player.downed else 0.0)
		if score < best_score:
			best = player
			best_score = score
	if best != null:
		if state != State.HUNT and state != State.BACK_OFF and state != State.FLEE:
			play_sound.rpc("dog_bark", 2.0)
			_alert_pack(best)
		_target = best
		_last_seen = best.global_position
		_unseen_time = 0.0
		if state == State.ROAM or state == State.INVESTIGATE:
			_set_state(State.HUNT)
	elif state == State.HUNT:
		_unseen_time += SIGHT_CHECK_SECONDS


## How far it sees a miner: a lit lamp from far off, the dark only close up, crouching less.
func sight_distance(lamp_lit: bool, crouching: bool) -> float:
	var reach: float = _config.grubenhund_sight_lit if lamp_lit else _config.grubenhund_sight_dark
	return reach * (_config.grubenhund_crouch_factor if crouching else 1.0)


## One dog found someone: the rest of the pack comes too.
func _alert_pack(target: Player) -> void:
	for creature: Creature in Game.instance.creatures():
		var dog: Grubenhund = creature as Grubenhund
		if dog != null and dog != self and dog.global_position.distance_to(global_position) < _config.grubenhund_pack_radius and dog.state != State.HUNT:
			dog._target = target
			dog._last_seen = target.global_position
			dog._unseen_time = 0.0
			dog._set_state(State.HUNT)


func _roam_point() -> Vector3:
	# Stay near the pack.
	for creature: Creature in Game.instance.creatures():
		if creature is Grubenhund and creature != self:
			var gap: float = creature.global_position.distance_to(global_position)
			if gap > 5.0 and gap < 20.0:
				return creature.global_position + Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))
	var nav: AStar3D = Game.instance.mine.nav
	var here: int = nav.get_closest_point(global_position)
	var options: PackedInt64Array = nav.get_point_connections(here)
	return global_position if options.is_empty() else nav.get_point_position(options[randi() % options.size()])


func _clear(from: Vector3, to: Vector3) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	_repath_left = 0.0


func host_heard(where: Vector3, _reach: float) -> void:
	if state == State.ROAM or state == State.INVESTIGATE:
		if in_smoke(where) or Game.instance.in_mine_cage(where):
			return
		_goal = where
		_set_state(State.INVESTIGATE)


func host_hit(damage: int, from: Vector3) -> void:
	if host_damage(damage, from, "dog_die"):
		return
	play_sound.rpc("dog_yelp")
	if not _fled and health < scaled_health(_config.grubenhund_health) * 0.3:
		_fled = true
		_goal = away_point(from)
		_set_state(State.FLEE)
		return
	if state != State.HUNT and state != State.BACK_OFF:
		var shooter: Player = _nearest_player_to(from)
		if shooter != null:
			_target = shooter
			_last_seen = shooter.global_position
			_unseen_time = 0.0
			_alert_pack(shooter)
			_set_state(State.HUNT)


func _nearest_player_to(point: Vector3) -> Player:
	var best: Player = null
	for player: Player in Game.instance.players():
		if player.alive and (best == null or player.global_position.distance_to(point) < best.global_position.distance_to(point)):
			best = player
	return best


func _build_body() -> void:
	var fur: StandardMaterial3D = BodyParts.rough(Color(0.34, 0.29, 0.24), 1.0, 1.0, 0.3)
	var skin: StandardMaterial3D = BodyParts.rough(Color(0.36, 0.26, 0.22), 0.7, 0.8, 0.15)
	var bone: StandardMaterial3D = BodyParts.rough(Color(0.7, 0.65, 0.55), 0.8, 0.4)
	# A lean, hunched body with the ribs showing; the head held low.
	BodyParts.add(body, BodyParts.capsule(0.17, 0.85), fur, Vector3(0, 0.52, 0), Vector3(90, 0, 0))
	for i: int in 4:
		var rib: TorusMesh = TorusMesh.new()
		rib.inner_radius = 0.15
		rib.outer_radius = 0.17
		rib.rings = 10
		rib.ring_segments = 4
		BodyParts.add(body, rib, bone, Vector3(0, 0.52, -0.12 + i * 0.08), Vector3(0, 0, 0), Vector3(1.0, 1.0, 0.4))
	var head: Node3D = Node3D.new()
	head.position = Vector3(0, 0.55, -0.5)
	head.rotation_degrees = Vector3(-15, 0, 0)
	body.add_child(head)
	BodyParts.add(head, BodyParts.sphere(0.12, 12), fur, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.9, 1.1))
	BodyParts.add(head, BodyParts.box(Vector3(0.1, 0.08, 0.2)), skin, Vector3(0, -0.03, -0.14))
	BodyParts.add(head, BodyParts.box(Vector3(0.09, 0.015, 0.14)), bone, Vector3(0, -0.075, -0.15))  # teeth
	for side: float in [-1.0, 1.0]:
		BodyParts.add(head, BodyParts.cylinder(0.0, 0.04, 0.12, 6), fur, Vector3(side * 0.07, 0.11, 0.02), Vector3(-10, 0, side * -15))
		BodyParts.add(head, BodyParts.sphere(0.018, 8), BodyParts.glow(Color(0.9, 0.75, 0.3), 4.0), Vector3(side * 0.05, 0.02, -0.1))
	# Legs (pivot at the hip, so they swing).
	for leg: Vector3 in [Vector3(-0.1, 0.45, -0.3), Vector3(0.1, 0.45, -0.3), Vector3(-0.1, 0.45, 0.3), Vector3(0.1, 0.45, 0.3)]:
		var hip: Node3D = Node3D.new()
		hip.position = leg
		body.add_child(hip)
		BodyParts.add(hip, BodyParts.cylinder(0.025, 0.035, 0.45, 6), skin, Vector3(0, -0.22, 0))
		_legs.append(hip)
	BodyParts.add(body, BodyParts.cylinder(0.01, 0.03, 0.35, 6), fur, Vector3(0, 0.6, 0.55), Vector3(-60, 0, 0))  # tail
	BodyParts.no_shadows(body)
