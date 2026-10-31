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
const WEDGED_SECONDS: float = 4.0
const DODGE_AFTER: float = 0.25
const DODGE_SECONDS: float = 0.7

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
var _progress_from: Vector3 = Vector3.INF
var _progress_time: float = 0.0
var _dodge_left: float = 0.0
var _dodge_side: float = 1.0
var _last_line_at: float = -INF
var _net: NetInterpolator = NetInterpolator.new()
## Host: seconds left of being stunned (Alphorn); the AI does nothing meanwhile.
var stunned_left: float = 0.0
## A "Raunacht" elite (DESIGN.md §6): set by Game before the creature enters the tree, on every
## peer. More health, faster, harder hits, red glowing eyes, and a box of ammo when it dies.
var elite: bool = false
## Host: the hit being applied right now landed on the creature's weak spot (Game.request_hit
## sets it before calling host_hit; the shooter's screen decided, DESIGN.md §11).
var hit_weak: bool = false
## Host: seconds left burning (a flare set it alight) and the damage per second.
var _burn_left: float = 0.0
var _burn_dps: float = 0.0
var _burn_carry: float = 0.0
var _burn_tick: float = 0.0
## Every peer: the flames on it while it burns.
var _flames: Node3D

@onready var voice: AudioStreamPlayer3D = $Voice
@onready var sync: MultiplayerSynchronizer = $Sync


func _ready() -> void:
	add_to_group(&"creatures")
	_config = Balance.config
	collision_layer = LAYER_CREATURES
	collision_mask = 1
	_net.delay = sync.replication_interval * 2.0
	if not multiplayer.is_server():
		sync.synchronized.connect(_on_synchronized)
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if elite:
		_mark_elite.call_deferred()  # after the creature has built its body


func _physics_process(delta: float) -> void:
	if multiplayer.is_server() and Game.instance != null and Game.instance.mine != null:
		_tick_burning(delta)
		if health <= 0 or is_queued_for_deletion():
			return
		if stunned_left > 0.0:
			stunned_left -= delta
			_halt(delta)
		else:
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


## Called on the host for every noise or vibration within its reach (Game.host_noise):
## `where` it came from and how far it carries (m). Override for creatures that listen.
func host_heard(_where: Vector3, _reach: float) -> void:
	pass


## The Alphorn's blast: stands dazed for `seconds` (host).
func host_stun(seconds: float) -> void:
	stunned_left = maxf(stunned_left, seconds)


## How much a shot landing at `point` (world space) counts: above 1 on a weak spot, below 1
## on armour. Decided on the shooter's screen from the creature as it looks there. Override.
func weak_spot_mult(_point: Vector3) -> float:
	return 1.0


## Whether bullets can touch it right now (a Kasermandl in the dark: they go straight through).
func can_be_shot() -> bool:
	return true


## Hit by a flare (host): it hurts, and the creature catches fire. Override for creatures that
## react to the light itself.
func host_flared(damage: int, from: Vector3) -> void:
	hit_weak = false
	host_hit(damage, from)
	if health > 0 and not is_queued_for_deletion():
		host_ignite(_config.flare_burn_seconds, _config.flare_burn_dps)


## Sets it alight for `seconds`, losing `dps` health a second (host).
func host_ignite(seconds: float, dps: float) -> void:
	if _burn_left <= 0.0:
		_set_burning.rpc(true)
	_burn_left = maxf(_burn_left, seconds)
	_burn_dps = maxf(_burn_dps, dps)


func _tick_burning(delta: float) -> void:
	if _burn_left <= 0.0:
		return
	_burn_left -= delta
	_burn_carry += _burn_dps * delta
	_burn_tick -= delta
	if _burn_tick <= 0.0 and _burn_carry >= 1.0:
		_burn_tick = 0.5
		var damage: int = floori(_burn_carry)
		_burn_carry -= damage
		hit_weak = false
		host_hit(damage, global_position)
	if _burn_left <= 0.0 and health > 0 and not is_queued_for_deletion():
		_burn_dps = 0.0
		_set_burning.rpc(false)


