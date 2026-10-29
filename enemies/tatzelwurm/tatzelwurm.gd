class_name Tatzelwurm
extends Creature
## The Tatzelwurm (DESIGN.md §6): a cat-headed worm that burrows through the salt. It hunts by
## vibration: sprinting, heavy things hitting the floor, loud voices, carts, bangs (Game.host_noise)
## draw it in. Underground it is only heard – grinding rock – then it bursts out of the floor
## where the noise was and lunges at anything moving close by. Counter: walk slowly (crouch),
## stand still, and it dives away again. Hitting it while it is out makes it dive at once.
## It does not talk; it scrapes and hisses.

enum State { ROAM, HUNT, SURFACE, LUNGE, DIVE, REST }

const UNDERGROUND_DEPTH: float = 1.3
const ARRIVE: float = 0.8
const EMERGE_SECONDS: float = 0.6
const LUNGE_SECONDS: float = 0.5
const SEGMENTS: int = 11

## Synced presentation: how far it is out of the floor (0–1), how far the head is thrown out
## in a lunge (0–1), and whether it is grinding through the rock right now.
var net_emerge: float = 0.0
var net_lunge: float = 0.0
var net_moving: bool = false

var state: State = State.ROAM
var _goal: Vector3
var _state_time: float = 0.0
var _victim: Player
var _bitten: bool = false
var _segments: Array[MeshInstance3D] = []
var _hole: Node3D
var _head: Node3D
var _scrape: MuffledAudio

@onready var body: Node3D = $Body
@onready var shape: CollisionShape3D = $Shape


func _ready() -> void:
	super()
	health = _config.tatzelwurm_health
	collision_mask = 0  # it goes through rock
	if multiplayer.is_server():
		global_position.y -= UNDERGROUND_DEPTH
	_goal = global_position
	_build_body()


func _process(delta: float) -> void:
	super(delta)
	_pose()
	shape.disabled = net_emerge < 0.5
	if net_moving and not _scrape.playing:
		_scrape.play()
	elif not net_moving and _scrape.playing:
		_scrape.stop()


func _halt(_delta: float) -> void:
	velocity = Vector3.ZERO  # no physics: it swims through the rock


func _think(delta: float) -> void:
	_state_time += delta
	match state:
		State.ROAM:
			if _swim_to(_goal, _config.tatzelwurm_roam_speed, delta) or _state_time > 15.0:
				_goal = _underground(far_point(0.0) if randf() < 0.3 else _random_nav_point())
				_state_time = 0.0
		State.HUNT:
			if _swim_to(_goal, _config.tatzelwurm_speed, delta):
				_surface()
			elif _state_time > 20.0:
				_set_state(State.ROAM)
		State.SURFACE:
			net_emerge = minf(1.0, net_emerge + delta / EMERGE_SECONDS)
			_turn_to_nearest(delta)
			var mover: Player = _moving_player_in_reach()
			if mover != null and net_emerge >= 1.0:
				_victim = mover
				_bitten = false
				play_sound.rpc("tatzel_hiss", 2.0)
				_set_state(State.LUNGE)
			elif _state_time > _config.tatzelwurm_surface_seconds:
				_dive()
		State.LUNGE:
			_turn_to(_victim.global_position if is_instance_valid(_victim) else global_position, delta * 3.0)
			net_lunge = sin(clampf(_state_time / LUNGE_SECONDS, 0.0, 1.0) * PI)
			if not _bitten and _state_time > LUNGE_SECONDS * 0.5:
				_bitten = true
				_bite()
			if _state_time > LUNGE_SECONDS:
				net_lunge = 0.0
				_set_state(State.SURFACE)
		State.DIVE:
			net_emerge = maxf(0.0, net_emerge - delta / EMERGE_SECONDS)
			if net_emerge <= 0.0:
				global_position.y -= UNDERGROUND_DEPTH
				_set_state(State.REST)
		State.REST:
			_swim_to(_goal, _config.tatzelwurm_roam_speed, delta)
			if _state_time > _config.tatzelwurm_dive_seconds:
				_set_state(State.ROAM)


