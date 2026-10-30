class_name Kasermandl
extends Creature
## The ghost of an old Alm herder (DESIGN.md §6). Only seen in darkness: lit by a lamp or a
## lantern it freezes, falls silent and fades away (the weeping-angel rule). In the dark it creeps
## after the nearest miner, and rushes when their lamp is out. A touch chills you to the bone,
## then it slips back into the dark for a while. Counter: keep a light on it – which is a problem
## in firedamp, where the carbide lamp has to go out.

enum State { STALK, RETREAT }

const STRIKE_DISTANCE: float = 1.3
const LIT_CHECK_SECONDS: float = 0.15
const BREATH_DISTANCE: float = 4.0

## Synced: whether a light is on it right now (every peer fades it out while lit).
var net_lit: bool = false

var state: State = State.STALK
var _target: Player
var _goal_far: Vector3 = Vector3.ZERO
var _strike_left: float = 0.0
var _lit_check_left: float = 0.0
var _spotted: Dictionary = {}
var _materials: Array[StandardMaterial3D] = []
var _alpha: float = 0.0
var _breath_left: float = 0.0

@onready var body: Node3D = $Body


func _ready() -> void:
	super()
	health = 1
	_build_body()


func _process(delta: float) -> void:
	super(delta)
	# Seen only in the dark: fades out under light, back in when it is dark again.
	_alpha = move_toward(_alpha, 0.0 if net_lit else 1.0, delta * (4.0 if net_lit else 0.8))
	for material: StandardMaterial3D in _materials:
		material.albedo_color.a = _alpha * 0.55
	body.visible = _alpha > 0.01
	body.position.y = sin(Time.get_ticks_msec() / 900.0) * 0.05
	_breathe(delta)


## Close by in the dark you hear it breathe before you see it.
func _breathe(delta: float) -> void:
	_breath_left -= delta
	var camera: Camera3D = get_viewport().get_camera_3d()
	if net_lit or _breath_left > 0.0 or camera == null or camera.global_position.distance_to(global_position) > BREATH_DISTANCE:
		return
	_breath_left = randf_range(3.0, 5.0)
	Audio.play_at("kaser_breath", global_position + Vector3.UP * 1.3, &"Creatures", -4.0, 8.0)


func _think(delta: float) -> void:
	_strike_left -= delta
	_lit_check_left -= delta
	if _lit_check_left <= 0.0:
		_lit_check_left = LIT_CHECK_SECONDS
		var lit: bool = _is_lit()
		if lit and not net_lit:
			_hush.rpc()  # silence = your light is on it
		net_lit = lit
	if net_lit:
		_halt(delta)  # frozen
		return
	if randf() < _config.voice_idle_chance * delta:
		say(VoiceLine.Moment.IDLE)
	if state == State.RETREAT:
		if walk_to(_goal_far, _config.kasermandl_rush_speed, delta) or _strike_left <= 0.0:
			state = State.STALK
		return
	_target = _nearest_player()
	if _target == null:
		_halt(delta)
		return
	if not _spotted.has(_target.peer_id) and _target.global_position.distance_to(global_position) < _config.voice_max_distance:
		_spotted[_target.peer_id] = true
		say(VoiceLine.Moment.SPOT)
	var speed: float = _config.kasermandl_rush_speed if _target.light_range() <= 0.0 else _config.kasermandl_creep_speed
	walk_to(_target.global_position, speed, delta)
	if _strike_left <= 0.0 and global_position.distance_to(_target.global_position) < STRIKE_DISTANCE:
		_strike_left = _config.kasermandl_strike_cooldown
		say(VoiceLine.Moment.ACTION, true)
		Game.instance.host_damage_player(_target, scaled_damage(_config.kasermandl_strike_damage))
		_goal_far = far_point(18.0)
		state = State.RETREAT


## Any lamp beam or lantern whose light reaches it (in range and nothing in between).
func _is_lit() -> bool:
	var chest: Vector3 = global_position + Vector3.UP * 0.9
	for player: Player in Game.instance.players():
		# In the beam (or the glow right around the miner), with nothing in between.
		if player.lights_point(chest, _config.kasermandl_lamp_share) and _clear(player.beam.global_position, chest):
			return true
	for light: OmniLight3D in Game.instance.mine.lights:
		if is_instance_valid(light) and light.is_visible_in_tree() and light.global_position.distance_to(chest) < _config.kasermandl_lantern_range \
				and _clear(light.global_position, chest):
			return true
	return false


func _clear(from: Vector3, to: Vector3) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _nearest_player() -> Player:
	var best: Player = null
	var best_distance: float = INF
	for player: Player in Game.instance.players():
		if not player.alive or player.global_position.y > Game.HUB_FLOOR_ABOVE:
			continue
		var distance: float = player.global_position.distance_to(global_position)
		if distance < best_distance:
			best = player
			best_distance = distance
	return best


@rpc("authority", "call_local", "reliable")
func _hush() -> void:
	voice.stop()


func host_hit(_damage: int, _from: Vector3) -> void:
	if not net_lit:
		say(VoiceLine.Moment.HIT, true)  # the pick goes right through it


func _build_body() -> void:
	var cloak: StandardMaterial3D = BodyParts.ghost(Color(0.7, 0.78, 0.72, 0.55), 0.5)
	var skin: StandardMaterial3D = BodyParts.ghost(Color(0.85, 0.88, 0.82, 0.55), 0.8)
	_materials = [cloak, skin]
	# Hunched under a long loden cape, a wide hat, a crooked staff.
	BodyParts.add(body, BodyParts.cylinder(0.16, 0.42, 1.25), cloak, Vector3(0, 0.62, 0), Vector3(-8, 0, 0))
	BodyParts.add(body, BodyParts.sphere(0.15), skin, Vector3(0, 1.32, -0.14))
	BodyParts.add(body, BodyParts.cylinder(0.32, 0.32, 0.03), cloak, Vector3(0, 1.45, -0.14))
	BodyParts.add(body, BodyParts.cylinder(0.11, 0.14, 0.16), cloak, Vector3(0, 1.53, -0.14))
	BodyParts.add(body, BodyParts.cylinder(0.025, 0.025, 1.5), cloak, Vector3(0.32, 0.75, -0.25), Vector3(-6, 0, 4))
	BodyParts.add(body, BodyParts.cylinder(0.02, 0.11, 0.3), skin, Vector3(0, 1.15, -0.25), Vector3(-20, 0, 0))  # beard
	var eye: StandardMaterial3D = BodyParts.glow(Color(0.7, 1.0, 0.85), 4.0)
	_materials.append(eye)
	eye.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for side: float in [-1.0, 1.0]:
		BodyParts.add(body, BodyParts.sphere(0.018, 8), eye, Vector3(side * 0.05, 1.35, -0.27))
	BodyParts.no_shadows(body)
	body.visible = false