@rpc("authority", "call_local", "reliable")
func _set_burning(on: bool) -> void:
	if not on:
		if _flames != null:
			_flames.queue_free()
			_flames = null
		return
	if _flames != null:
		return
	_flames = Node3D.new()
	_flames.name = "Flames"
	add_child(_flames)
	_flames.position = Vector3.UP * 0.6
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 1.6
	light.omni_range = 4.0
	_flames.add_child(light)
	var fire: CPUParticles3D = CPUParticles3D.new()
	fire.amount = 24
	fire.lifetime = 0.6
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.3
	fire.direction = Vector3.UP
	fire.spread = 20.0
	fire.gravity = Vector3(0.0, 2.5, 0.0)
	fire.initial_velocity_min = 0.3
	fire.initial_velocity_max = 0.9
	fire.scale_amount_min = 0.06
	fire.scale_amount_max = 0.14
	var flame: SphereMesh = BodyParts.sphere(0.5, 6)
	flame.material = BodyParts.glow(Color(1.0, 0.5, 0.15), 3.0)
	fire.mesh = flame
	_flames.add_child(fire)
	Audio.play_at("flare_hiss", global_position + Vector3.UP * 0.6, &"Creatures", -4.0, 18.0)


## A Raunacht elite: red glowing eyes and a faint red glow about it (every peer).
func _mark_elite() -> void:
	var body: Node3D = get_node_or_null(^"Body") as Node3D
	if body == null:
		return
	for node: Node in body.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		var material: StandardMaterial3D = mesh.material_override as StandardMaterial3D
		if material != null and material.emission_enabled and material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
			var red: StandardMaterial3D = material.duplicate() as StandardMaterial3D
			red.albedo_color = Color(1.0, 0.08, 0.05, material.albedo_color.a)
			red.emission = Color(1.0, 0.08, 0.05)
			red.emission_energy_multiplier = maxf(material.emission_energy_multiplier, 5.0)
			mesh.material_override = red
	var aura: OmniLight3D = OmniLight3D.new()
	aura.name = "RaunachtGlow"
	aura.light_color = Color(1.0, 0.15, 0.08)
	aura.light_energy = 0.5
	aura.omni_range = 2.5
	aura.position = Vector3.UP * 0.8
	body.add_child(aura)
	body.scale *= 1.08


## Whether a point lies in the smoke of a "Bierzelt" bomb, which creatures avoid.
func in_smoke(point: Vector3) -> bool:
	return Game.instance != null and Game.instance.in_smoke(point)


# --- movement --------------------------------------------------------------------------------------

## Walks towards `goal` along the waypoint graph; true once there.
func walk_to(goal: Vector3, speed: float, delta: float) -> bool:
	speed *= speed_mult()
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
	# The stink of a "Bierzelt" bomb: get out of it, and never walk into it.
	if in_smoke(global_position):
		next = Game.instance.smoke_exit(global_position)
	elif in_smoke(next):
		_halt(delta)
		return false
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
	var facing: Vector3 = dir
	# Something in the way (a cart, a crate, another creature): step around it for a moment.
	_dodge_left -= delta
	if _dodge_left > 0.0:
		dir = (dir + dir.cross(Vector3.UP) * _dodge_side * 1.3).normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	var before: Vector3 = global_position
	move_and_slide()
	if facing.length_squared() > 0.0:
		rotation.y = lerp_angle(rotation.y, atan2(-facing.x, -facing.z), clampf(10.0 * delta, 0.0, 1.0))
	if _dodge_left <= 0.0 and before.distance_to(global_position) < speed * delta * 0.25 and _stuck_time > DODGE_AFTER:
		_dodge_side = -_dodge_side
		_dodge_left = DODGE_SECONDS
	# Wedged for good (re-pathing keeps sending it into the same rock): back onto the graph.
	_progress_time += delta
	if global_position.distance_to(_progress_from) > 0.5:
		_progress_from = global_position
		_progress_time = 0.0
	elif _progress_time > WEDGED_SECONDS:
		_progress_time = 0.0
		var nav: AStar3D = Game.instance.mine.nav
		global_position = nav.get_point_position(nav.get_closest_point(global_position)) + Vector3.UP * 0.3
		_path_index = mini(_path_index + 1, _path.size())
		print("[creature] %s was wedged, back on the path" % name)
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


## Whether `player` carries the Fundstück: every creature's favourite target (DESIGN.md §2).
func is_carrier(player: Player) -> bool:
	return Game.instance != null and Game.instance.alarm_on and Game.instance.fundstueck_carrier() == player


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


