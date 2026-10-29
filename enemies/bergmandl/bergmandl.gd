class_name Bergmandl
extends Creature
## The mine gnome (DESIGN.md §6): small, quick, in groups. Steals loot from the floor, from
## Schubkarren and out of players' hands, then runs off giggling and drops it somewhere far
## away. Not deadly. Counter: shout at it ("Plärren") or hit it, and it drops what it has.
## Loot inside the Förderkorb is safe.

enum State { WANDER, FETCH, SNATCH, RUN_OFF, SCARED }

const LOOK_SECONDS: float = 0.3
const GRAB_DISTANCE: float = 0.9
const SNATCH_DISTANCE: float = 1.4
const SNATCH_COOLDOWN: float = 2.0
const STEP_SECONDS: float = 0.32

## Loot that Bergmandl dropped after running off: their stash, left alone until a player
## picks it up again (shared by all of them).
static var stash: Dictionary = {}  # WorldItem -> true

var state: State = State.WANDER
var carried: WorldItem

var _goal: Vector3
var _state_time: float = 0.0
var _look_left: float = 0.0
var _snatch_cooldown: float = 0.0
var _target_item: WorldItem
var _target_player: Player
var _spotted: Dictionary = {}  # peer id -> true while that player stays in sight
## Local presentation (every peer).
var _last_position: Vector3
var _step_left: float = 0.0
var _bob: float = 0.0

@onready var carry_point: Node3D = $CarryPoint
@onready var body: Node3D = $Body
@onready var steps: AudioStreamPlayer3D = $Steps


func _ready() -> void:
	super()
	health = _config.bergmandl_health
	_goal = global_position
	_last_position = global_position


func _process(delta: float) -> void:
	super(delta)
	# Footsteps and a waddle from how far it moved (works the same on clients).
	var moved: float = Vector2(global_position.x - _last_position.x, global_position.z - _last_position.z).length()
	_last_position = global_position
	var speed: float = moved / maxf(delta, 0.0001)
	if speed > 0.4:
		_bob += delta * speed * 4.0
		_step_left -= delta * clampf(speed / 3.0, 0.6, 1.8)
		if _step_left <= 0.0:
			_step_left = STEP_SECONDS
			Audio.play_on(steps, "mandl_steps", 0.1)
	else:
		_bob = lerpf(_bob, roundf(_bob / PI) * PI, clampf(8.0 * delta, 0.0, 1.0))
	body.position.y = absf(sin(_bob)) * 0.06
	body.rotation.z = sin(_bob) * 0.12


func _think(delta: float) -> void:
	_state_time += delta
	_look_left -= delta
	_snatch_cooldown -= delta
	if carried != null and (not is_instance_valid(carried) or carried.state != WorldItem.State.STOLEN):
		carried = null
	match state:
		State.WANDER:
			if _look_left <= 0.0:
				_look_left = LOOK_SECONDS
				if _look_around():
					return
			if randf() < _config.voice_idle_chance * delta:
				say(VoiceLine.Moment.IDLE)
			if walk_to(_goal, _config.bergmandl_speed * 0.55, delta) or _state_time > 20.0:
				_goal = _wander_point()
				_state_time = 0.0
		State.FETCH:
			if not _can_take(_target_item):
				_set_state(State.WANDER)
			elif walk_to(_target_item.global_position, _config.bergmandl_speed, delta) or global_position.distance_to(_target_item.global_position) < GRAB_DISTANCE:
				_grab(_target_item)
		State.SNATCH:
			_think_snatch(delta)
		State.RUN_OFF:
			var speed: float = _config.bergmandl_flee_speed
			if carried != null and carried.data.weight_class == ItemData.WeightClass.HEAVY:
				speed *= 0.6
			if _look_left <= 0.0:
				_look_left = 1.0
				if not visible_players(8.0).is_empty():
					say(VoiceLine.Moment.FLEE)
			if walk_to(_goal, speed, delta) or _state_time > 25.0:
				_drop_carried(true)
				play_sound.rpc("voices/bergmandl/giggle")
				_set_state(State.WANDER)
		State.SCARED:
			if walk_to(_goal, _config.bergmandl_flee_speed, delta) or _state_time > _config.bergmandl_scared_seconds:
				_set_state(State.WANDER)


func _think_snatch(delta: float) -> void:
	var loot: WorldItem = _loot_in_hands(_target_player)
	if loot == null or not _target_player.alive or _target_player.global_position.distance_to(global_position) > _config.bergmandl_sight * 1.3:
		_set_state(State.WANDER)
		return
	walk_to(_target_player.global_position, _config.bergmandl_speed * 1.15, delta)
	if _snatch_cooldown <= 0.0 and _target_player.global_position.distance_to(global_position) < SNATCH_DISTANCE:
		_snatch_cooldown = SNATCH_COOLDOWN
		if randf() < _config.bergmandl_steal_from_hands_chance:
			_grab(loot)
		else:
			play_sound.rpc("voices/bergmandl/giggle", -4.0)


