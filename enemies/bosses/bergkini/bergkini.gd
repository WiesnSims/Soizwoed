class_name Bergkini
extends Creature
## Da Bergkini (DESIGN.md §6 bosses): the king of the Bergmandl, guarding the Fundstück at the
## Fundort. He dozes on his hoard until a miner comes close, makes a noise nearby or hits him.
## Then he fights from cover – crates, rubble, his loot piles: he runs from one hiding place to
## the next, throws lit dynamite at whoever he can see, calls his Bergmandl now and then and
## slaps whoever gets too close. While he lives the Fundstück stays in its salt shell (Game).
## Counter: push in between throws, come at his cover from the side, mind the fuses – his
## dynamite hurts him and his Bergmandl too.

enum State { SLEEP, FIGHT }

const LOOK_SECONDS: float = 0.3
const STEP_SECONDS: float = 0.45
## He keeps to his hall: covers within this far of where he started.
const HOME_RADIUS: float = 12.0
## His head (weak spot), in the body's own scale, around a point just under the crown.
const HEAD_RADIUS: float = 0.17

var state: State = State.SLEEP

var _home: Vector3
var _covers: Array[Vector3] = []
var _cover: Vector3
var _target: Player
var _look_left: float = 0.0
var _throw_left: float = 2.0
var _summon_left: float = 6.0
var _slap_left: float = 0.0
var _cover_left: float = 0.0
var _hurt_since_cover: int = 0
## Local presentation.
var _last_position: Vector3
var _step_left: float = 0.0
var _bob: float = 0.0

@onready var body: Node3D = $Body
@onready var steps: AudioStreamPlayer3D = $Steps


func _ready() -> void:
	super()
	var run: RunState = GameState.run
	health = maxi(1, roundi(_config.bergkini_health * _config.boss_health_mult(run.shift_index if run != null else 0, run.player_count if run != null else 1)))
	_home = global_position
	_cover = global_position
	_last_position = global_position
	_build_crown()


func _process(delta: float) -> void:
	super(delta)
	# A heavy, rolling waddle and thudding steps.
	var speed: float = Vector2(global_position.x - _last_position.x, global_position.z - _last_position.z).length() / maxf(delta, 0.0001)
	_last_position = global_position
	if speed > 0.4:
		_bob += delta * speed * 2.6
		_step_left -= delta
		if _step_left <= 0.0:
			_step_left = STEP_SECONDS
			Audio.play_on(steps, "mandl_steps", 0.1)
			steps.pitch_scale = 0.7
	body.position.y = absf(sin(_bob)) * 0.08
	body.rotation.z = sin(_bob) * 0.08
	# The king speaks with the Bergmandl's words, an octave of age deeper.
	if voice.playing and voice.pitch_scale > 0.8:
		voice.pitch_scale = 0.7


func _think(delta: float) -> void:
	_look_left -= delta
	match state:
		State.SLEEP:
			if _look_left <= 0.0:
				_look_left = LOOK_SECONDS
				if not visible_players(_config.bergkini_wake_distance).is_empty():
					_wake()
			_halt(delta)
		State.FIGHT:
			_fight(delta)


func _fight(delta: float) -> void:
	_throw_left -= delta
	_summon_left -= delta
	_slap_left -= delta
	_cover_left -= delta
	if _look_left <= 0.0:
		_look_left = LOOK_SECONDS
		_target = _pick_target()
	if _cover_left <= 0.0 or _hurt_since_cover >= _config.bergkini_cover_after_damage:
		_pick_cover()
	var close: Player = _closest_player(_config.bergkini_slap_distance)
	if close != null:
		_face(close.global_position)
		_halt(delta)
		if _slap_left <= 0.0:
			_slap_left = _config.bergkini_slap_cooldown
			play_sound.rpc("watschn", 4.0)
			Game.instance.host_damage_player(close, scaled_damage(_config.bergkini_slap_damage))
			_cover_left = minf(_cover_left, 0.8)  # then off to another hiding place
		return
	if walk_to(_cover, _config.bergkini_speed, delta) and _target != null:
		_face(_target.global_position)
	if _summon_left <= 0.0:
		_summon()
	if _throw_left <= 0.0 and _target != null:
		var distance: float = _target.global_position.distance_to(global_position)
		if distance > 3.0 and distance < _config.bergkini_throw_range:
			_throw_at(_target)


func boss_fighting() -> bool:
	return state == State.FIGHT


## His head under the crown counts double (M10: every creature rewards aiming).
func weak_spot_mult(point: Vector3) -> float:
	var crown: Node3D = body.get_node_or_null(^"Crown") as Node3D
	if crown == null:
		return 1.0
	var size: float = body.global_basis.get_scale().x
	var head: Vector3 = crown.global_position - body.global_basis.y.normalized() * 0.12 * size
	return _config.bergkini_head_mult if point.distance_to(head) < HEAD_RADIUS * size else 1.0


func _wake() -> void:
	if state == State.FIGHT:
		return
	state = State.FIGHT
	_throw_left = 1.5
	_summon_left = 4.0
	if _covers.is_empty():
		for spot: Array in Game.instance.mine.markers_with_depth(&"boss_cover"):
			var at: Vector3 = (spot[0] as Marker3D).global_position
			if at.distance_to(_home) < HOME_RADIUS:
				_covers.append(at)
	_pick_cover()
	say(VoiceLine.Moment.SPOT, true)
	play_sound.rpc("voices/bergmandl/giggle", 6.0)
	Game.instance.host_noise(global_position, 25.0)  # the hall wakes with him
	Game.instance.message_everyone("MSG_BOSS_AWAKE")
	print("[bergkini] awake, %d covers, health %d" % [_covers.size(), health])