## Something shook the rock: if it is listening, it heads there.
func host_heard(where: Vector3, _reach: float) -> void:
	match state:
		State.ROAM, State.HUNT:
			if in_smoke(where):
				return
			_goal = _underground(where)
			_set_state(State.HUNT)
		State.SURFACE:
			if net_emerge < 1.0:
				return
			# Already out: a noise close by gives the noisy one away.
			for player: Player in Game.instance.players():
				if player.alive and player.global_position.distance_to(where) < 1.5 \
						and _flat_distance(player.global_position) < _config.tatzelwurm_lunge_distance:
					_victim = player
					_bitten = false
					_set_state(State.LUNGE)
					return


func host_hit(damage: int, from: Vector3) -> void:
	if net_emerge < 0.5:
		return
	health -= damage
	play_sound.rpc("tatzel_hiss", 3.0)
	if health <= 0:
		# Gone for good, deep into the mountain.
		_farewell.rpc(-1, "tatzel_burst")
		queue_free()
		return
	_turn_to(from, 1.0)
	_dive()


func _surface() -> void:
	var floor_point: Vector3 = _floor_below(global_position + Vector3.UP * UNDERGROUND_DEPTH)
	global_position = floor_point
	net_moving = false
	play_sound.rpc("tatzel_burst", 4.0)
	Game.instance.host_noise(floor_point, _config.noise_landing)
	_set_state(State.SURFACE)


func _dive() -> void:
	net_lunge = 0.0
	play_sound.rpc("tatzel_burst", -2.0)
	_goal = _underground(far_point(10.0))
	_set_state(State.DIVE)


func _bite() -> void:
	play_sound.rpc("tatzel_bite", 4.0)
	if not is_instance_valid(_victim) or not _victim.alive:
		return
	if _flat_distance(_victim.global_position) < _config.tatzelwurm_lunge_distance + 0.6:
		Game.instance.host_damage_player(_victim, _config.tatzelwurm_bite_damage)


## A living player close to the hole who is moving fast enough to be felt (crouching is not).
func _moving_player_in_reach() -> Player:
	for player: Player in Game.instance.players():
		if not player.alive or _flat_distance(player.global_position) > _config.tatzelwurm_lunge_distance:
			continue
		var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
		if speed > _config.tatzelwurm_motion_threshold and not player.crouching:
			return player
	return null


## Straight through the rock, no paths needed. True once there.
func _swim_to(goal: Vector3, speed: float, delta: float) -> bool:
	var to_goal: Vector3 = goal - global_position
	net_moving = to_goal.length() > ARRIVE
	if not net_moving:
		return true
	global_position += to_goal.limit_length(speed * delta)
	_turn_to(goal, delta)
	return false


func _turn_to(point: Vector3, delta: float) -> void:
	var dir: Vector3 = point - global_position
	if Vector2(dir.x, dir.z).length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(4.0 * delta, 0.0, 1.0))


func _turn_to_nearest(delta: float) -> void:
	var best: Player = null
	for player: Player in Game.instance.players():
		if player.alive and (best == null or _flat_distance(player.global_position) < _flat_distance(best.global_position)):
			best = player
	if best != null and _flat_distance(best.global_position) < 12.0:
		_turn_to(best.global_position, delta * 0.5)


func _underground(point: Vector3) -> Vector3:
	return _floor_below(point) - Vector3.UP * UNDERGROUND_DEPTH


func _floor_below(point: Vector3) -> Vector3:
	var from: Vector3 = point + Vector3.UP * 1.0
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 6.0, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		var nav: AStar3D = Game.instance.mine.nav
		return nav.get_point_position(nav.get_closest_point(point))
	return hit.position


func _random_nav_point() -> Vector3:
	var nav: AStar3D = Game.instance.mine.nav
	var ids: PackedInt64Array = nav.get_point_ids()
	return nav.get_point_position(ids[randi() % ids.size()])


func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0


# --- body (every peer) ------------------------------------------------------------------------------