## Looks for players to greet and loot to take. True when it found something to do.
func _look_around() -> bool:
	var seen: Array[Player] = visible_players(_config.bergmandl_sight)
	for player: Player in seen:
		if not _spotted.has(player.peer_id):
			_spotted[player.peer_id] = true
			say(VoiceLine.Moment.SPOT)
	for peer: int in _spotted.keys():
		var still_seen: bool = false
		for player: Player in seen:
			still_seen = still_seen or player.peer_id == peer
		if not still_seen:
			_spotted.erase(peer)
	var item: WorldItem = _nearest_loot()
	if item != null:
		_target_item = item
		_set_state(State.FETCH)
		return true
	for player: Player in seen:
		if _loot_in_hands(player) != null:
			_target_player = player
			_set_state(State.SNATCH)
			return true
	return false


func _nearest_loot() -> WorldItem:
	var best: WorldItem = null
	var best_distance: float = _config.bergmandl_sight
	for node: Node in get_tree().get_nodes_in_group(&"items"):
		var item: WorldItem = node as WorldItem
		if item == null or not _can_take(item):
			continue
		var distance: float = item.global_position.distance_to(global_position)
		if distance < best_distance and can_see(item.global_position + Vector3.UP * 0.2):
			best = item
			best_distance = distance
	return best


## Loot lying around or in a parked Schubkarre, outside the Förderkorb.
func _can_take(item: WorldItem) -> bool:
	if item == null or not is_instance_valid(item) or item.is_queued_for_deletion() or not item.is_loot():
		return false
	if item.global_position.y > Game.HUB_FLOOR_ABOVE or Game.instance.in_mine_cage(item.global_position):
		return false
	if stash.has(item):
		return false
	if item.state == WorldItem.State.CARTED:
		return item.cart != null and item.cart.state == WorldItem.State.FREE
	return item.state == WorldItem.State.FREE


## Loot the player carries in the hands, or the top of the Schubkarre they push.
func _loot_in_hands(player: Player) -> WorldItem:
	if player == null or not is_instance_valid(player):
		return null
	var hands: WorldItem = player.inventory.hands as WorldItem
	if hands != null and hands.helper_peer != 0:
		return null  # two miners holding on: too much for a Bergmandl
	if hands is Schubkarre:
		var cart: Schubkarre = hands as Schubkarre
		return null if cart.cargo.is_empty() else cart.cargo.back()
	return hands if hands != null and hands.is_loot() else null


func _grab(item: WorldItem) -> void:
	item.host_steal(carry_point)
	carried = item
	say(VoiceLine.Moment.ACTION, true)
	play_sound.rpc("voices/bergmandl/giggle", -6.0)
	_goal = far_point()
	_set_state(State.RUN_OFF)


func _drop_carried(into_stash: bool = false) -> void:
	if carried == null:
		return
	var toss: Vector3 = -global_basis.z * 1.5 + Vector3.UP * 2.0
	carried.host_release(carry_point.global_transform, toss)
	if into_stash:
		stash[carried] = true
		carried.state_changed.connect(_forget_stash.bind(carried), CONNECT_ONE_SHOT)
	carried = null


static func _forget_stash(item: WorldItem) -> void:
	stash.erase(item)


func _wander_point() -> Vector3:
	var nav: AStar3D = Game.instance.mine.nav
	var here: int = nav.get_closest_point(global_position)
	var options: PackedInt64Array = nav.get_point_connections(here)
	if options.is_empty():
		return global_position
	# Prefer going on over turning back.
	var point: Vector3 = nav.get_point_position(options[randi() % options.size()])
	if options.size() > 1 and point.distance_to(_goal) < 1.0:
		point = nav.get_point_position(options[randi() % options.size()])
	return point


func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	_repath_left = 0.0


func host_shouted_at(from: Vector3) -> void:
	_drop_carried()
	say(VoiceLine.Moment.SHOUTED_AT, true)
	_goal = away_point(from)
	_set_state(State.SCARED)


func host_hit(damage: int, from: Vector3) -> void:
	_drop_carried()
	health -= damage
	if health <= 0:
		host_vanish(VoiceLine.Moment.DIE, "poof")
		return
	say(VoiceLine.Moment.HIT, true)
	_goal = away_point(from)
	_set_state(State.SCARED)