# --- combat ----------------------------------------------------------------------------------------

## `base` health scaled for the crew size (solo creatures are weaker) and the shift (DESIGN.md §8).
func scaled_health(base: int) -> int:
	var run: RunState = GameState.run
	var elite_mult: float = _config.elite_health_mult if elite else 1.0
	var overtime_mult: float = _config.overtime_health_mult if Game.instance != null and Game.instance.has_overtime(&"zaach") else 1.0
	return maxi(1, roundi(base * elite_mult * overtime_mult * _config.enemy_health_mult(run.player_count if run != null else 1, run.shift_index if run != null else 0)))


## `base` damage of an attack, growing with the shift (DESIGN.md §8).
func scaled_damage(base: int) -> int:
	var elite_mult: float = _config.elite_damage_mult if elite else 1.0
	return maxi(1, roundi(base * elite_mult * _config.enemy_damage_mult(GameState.run.shift_index if GameState.run != null else 0)))


## Elites move faster (applied to every walk).
func speed_mult() -> float:
	return _config.elite_speed_mult if elite else 1.0


## Generic damage (host): health down, a flinch everyone sees, death at 0. True if it died.
func host_damage(damage: int, from: Vector3, die_sound: String = "") -> bool:
	if damage <= 0 or health <= 0:
		return false
	if data.id == &"grubenhund" and Game.instance != null and Game.instance.has_overtime(&"panzerhunde"):
		damage = maxi(1, roundi(damage * _config.overtime_dog_damage_taken))  # Überstund: armoured dogs
	health -= damage
	_flinch.rpc(from)
	if health <= 0:
		host_die(die_sound)
		return true
	return false


## Killed (host): a last line and sound, and the body drops where it stood on every peer.
func host_die(sound: String = "") -> void:
	var lines: Array[VoiceLine] = data.lines_for(VoiceLine.Moment.DIE)
	var index: int = -1 if lines.is_empty() else data.voice_lines.find(lines.pick_random())
	_died.rpc(index, sound)
	print("[creature] %s %s killed" % [data.id, name])
	if Game.instance != null:
		Game.instance.host_boss_died(self)
		if elite:
			Game.instance.host_elite_drop(global_position)
	queue_free()


@rpc("authority", "call_local", "unreliable")
func _flinch(from: Vector3) -> void:
	# Heard on every peer even when the creature's own cry is on cooldown: the shot went in.
	Audio.play_at("flesh_hit", global_position + Vector3.UP * 0.6, &"Creatures", 0.0, 25.0, randf_range(0.9, 1.1))
	var body: Node3D = get_node_or_null(^"Body") as Node3D
	if body == null:
		return
	var away: Vector3 = (global_position - from)
	away.y = 0.0
	var jolt: Vector3 = to_local(global_position + away.normalized() * 0.12) if away.length() > 0.01 else Vector3.ZERO
	var tween: Tween = body.create_tween()
	tween.tween_property(body, "position", jolt, 0.05)
	tween.tween_property(body, "position", Vector3.ZERO, 0.15)


@rpc("authority", "call_local", "reliable")
func _died(line_index: int, sound: String) -> void:
	_farewell(line_index, sound)
	var body: Node3D = get_node_or_null(^"Body") as Node3D
	if body == null or not body.visible:
		return
	# The body falls over and sinks into the floor, then is gone.
	var corpse: Node3D = body.duplicate() as Node3D
	get_tree().current_scene.add_child(corpse)
	corpse.global_transform = body.global_transform
	var tween: Tween = corpse.create_tween()
	tween.tween_property(corpse, "rotation:z", corpse.rotation.z + PI / 2.0 * (1.0 if randf() < 0.5 else -1.0), 0.35)
	tween.tween_interval(3.0)
	tween.tween_property(corpse, "position:y", corpse.position.y - 0.8, 2.0)
	tween.tween_callback(corpse.queue_free)


## Says a `moment` line one last time and disappears (host).
func host_vanish(moment: VoiceLine.Moment, sound: String) -> void:
	var lines: Array[VoiceLine] = data.lines_for(moment)
	var index: int = -1 if lines.is_empty() else data.voice_lines.find(lines.pick_random())
	_farewell.rpc(index, sound)
	queue_free()