## Who to throw at: the Fundstück's carrier if he sees them, else the nearest miner in sight.
func _pick_target() -> Player:
	var best: Player = null
	for player: Player in visible_players(_config.bergkini_throw_range):
		if best == null or is_carrier(player) or (not is_carrier(best) and player.global_position.distance_to(global_position) < best.global_position.distance_to(global_position)):
			best = player
	return best


func _closest_player(reach: float) -> Player:
	var best: Player = null
	for player: Player in Game.instance.players():
		var distance: float = player.global_position.distance_to(global_position)
		if player.alive and player.global_position.y < Game.HUB_FLOOR_ABOVE and distance < reach \
				and (best == null or distance < best.global_position.distance_to(global_position)):
			best = player
	return best


## The next hiding place: one the miners cannot see into, far from them, not where he is now.
func _pick_cover() -> void:
	_cover_left = randf_range(_config.bergkini_cover_seconds * 0.7, _config.bergkini_cover_seconds * 1.3)
	_hurt_since_cover = 0
	if _covers.is_empty():
		return
	var best: Vector3 = _cover
	var best_score: float = -INF
	for at: Vector3 in _covers:
		if at.distance_to(_cover) < 1.0:
			continue
		var score: float = minf(10.0, _distance_to_players(at)) - at.distance_to(global_position) * 0.2 + randf() * 2.0
		for player: Player in Game.instance.players():
			if player.alive and Game.instance.clear_line(player.global_position + Vector3.UP * 1.5, at + Vector3.UP * 0.8):
				score -= 6.0  # in plain sight
		if score > best_score:
			best_score = score
			best = at
	_cover = best


## A lit stick at a miner: lobbed a little ahead of where they are going (host decides the blast).
func _throw_at(player: Player) -> void:
	_throw_left = randf_range(_config.bergkini_throw_seconds * 0.75, _config.bergkini_throw_seconds * 1.25)
	var from: Vector3 = global_position + Vector3.UP * 1.6
	var target: Vector3 = player.global_position + player.velocity * 0.6 + Vector3(randf_range(-0.8, 0.8), 0.0, randf_range(-0.8, 0.8))
	_face(target)
	Game.instance.host_throw_dynamite(from, target, scaled_damage(_config.dynamite_damage), get_path())
	print("[bergkini] dynamite at P%d" % player.peer_id)
	if randf() < 0.4:
		say(VoiceLine.Moment.ACTION)


## His Bergmandl come out of the rock nearby (out of the miners' sight where possible).
func _summon() -> void:
	_summon_left = _config.bergkini_summon_seconds
	var game: Game = Game.instance
	var room: int = _config.bergkini_summon_max - game.alive_count(&"bergmandl")
	if room <= 0:
		return
	var spots: Array[Vector3] = []
	for spot: Array in game.mine.markers_with_depth(&"enemy_spawn"):
		var at: Vector3 = (spot[0] as Marker3D).global_position
		if at.distance_to(_home) < HOME_RADIUS + 10.0 and _distance_to_players(at) > 4.0:
			spots.append(at)
	if spots.is_empty():
		spots.append(_home)
	for i: int in mini(room, _config.bergkini_summon_count):
		var at: Vector3 = spots.pick_random() + Vector3(randf_range(-0.6, 0.6), 0.3, randf_range(-0.6, 0.6))
		game.spawn_creature(&"bergmandl", Transform3D(Basis(Vector3.UP, randf() * TAU), at))
	play_sound.rpc("voices/bergmandl/giggle", 8.0)
	print("[bergkini] calls his Bergmandl")


func _face(point: Vector3) -> void:
	var flat: Vector3 = Vector3(point.x, global_position.y, point.z)
	if flat.distance_to(global_position) > 0.1:
		look_at(flat, Vector3.UP)


func host_heard(where: Vector3, reach: float) -> void:
	if state == State.SLEEP and where.distance_to(global_position) < minf(reach, 25.0):
		_wake()


## Shouting does not impress a king.
func host_shouted_at(_from: Vector3) -> void:
	_wake()


func host_hit(damage: int, from: Vector3) -> void:
	_wake()
	if host_damage(damage, from, "poof"):
		return
	_hurt_since_cover += damage
	say(VoiceLine.Moment.HIT)


func _build_crown() -> void:
	var hat: Node3D = body.get_node_or_null(^"Hat") as Node3D
	if hat != null:
		hat.hide()
	var gold: StandardMaterial3D = BodyParts.rough(Color(0.92, 0.7, 0.28), 0.3, 0.2)
	gold.metallic = 1.0
	var crown: Node3D = Node3D.new()
	crown.name = "Crown"
	crown.position = Vector3(0.0, 0.86, 0.0)
	body.add_child(crown)
	BodyParts.add(crown, BodyParts.cylinder(0.12, 0.115, 0.07, 16), gold, Vector3.ZERO)
	for i: int in 6:
		var a: float = TAU * i / 6.0
		BodyParts.add(crown, BodyParts.cylinder(0.0, 0.03, 0.08, 6), gold, Vector3(cos(a) * 0.11, 0.07, sin(a) * 0.11))
	BodyParts.add(crown, BodyParts.sphere(0.022, 8), BodyParts.glow(Color(0.9, 0.1, 0.15), 2.0), Vector3(0.0, 0.0, -0.12))
	BodyParts.no_shadows(crown)