## Lays the segments along an arc from the hole up to the head; below the floor they are hidden
## by the rock itself.
func _pose() -> void:
	var out: float = net_emerge
	body.visible = out > 0.01
	_hole.visible = out > 0.01
	if not body.visible:
		return
	var reach: float = net_lunge * _config.tatzelwurm_lunge_distance * 0.7
	var head: Vector3 = Vector3(0.0, 0.35 + 1.25 * out - net_lunge * 0.5, -0.4 * out - reach)
	var bend: Vector3 = Vector3(0.0, 1.7 * out, 0.5)
	var tail: Vector3 = Vector3(0.0, -2.2, 0.6)
	for i: int in _segments.size():
		var t: float = float(i) / float(_segments.size() - 1)
		var p: Vector3 = head.lerp(bend, t).lerp(bend.lerp(tail, t), t)
		_segments[i].position = p
	_head.position = head
	var neck: Vector3 = _segments[1].position
	if head.distance_to(neck) > 0.01:
		_head.look_at(body.to_global(head + (head - neck)), Vector3.UP)


func _build_body() -> void:
	var scales: StandardMaterial3D = BodyParts.rough(Color(0.36, 0.38, 0.3), 0.55, 1.2, 0.25)
	scales.metallic_specular = 0.7
	var belly: StandardMaterial3D = BodyParts.rough(Color(0.6, 0.55, 0.42), 0.7, 0.6)
	for i: int in SEGMENTS:
		var radius: float = lerpf(0.36, 0.14, float(i) / float(SEGMENTS - 1))
		_segments.append(BodyParts.add(body, BodyParts.sphere(radius, 16), scales, Vector3.ZERO))
	_head = Node3D.new()
	body.add_child(_head)
	# The cat's head: round skull, pointed ears, a broad snout full of teeth, yellow eyes.
	BodyParts.add(_head, BodyParts.sphere(0.4), scales, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.85, 1.1))
	BodyParts.add(_head, BodyParts.box(Vector3(0.42, 0.22, 0.4)), belly, Vector3(0, -0.12, -0.35))
	var teeth: StandardMaterial3D = BodyParts.rough(Color(0.9, 0.88, 0.8), 0.4, 0.0)
	for x: float in [-0.14, -0.05, 0.05, 0.14]:
		BodyParts.add(_head, BodyParts.cylinder(0.0, 0.025, 0.09, 6), teeth, Vector3(x, -0.26, -0.5), Vector3(180, 0, 0))
	var eye: StandardMaterial3D = BodyParts.glow(Color(1.0, 0.8, 0.2), 6.0)
	for side: float in [-1.0, 1.0]:
		BodyParts.add(_head, BodyParts.cylinder(0.0, 0.11, 0.26, 6), scales, Vector3(side * 0.22, 0.34, 0.05), Vector3(0, 0, -side * 20))
		BodyParts.add(_head, BodyParts.sphere(0.06, 10), eye, Vector3(side * 0.17, 0.08, -0.33), Vector3.ZERO, Vector3(1.0, 0.5, 1.0))
		# The two front paws ("Tatzen") that give it its name.
		var paw: MeshInstance3D = BodyParts.add(_head, BodyParts.capsule(0.08, 0.7), scales, Vector3(side * 0.35, -0.55, 0.15), Vector3(20, 0, side * 15))
		for claw: float in [-0.04, 0.0, 0.04]:
			BodyParts.add(paw, BodyParts.cylinder(0.0, 0.015, 0.1, 5), teeth, Vector3(claw, -0.38, -0.05), Vector3(150, 0, 0))
	# The hole it broke out of.
	_hole = Node3D.new()
	add_child(_hole)
	var dark: StandardMaterial3D = BodyParts.rough(Color(0.03, 0.025, 0.02), 1.0, 0.0)
	BodyParts.add(_hole, BodyParts.cylinder(0.85, 0.85, 0.02, 20), dark, Vector3(0, 0.02, 0))
	var rubble: StandardMaterial3D = BodyParts.rough(Color(0.55, 0.52, 0.48), 0.9, 1.0, 0.3)
	for i: int in 9:
		var angle: float = TAU * i / 9.0
		BodyParts.add(_hole, BodyParts.box(Vector3(0.3, 0.18, 0.25)), rubble, Vector3(cos(angle), 0.06, sin(angle)) * 1.05, Vector3(randf() * 40, angle * 57.3, randf() * 40))
	_scrape = MuffledAudio.new()
	_scrape.stream = Audio.stream("tatzel_scrape")
	_scrape.bus = &"Creatures"
	_scrape.max_distance = 28.0
	_scrape.unit_size = 4.0
	_scrape.volume_db = 2.0
	add_child(_scrape)
	_pose()
