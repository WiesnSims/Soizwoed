class_name Creature
extends CharacterBody3D
## Base of every creature. The AI runs on the host only (`_think`); clients see the result
## through the MultiplayerSynchronizer (`net_position` / `net_yaw`, smoothed by a
## NetInterpolator) and RPCs (voice lines, sounds). Shared
## helpers: walking the mine's waypoint graph, line of sight, and creature voices with their
## cooldowns (DESIGN.md §6 "Creature voices").

const LAYER_CREATURES: int = 8  # physics layer 4
const ARRIVE_DISTANCE: float = 0.6
const REPATH_SECONDS: float = 1.0
const STUCK_SECONDS: float = 1.2

var data: EnemyData
var health: int = 1
## Synced from the host (Sync node).
var net_position: Vector3 = Vector3.ZERO
var net_yaw: float = 0.0

var _config: BalanceConfig
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _path: PackedVector3Array = []
var _path_index: int = 0
var _path_goal: Vector3 = Vector3.INF
var _repath_left: float = 0.0
var _stuck_time: float = 0.0
var _last_line_at: float = -INF
var _net: NetInterpolator = NetInterpolator.new()

@onready var voice: AudioStreamPlayer3D = $Voice
@onready var sync: MultiplayerSynchronizer = $Sync


func _ready() -> void:
	add_to_group(&"creatures")
	_config = Balance.config
	health = data.max_health
	collision_layer = LAYER_CREATURES
	collision_mask = 1
	_net.delay = sync.replication_interval * 2.0
	if not multiplayer.is_server():
		sync.synchronized.connect(_on_synchronized)


func _physics_process(delta: float) -> void:
	if multiplayer.is_server() and Game.instance != null and Game.instance.mine != null:
		_think(delta)
		net_position = global_position
		net_yaw = rotation.y


func _process(_delta: float) -> void:
	if not multiplayer.is_server() and _net.sample(Time.get_ticks_msec() / 1000.0):
		global_position = _net.position
		rotation.y = Basis(_net.rotation).get_euler().y


func _on_synchronized() -> void:
	_net.push(Time.get_ticks_msec() / 1000.0, net_position, Quaternion(Vector3.UP, net_yaw))


## The host's AI step; override.
func _think(_delta: float) -> void:
	pass


## Called on the host when a player hits the creature.
func host_hit(_damage: int, _from: Vector3) -> void:
	pass


## Called on the host when a player shouts ("Plärren") nearby.
func host_shouted_at(_from: Vector3) -> void:
	pass


# --- movement --------------------------------------------------------------------------------------

## Walks towards `goal` along the waypoint graph; true once there.
func walk_to(goal: Vector3, speed: float, delta: float) -> bool:
	var to_goal: Vector3 = goal - global_position
	if Vector2(to_goal.x, to_goal.z).length() < ARRIVE_DISTANCE:
		_halt(delta)
		return true
	_repath_left -= delta
	if _repath_left <= 0.0 or goal.distance_to(_path_goal) > 1.5:
		_repath(goal)
	var next: Vector3 = goal
	if to_goal.length() > 4.0 or not can_see(goal + Vector3.UP * 0.5):
		while _path_index < _path.size() and _flat_distance(_path[_path_index]) < ARRIVE_DISTANCE:
			_path_index += 1
		if _path_index < _path.size():
			next = _path[_path_index]
	_step_towards(next, speed, delta)
	return false


func _repath(goal: Vector3) -> void:
	_repath_left = REPATH_SECONDS
	_path_goal = goal
	_path = Game.instance.mine.nav_path(global_position, goal)
	_path_index = 0
	# Skip waypoints behind us.
	if _path.size() > 1 and _flat_distance(_path[1]) < _path[0].distance_to(_path[1]):
		_path_index = 1


func _step_towards(target: Vector3, speed: float, delta: float) -> void:
	var dir: Vector3 = target - global_position
	dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	var before: Vector3 = global_position
	move_and_slide()
	if dir.length_squared() > 0.0:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(10.0 * delta, 0.0, 1.0))
	# Stuck on a rock: skip to the next waypoint, then hop.
	if before.distance_to(global_position) < speed * delta * 0.25:
		_stuck_time += delta
		if _stuck_time > STUCK_SECONDS:
			_stuck_time = 0.0
			_path_index += 1
			if is_on_floor():
				velocity.y = 3.5
	else:
		_stuck_time = 0.0


