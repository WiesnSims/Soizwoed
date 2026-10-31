class_name Salzweibl
extends Creature
## The salt woman (DESIGN.md §6, Salzsee and Die Tiefe): a gaunt figure crusted with salt
## who waits in the dark and calls out in a voice you know – something a teammate really said
## earlier in the voice chat (only from those who allow it), or a generic call when there is
## none (solo, ENet, or nobody allowed it).
##
## Its rule: whoever comes to it alone, it grabs and pins (v2): they cannot move or act and
## their health drains away until a teammate shoots or shoves it off (alone, it lets go after a
## few seconds). Two miners together it does not dare: it shrieks and is gone. It can be killed,
## but it is quick to vanish when hurt. Counter: stick together, and call each other by name –
## the real teammate answers.
##
## It does not walk: it waits at a spot out of sight of the loneliest miner, calls every few
## seconds, and after a strike or a fright vanishes and waits somewhere new.

enum State { WAIT, GONE, PIN }

const CHECK_SECONDS: float = 0.25
## Seen by a miner (lamp on it) closer than this, with a teammate by them: it flees.
const SEEN_DISTANCE: float = 9.0
## Its miner is this much further than lure_max away for a while: it moves closer.
const MOVE_ON_SECONDS: float = 12.0

## Synced: whether it is there to be seen (fades on every peer).
var net_shown: bool = false

var state: State = State.WAIT
var _target: Player
var _check_left: float = 0.0
var _call_left: float = 3.0
var _gone_left: float = 0.0
var _far_time: float = 0.0
var _alpha: float = 0.0
var _materials: Array[StandardMaterial3D] = []
var _hum_left: float = 0.0
## The miner it holds (PIN), how long it may still hold them, and the drain not yet dealt.
var _victim: Player
var _pin_left: float = 0.0
var _pin_carry: float = 0.0

@onready var body: Node3D = $Body


func _ready() -> void:
	super()
	health = scaled_health(_config.salzweibl_health)
	_build_body()
	if multiplayer.is_server():
		# Starts unseen and first picks a spot near the loneliest miner.
		state = State.GONE
		net_shown = false
		_gone_left = 1.0


func _process(delta: float) -> void:
	super(delta)
	_alpha = move_toward(_alpha, 1.0 if net_shown else 0.0, delta * (0.7 if net_shown else 3.0))
	for material: StandardMaterial3D in _materials:
		material.albedo_color.a = _alpha * 0.9
	body.visible = _alpha > 0.01
	body.rotation.y = sin(Time.get_ticks_msec() / 2300.0) * 0.08
	# Close by you hear her hum to herself.
	_hum_left -= delta
	var camera: Camera3D = get_viewport().get_camera_3d()
	if net_shown and _hum_left <= 0.0 and camera != null and camera.global_position.distance_to(global_position) < 7.0:
		_hum_left = randf_range(5.0, 8.0)
		Audio.play_at("salzweibl_hum", global_position + Vector3.UP * 1.5, &"Creatures", -6.0, 10.0)


func _think(delta: float) -> void:
	if state == State.PIN:
		_hold(delta)
		return
	if state == State.GONE:
		_gone_left -= delta
		if _gone_left <= 0.0:
			_appear()
		return
	_halt(delta)
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = CHECK_SECONDS
		if _check_players():
			return
	if _target == null or not is_instance_valid(_target) or not _target.alive:
		_target = _loneliest()
		return
	var distance: float = _target.global_position.distance_to(global_position)
	_far_time = _far_time + delta if distance > _config.salzweibl_lure_max + 10.0 else 0.0
	if _far_time > MOVE_ON_SECONDS and not _seen_by_anyone():
		_far_time = 0.0
		_move_near(_loneliest())
		return
	_call_left -= delta
	if _call_left <= 0.0 and distance < _config.salzweibl_call_range and not _seen_by_anyone():
		_call_left = randf_range(_config.salzweibl_call_min, _config.salzweibl_call_max)
		_call()


## Strikes a lone miner who came close, flees from two together or from being seen by a pair.
## True when it acted.
func _check_players() -> bool:
	var chest: Vector3 = global_position + Vector3.UP * 1.2
	for player: Player in Game.instance.players():
		if not player.alive or player.global_position.y > Game.HUB_FLOOR_ABOVE:
			continue
		var distance: float = player.global_position.distance_to(global_position)
		var alone: bool = is_alone(player)
		if distance < _config.salzweibl_strike_distance:
			if alone:
				_strike(player)
			else:
				_flee()
			return true
		if not alone and distance < SEEN_DISTANCE and player.lights_point(chest) and can_see(player.global_position + Vector3.UP * 1.5):
			_flee()
			return true
	return false


