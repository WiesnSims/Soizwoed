class_name Seemuada
extends Creature
## D'Seemuada (DESIGN.md §6 bosses, the Salzsee): a giant Tatzelwurm, "the lake's mother", living
## in the black brine of the Fundort's lake. She sleeps on the bottom until a miner comes near,
## makes a noise or hurts her. Then:
## - under the surface she swims to the shore nearest the miner she wants (the Fundstück's carrier
##   first) – only a swirl on the water shows where;
## - she rears up out of the lake: whoever is within reach of the water gets bitten, whoever is
##   further off gets a gob of brine spat at them;
## - after a few seconds, or when hurt too much, she sinks again.
## Only her head and neck above the water can be hit; the head is the soft spot. While she lives
## the Fundstück stays in its salt shell (Game). Counter: stay back from the shore, shoot her head
## while she is up, and do not fall in.

enum State { SLEEP, UNDER, RISE, UP, SINK }

const RISE_SECONDS: float = 0.9
const BITE_SECONDS: float = 0.55
const SEGMENTS: int = 13
## Kept this far inside the lake's edge.
const SHORE_MARGIN: float = 0.9
const WAKE_DISTANCE: float = 16.0
const LOOK_SECONDS: float = 0.3

## Synced presentation: how far she is out of the water (0–1) and how far the head is thrown
## out in a bite (0–1).
var net_emerge: float = 0.0
var net_lunge: float = 0.0

var state: State = State.SLEEP
var _lake: Lake
var _target: Player
var _goal: Vector3
var _state_time: float = 0.0
var _look_left: float = 0.0
var _bite_left: float = 0.0
var _spit_left: float = 1.0
var _biting: float = -1.0
var _bitten: bool = false
var _hurt_up: int = 0
var _segments: Array[MeshInstance3D] = []
var _head: Node3D
var _swirl: MeshInstance3D

@onready var body: Node3D = $Body
@onready var shape: CollisionShape3D = $Shape


func _ready() -> void:
	super()
	var run: RunState = GameState.run
	health = maxi(1, roundi(_config.seemuada_health * _config.boss_health_mult(run.shift_index if run != null else 0, run.player_count if run != null else 1)))
	collision_mask = 0  # she swims; the lake has no floor for her
	_goal = global_position
	_build_body()


func _process(delta: float) -> void:
	super(delta)
	_pose()
	shape.disabled = net_emerge < 0.5


func _halt(_delta: float) -> void:
	velocity = Vector3.ZERO


func _think(delta: float) -> void:
	if _lake == null or not is_instance_valid(_lake):
		_lake = _find_lake()
		if _lake == null:
			return
	_state_time += delta
	_bite_left -= delta
	_spit_left -= delta
	_look_left -= delta
	if _look_left <= 0.0:
		_look_left = LOOK_SECONDS
		_target = _pick_target()
	match state:
		State.SLEEP:
			if _target != null and _target.global_position.distance_to(global_position) < WAKE_DISTANCE:
				_wake()
		State.UNDER:
			if _target != null:
				_goal = _shore_point(_target.global_position)
			_swim_to(_goal, delta)
			if _state_time > _config.seemuada_under_seconds and _target != null and _flat(_goal - global_position) < 0.6:
				_set_state(State.RISE)
				play_sound.rpc("seemuada_roar", 8.0)
				play_sound.rpc("splash", 6.0)
		State.RISE:
			net_emerge = minf(1.0, net_emerge + delta / RISE_SECONDS)
			_face_target(delta)
			if net_emerge >= 1.0:
				_hurt_up = 0
				_set_state(State.UP)
		State.UP:
			_fight(delta)
		State.SINK:
			net_lunge = 0.0
			net_emerge = maxf(0.0, net_emerge - delta / RISE_SECONDS)
			if net_emerge <= 0.0:
				_burn_left = 0.0
				_set_state(State.UNDER)