func _halt(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()


func _flat_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


## A waypoint far from every player (at least `min_distance` if possible), to run off to.
func far_point(min_distance: float = 15.0) -> Vector3:
	var nav: AStar3D = Game.instance.mine.nav
	var ids: PackedInt64Array = nav.get_point_ids()
	var best: Vector3 = global_position
	var best_score: float = -INF
	for i: int in 16:
		var point: Vector3 = nav.get_point_position(ids[randi() % ids.size()])
		var score: float = _distance_to_players(point)
		if Game.instance.in_mine_cage(point):
			score -= 100.0
		if score > best_score:
			best_score = score
			best = point
		if score >= min_distance + 10.0:
			break
	return best


## A waypoint in the direction away from `from`, a good distance off.
func away_point(from: Vector3) -> Vector3:
	var nav: AStar3D = Game.instance.mine.nav
	var best: Vector3 = global_position
	var best_score: float = -INF
	for id: int in nav.get_point_ids():
		var point: Vector3 = nav.get_point_position(id)
		var from_threat: float = point.distance_to(from)
		var from_me: float = point.distance_to(global_position)
		if from_me > 30.0:
			continue
		var score: float = from_threat - absf(from_me - 14.0) * 0.5
		if score > best_score:
			best_score = score
			best = point
	return best


func _distance_to_players(point: Vector3) -> float:
	var best: float = INF
	for player: Player in Game.instance.players():
		best = minf(best, player.global_position.distance_to(point))
	return best


## Line of sight from the creature's eyes to `point` (only rock blocks it).
func can_see(point: Vector3) -> bool:
	var eyes: Vector3 = global_position + Vector3.UP * 0.7
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eyes, point, 1)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Players in the mine within `distance` that the creature can see.
func visible_players(distance: float) -> Array[Player]:
	var result: Array[Player] = []
	for player: Player in Game.instance.players():
		if not player.alive or player.global_position.y > Game.HUB_FLOOR_ABOVE:
			continue
		var head: Vector3 = player.global_position + Vector3.UP * 1.5
		if head.distance_to(global_position) <= distance and can_see(head):
			result.append(player)
	return result


# --- voice -----------------------------------------------------------------------------------------

## Maybe says a line for `moment` (host). `urgent` lines (hit, shouted at, dying) ignore the
## creature's own cooldown but still respect the global gap.
func say(moment: VoiceLine.Moment, urgent: bool = false) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if not urgent and now - _last_line_at < _config.voice_cooldown_per_creature:
		return
	if _distance_to_players(global_position) > _config.voice_max_distance:
		return
	var lines: Array[VoiceLine] = data.lines_for(moment)
	if lines.is_empty() or not Game.instance.claim_voice_slot():
		return
	_last_line_at = now
	_play_line.rpc(data.voice_lines.find(lines.pick_random()))


@rpc("authority", "call_local", "reliable")
func _play_line(index: int) -> void:
	if not Audio.creature_lines_enabled or index < 0:
		return
	voice.stream = data.voice_lines[index].stream
	voice.pitch_scale = randf_range(0.96, 1.05)
	voice.play()


## A non-speech creature sound (giggle, growl, ...); always plays, it is a gameplay cue.
@rpc("authority", "call_local", "reliable")
func play_sound(sound: String, volume_db: float = 0.0) -> void:
	Audio.play_at(sound, global_position + Vector3.UP * 0.6, &"Creatures", volume_db, 30.0, randf_range(0.95, 1.08))


## The last line and sound when the creature is gone, left behind as one-shot sounds.
@rpc("authority", "call_local", "reliable")
func _farewell(line_index: int, sound: String) -> void:
	var where: Vector3 = global_position + Vector3.UP * 0.6
	if sound != "":
		Audio.play_at(sound, where, &"Creatures", 0.0, 25.0)
	if line_index >= 0 and Audio.creature_lines_enabled:
		Audio.play_stream_at(data.voice_lines[line_index].stream, where, &"Creatures", voice.volume_db, voice.max_distance)


## Says a `moment` line one last time and disappears (host).
func host_vanish(moment: VoiceLine.Moment, sound: String) -> void:
	var lines: Array[VoiceLine] = data.lines_for(moment)
	var index: int = -1 if lines.is_empty() else data.voice_lines.find(lines.pick_random())
	_farewell.rpc(index, sound)
	queue_free()