## No other living miner close by.
func is_alone(player: Player) -> bool:
	for other: Player in Game.instance.players():
		if other != player and other.alive and other.global_position.distance_to(player.global_position) < _config.salzweibl_together_distance:
			return false
	return true


## Grabs a lone miner and holds them fast (DESIGN.md §6: pin).
func _strike(player: Player) -> void:
	say(VoiceLine.Moment.ACTION, true)
	play_sound.rpc("salzweibl_shriek", 4.0)
	state = State.PIN
	_victim = player
	_pin_carry = 0.0
	var solo: bool = Game.instance.players().size() <= 1
	_pin_left = _config.salzweibl_pin_seconds_solo if solo else _config.salzweibl_pin_seconds
	var to: Vector3 = player.global_position - global_position
	to.y = 0.0
	if to.length() > 0.1:
		look_at(global_position + to, Vector3.UP)
	Game.instance.host_pin_player(player, true)
	print("[salzweibl] pins P%d" % player.peer_id)


## Holding its miner: their health drains away until it is driven off or lets go.
func _hold(delta: float) -> void:
	_halt(delta)
	_pin_left -= delta
	if _victim == null or not is_instance_valid(_victim) or not _victim.alive or _victim.downed:
		_release()
		_vanish()
		return
	_pin_carry += scaled_damage(roundi(_config.salzweibl_pin_dps)) * delta
	if _pin_carry >= 3.0:
		var due: int = floori(_pin_carry)
		_pin_carry -= due
		Game.instance.host_damage_player(_victim, due)
	if _pin_left <= 0.0:
		print("[salzweibl] lets go of P%d" % _victim.peer_id)
		_release()
		_vanish()


func _release() -> void:
	if _victim != null and is_instance_valid(_victim) and _victim.is_inside_tree() and not _victim.is_queued_for_deletion():
		Game.instance.host_pin_player(_victim, false)
	_victim = null


func _flee() -> void:
	say(VoiceLine.Moment.FLEE, true)
	play_sound.rpc("salzweibl_shriek", -2.0)
	print("[salzweibl] fled from a pair")
	_vanish()


func _vanish() -> void:
	state = State.GONE
	net_shown = false
	_gone_left = _config.salzweibl_hide_seconds
	_target = null
	# Out of everyone's way while gone (nobody bumps into an invisible woman).
	global_position = Vector3(global_position.x, -100.0, global_position.z)
	velocity = Vector3.ZERO


func _appear() -> void:
	_move_near(_loneliest())
	state = State.WAIT
	net_shown = true
	_call_left = randf_range(2.0, 5.0)


## Calls out: a teammate's real voice if there is one to copy, else one of its own lines.
func _call() -> void:
	var snippet: Dictionary = VoiceChat.pick_snippet(_target.peer_id)
	if not snippet.is_empty():
		_play_snippet.rpc(snippet.packets)
		print("[salzweibl] calls with the voice of P%d" % int(snippet.peer))
	else:
		say(VoiceLine.Moment.IDLE, true)
		print("[salzweibl] calls")


@rpc("authority", "call_local", "reliable")
func _play_snippet(packets: Array) -> void:
	var sound: AudioStreamWAV = VoiceChat.decode(packets)
	if sound == null:
		return
	voice.stream = sound
	voice.pitch_scale = randf_range(0.97, 1.0)
	voice.play()


## The miner furthest from any teammate (the only one, solo).
func _loneliest() -> Player:
	var best: Player = null
	var best_gap: float = -1.0
	for player: Player in Game.instance.players():
		if not player.alive or player.global_position.y > Game.HUB_FLOOR_ABOVE or Game.instance.in_mine_cage(player.global_position):
			continue
		var gap: float = 1000.0
		for other: Player in Game.instance.players():
			if other != player and other.alive:
				gap = minf(gap, other.global_position.distance_to(player.global_position))
		if gap > best_gap:
			best = player
			best_gap = gap
	return best