## Up out of the water: bite whoever is close to the shore, spit at whoever is not.
func _fight(delta: float) -> void:
	_face_target(delta)
	if _biting >= 0.0:
		_biting += delta
		net_lunge = sin(clampf(_biting / BITE_SECONDS, 0.0, 1.0) * PI)
		if not _bitten and _biting > BITE_SECONDS * 0.5:
			_bitten = true
			play_sound.rpc("tatzel_bite", 6.0)
			if _target != null and is_instance_valid(_target) and _target.alive and _flat(_target.global_position - global_position) < _config.seemuada_bite_reach + 0.6:
				Game.instance.host_damage_player(_target, scaled_damage(_config.seemuada_bite_damage))
				print("[seemuada] bit P%d" % _target.peer_id)
		if _biting >= BITE_SECONDS:
			_biting = -1.0
			net_lunge = 0.0
		return
	if _target != null:
		var distance: float = _flat(_target.global_position - global_position)
		if distance < _config.seemuada_bite_reach and _bite_left <= 0.0:
			_bite_left = _config.seemuada_bite_cooldown
			_biting = 0.0
			_bitten = false
			play_sound.rpc("tatzel_hiss", 6.0)
		elif distance >= _config.seemuada_bite_reach and distance < _config.seemuada_spit_range and _spit_left <= 0.0 \
				and Game.instance.clear_line(_head.global_position, _target.global_position + Vector3.UP * 1.2):
			_spit_left = _config.seemuada_spit_cooldown
			var aim: Vector3 = _target.global_position + Vector3.UP * 0.9 + _target.velocity * 0.4
			Game.instance.host_spit(_head.global_position, aim, scaled_damage(_config.seemuada_spit_damage), get_path())
	if _state_time > _config.seemuada_surface_seconds or _hurt_up >= _config.seemuada_pain_dive or _target == null:
		play_sound.rpc("splash", 4.0)
		_set_state(State.SINK)


func boss_fighting() -> bool:
	return state != State.SLEEP


func _wake() -> void:
	if state != State.SLEEP:
		return
	_set_state(State.UNDER)
	Game.instance.message_everyone("MSG_SEEMUADA_AWAKE")
	play_sound.rpc("seemuada_roar", 4.0)
	print("[seemuada] awake, health %d" % health)


## The Fundstück's carrier if she can reach for them, else the miner nearest her lake.
func _pick_target() -> Player:
	var best: Player = null
	var best_distance: float = INF
	for player: Player in Game.instance.players():
		if not player.alive or player.global_position.y > Game.HUB_FLOOR_ABOVE:
			continue
		var distance: float = _flat(player.global_position - _shore_point(player.global_position))
		if distance > _config.seemuada_spit_range:
			continue
		distance -= 30.0 if is_carrier(player) else 0.0
		if distance < best_distance:
			best = player
			best_distance = distance
	return best


## The point on the water (inside the lake, near its edge) closest to `where`.
func _shore_point(where: Vector3) -> Vector3:
	var local: Vector3 = _lake.to_local(where)
	var half: Vector3 = _lake.size / 2.0 - Vector3(SHORE_MARGIN, 0.0, SHORE_MARGIN)
	local = Vector3(clampf(local.x, -half.x, half.x), 0.0, clampf(local.z, -half.z, half.z))
	return _lake.to_global(local)


func _swim_to(goal: Vector3, delta: float) -> void:
	var to: Vector3 = goal - global_position
	to.y = 0.0
	global_position += to.limit_length(_config.seemuada_swim_speed * speed_mult() * delta)
	global_position.y = _lake.surface_y()
	if to.length() > 0.2:
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), clampf(3.0 * delta, 0.0, 1.0))


func _face_target(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var to: Vector3 = _target.global_position - global_position
	if Vector2(to.x, to.z).length() > 0.2:
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), clampf(5.0 * delta, 0.0, 1.0))


func _find_lake() -> Lake:
	var best: Lake = null
	for node: Node in Game.instance.mine.find_children("*", "Node3D", true, false):
		var lake: Lake = node as Lake
		if lake != null and (best == null or lake.global_position.distance_to(global_position) < best.global_position.distance_to(global_position)):
			best = lake
	if best != null:
		global_position = Vector3(global_position.x, best.surface_y(), global_position.z)
	return best


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	_biting = -1.0


func host_heard(where: Vector3, reach: float) -> void:
	if state == State.SLEEP and where.distance_to(global_position) < minf(reach, 25.0):
		_wake()


func host_hit(damage: int, from: Vector3) -> void:
	if net_emerge < 0.5:
		return
	_wake()
	if host_damage(damage, from, "seemuada_roar"):
		return
	_hurt_up += damage
	if randf() < 0.3:
		play_sound.rpc("tatzel_hiss", 4.0)


## Her head is soft; the scaly neck takes little.
func weak_spot_mult(point: Vector3) -> float:
	if _head == null:
		return 1.0
	return _config.seemuada_head_mult if point.distance_to(_head.global_position) < 0.8 else _config.seemuada_neck_mult


func can_be_shot() -> bool:
	return net_emerge >= 0.5


# --- body (every peer) ------------------------------------------------------------------------------

## The neck rises in an arc out of the water up to the head; under the surface it is hidden by the
## dark brine.
func _pose() -> void:
	var out: float = net_emerge
	body.visible = out > 0.01
	var swell: float = 1.0 + 0.15 * sin(Time.get_ticks_msec() / 300.0)
	_swirl.scale = Vector3(swell, 0.02, swell)
	if not body.visible:
		return
	var reach: float = net_lunge * 1.6
	var head: Vector3 = Vector3(0.0, -0.8 + 3.4 * out - net_lunge * 1.2, -0.7 * out - reach)
	var bend: Vector3 = Vector3(0.0, 2.6 * out, 0.9)
	var tail: Vector3 = Vector3(0.0, -2.6, 1.6)
	for i: int in _segments.size():
		var t: float = float(i) / float(_segments.size() - 1)
		_segments[i].position = head.lerp(bend, t).lerp(bend.lerp(tail, t), t)
	_head.position = head
	var neck: Vector3 = _segments[1].position
	if head.distance_to(neck) > 0.01:
		_head.look_at(body.to_global(head + (head - neck)), Vector3.UP)


func _build_body() -> void:
	var scales: StandardMaterial3D = BodyParts.rough(Color(0.18, 0.24, 0.24), 0.35, 1.4, 0.2)
	scales.metallic_specular = 0.9
	var belly: StandardMaterial3D = BodyParts.rough(Color(0.5, 0.5, 0.44), 0.4, 0.6)
	var teeth: StandardMaterial3D = BodyParts.rough(Color(0.9, 0.88, 0.8), 0.4, 0.0)
	for i: int in SEGMENTS:
		var radius: float = lerpf(0.62, 0.32, float(i) / float(SEGMENTS - 1))
		_segments.append(BodyParts.add(body, BodyParts.sphere(radius, 16), scales, Vector3.ZERO))
	_head = Node3D.new()
	_head.name = "Head"
	body.add_child(_head)
	# The cat's head of a Tatzelwurm, twice the size, with weed and salt in its whiskers.
	BodyParts.add(_head, BodyParts.sphere(0.75), scales, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.8, 1.15))
	BodyParts.add(_head, BodyParts.box(Vector3(0.8, 0.4, 0.75)), belly, Vector3(0, -0.24, -0.62))
	for x: float in [-0.28, -0.12, 0.0, 0.12, 0.28]:
		BodyParts.add(_head, BodyParts.cylinder(0.0, 0.045, 0.18, 6), teeth, Vector3(x, -0.48, -0.95), Vector3(180, 0, 0))
	var eye: StandardMaterial3D = BodyParts.glow(Color(0.5, 1.0, 0.85), 6.0)
	for side: float in [-1.0, 1.0]:
		BodyParts.add(_head, BodyParts.cylinder(0.0, 0.2, 0.5, 6), scales, Vector3(side * 0.42, 0.62, 0.1), Vector3(0, 0, -side * 22))
		BodyParts.add(_head, BodyParts.sphere(0.11, 10), eye, Vector3(side * 0.32, 0.14, -0.62), Vector3.ZERO, Vector3(1.0, 0.5, 1.0))
		for w: float in [-0.06, 0.06]:
			BodyParts.add(_head, BodyParts.cylinder(0.006, 0.006, 0.8, 4), belly, Vector3(side * 0.62, -0.18 + w, -0.7), Vector3(0, 0, side * 80))
	# The swirl on the black water that gives her away when she is under.
	var swirl_material: StandardMaterial3D = StandardMaterial3D.new()
	swirl_material.albedo_color = Color(0.25, 0.32, 0.32, 0.35)
	swirl_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	swirl_material.roughness = 0.05
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.9
	ring.outer_radius = 1.25
	_swirl = MeshInstance3D.new()
	_swirl.mesh = ring
	_swirl.material_override = swirl_material
	_swirl.position = Vector3(0.0, 0.02, 0.0)
	_swirl.scale = Vector3(1.0, 0.02, 1.0)
	_swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_swirl)
	BodyParts.no_shadows(body)
	_pose()