## Moves (unseen) to a waypoint at a good luring distance from `player`, out of their sight,
## preferably in a side passage, away from the others.
func _move_near(player: Player) -> void:
	_target = player
	if player == null:
		return
	var nav: AStar3D = Game.instance.mine.nav
	var head: Vector3 = player.global_position + Vector3.UP * 1.5
	var best: Vector3 = global_position
	var best_score: float = -INF
	for id: int in nav.get_point_ids():
		var point: Vector3 = nav.get_point_position(id)
		var distance: float = point.distance_to(player.global_position)
		if distance < _config.salzweibl_lure_min or distance > _config.salzweibl_lure_max or Game.instance.in_mine_cage(point):
			continue
		var score: float = randf() * 3.0
		if not Game.instance.clear_line(head, point + Vector3.UP * 1.2):
			score += 10.0
		if nav.get_point_connections(id).size() <= 1:
			score += 3.0  # a dead end
		for other: Player in Game.instance.players():
			if other != player and other.alive:
				score += minf(other.global_position.distance_to(point), 30.0) * 0.1
		if score > best_score:
			best_score = score
			best = point
	global_position = best + Vector3.UP * 0.1
	_far_time = 0.0


func _seen_by_anyone() -> bool:
	var chest: Vector3 = global_position + Vector3.UP * 1.2
	for player: Player in Game.instance.players():
		if player.alive and player.lights_point(chest) and Game.instance.clear_line(player.beam.global_position, chest):
			return true
	return false


## A hit hurts it and drives it off – and lets go of whoever it holds.
func host_hit(damage: int, from: Vector3) -> void:
	if state == State.GONE:
		return
	var held: bool = state == State.PIN
	_release()
	if host_damage(damage, from, "salzweibl_shriek"):
		return
	say(VoiceLine.Moment.HIT, true)
	play_sound.rpc("salzweibl_shriek", 0.0)
	if held:
		print("[salzweibl] driven off")
	_vanish()


func _exit_tree() -> void:
	if multiplayer.is_server() and Game.instance != null:
		_release()


func _build_body() -> void:
	var dress: StandardMaterial3D = BodyParts.rough(Color(0.86, 0.84, 0.8, 0.9), 0.9, 1.0, 0.25)
	var skin: StandardMaterial3D = BodyParts.rough(Color(0.78, 0.76, 0.72, 0.9), 0.7, 0.6, 0.15)
	var hair: StandardMaterial3D = BodyParts.rough(Color(0.32, 0.31, 0.3, 0.9), 1.0, 0.8, 0.5)
	var crust: StandardMaterial3D = BodyParts.rough(Color(0.95, 0.95, 0.93, 0.9), 0.3, 0.5, 0.3)
	for material: StandardMaterial3D in [dress, skin, hair, crust]:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_materials.append(material)
	# Tall and thin in a long dress gone stiff with salt; long grey hair over her face.
	BodyParts.add(body, BodyParts.cylinder(0.16, 0.42, 1.3), dress, Vector3(0, 0.65, 0))
	BodyParts.add(body, BodyParts.cylinder(0.13, 0.17, 0.45), dress, Vector3(0, 1.48, 0))
	BodyParts.add(body, BodyParts.sphere(0.12, 14), skin, Vector3(0, 1.82, 0), Vector3.ZERO, Vector3(0.9, 1.15, 0.95))
	BodyParts.add(body, BodyParts.cylinder(0.13, 0.17, 0.75, 12), hair, Vector3(0, 1.55, 0.03))
	BodyParts.add(body, BodyParts.box(Vector3(0.2, 0.42, 0.04)), hair, Vector3(0, 1.66, -0.11))  # over the face
	for side: float in [-1.0, 1.0]:
		BodyParts.add(body, BodyParts.capsule(0.035, 0.8), skin, Vector3(side * 0.2, 1.25, -0.12), Vector3(-35, 0, side * 12))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in 14:
		var a: float = rng.randf() * TAU
		var y: float = rng.randf_range(0.1, 1.2)
		var r: float = lerpf(0.42, 0.18, y / 1.3)
		BodyParts.add(body, BodyParts.box(Vector3.ONE * rng.randf_range(0.05, 0.1)), crust, Vector3(sin(a) * r, y, cos(a) * r), Vector3(rng.randf() * 90.0, rng.randf() * 90.0, 0.0))
	var eye: StandardMaterial3D = BodyParts.glow(Color(0.75, 0.9, 1.0), 2.5)
	eye.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materials.append(eye)
	for side: float in [-1.0, 1.0]:
		BodyParts.add(body, BodyParts.sphere(0.012, 6), eye, Vector3(side * 0.04, 1.85, -0.14))
	BodyParts.no_shadows(body)
	body.visible = false
