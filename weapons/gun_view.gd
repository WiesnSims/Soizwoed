class_name GunView
extends Node3D
## How the gun in your hands looks and moves (local player only; purely visual). Modelled on
## Berghittn's viewmodel and weapon motion (owner request after the M6 playtest):
## - two gloved hands hold it (right on the grip, left under it or on the forend);
## - it glides between the hip and the eye, where its sights sit on the screen centre;
## - walking bobs it in a figure 8, sprinting lowers and turns it, mouse turns make it trail,
##   strafing leans it, landing dips it – all nearly gone while aiming;
## - every shot kicks it back with the muzzle climbing, blows the pistol's slide back and
##   throws out a casing, with a short muzzle flash.
## The gun item follows this node (WorldItem.follow), so everything here moves the gun too.

## From the hip: low on the right, pointing where you look.
const HIP: Vector3 = Vector3(0.17, -0.17, -0.46)
## Bob at walking speed (m), and cycles per second (one cycle = two steps).
const BOB_SIDE: float = 0.012
const BOB_UP: float = 0.009
const BOB_FREQUENCY: float = 0.95
## Sprint pose (m and degrees: pitch down, yaw in, roll).
const SPRINT_OFFSET: Vector3 = Vector3(-0.03, -0.07, 0.03)
const SPRINT_ROTATION: Vector3 = Vector3(-18.0, 28.0, -12.0)
## Trailing mouse turns: degrees per pixel, most, catch-up speed.
const LOOK_LAG_PER_PIXEL: float = 0.04
const LOOK_LAG_MAX: float = 4.0
const LOOK_LAG_RECOVER: float = 10.0
const STRAFE_ROLL: float = 3.0
const LAND_DIP_PER_SPEED: float = 0.008
const LAND_DIP_MAX: float = 0.05
const SMOOTHING: float = 12.0
## Where turns happen around (camera space): about the hand, so turning never swings the gun away.
const PIVOT: Vector3 = Vector3(0.15, -0.16, -0.4)
const AIM_SPEED: float = 7.0
const FLASH_SECONDS: float = 0.05
const CASINGS: int = 8
const CASING_SECONDS: float = 0.7

var player: Player
## 0 hip … 1 aimed, eased.
var aim_amount: float = 0.0

var _bob_phase: float = 0.0
var _bob_amount: float = 0.0
var _sprint: float = 0.0
var _look_lag: Vector2 = Vector2.ZERO
var _land_dip: float = 0.0
var _was_on_floor: bool = true
var _fall_speed: float = 0.0
var _motion_position: Vector3 = Vector3.ZERO
var _motion_rotation: Vector3 = Vector3.ZERO
## The current shot's kick (1 at the shot, falling to 0) and how long it lasts.
var _kick: float = 0.0
var _kick_time: float = 0.12
var _kick_weapon: WeaponData
var _hands: Node3D
var _right_hand: Node3D
var _left_hand: Node3D
var _hands_for: WeaponData
var _flash: Node3D
var _flash_left: float = 0.0
var _casings: Array[MeshInstance3D] = []
var _casing_velocity: Array[Vector3] = []
var _casing_left: Array[float] = []
var _next_casing: int = 0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func setup(owner_player: Player) -> void:
	player = owner_player
	name = "GunView"
	position = HIP
	player.camera.add_child(self)
	_build_hands()
	_build_flash()
	_build_casings()


func _unhandled_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look_lag = (_look_lag + motion.screen_relative * LOOK_LAG_PER_PIXEL).limit_length(LOOK_LAG_MAX)


## Every frame: where the gun is, how it moves, the hands on it.
func update(delta: float, item: WorldItem, aiming: bool) -> void:
	var weapon: WeaponData = item.data.weapon if item != null else null
	aim_amount = move_toward(aim_amount, 1.0 if aiming and weapon != null else 0.0, AIM_SPEED * delta)
	var eased_aim: float = smoothstep(0.0, 1.0, aim_amount)
	var aimed: Vector3 = Vector3(0.0, -weapon.sight_height, -weapon.aim_distance) if weapon != null else HIP
	var base: Vector3 = HIP.lerp(aimed, eased_aim)
	_update_motion(delta, eased_aim)
	# The kick: back and muzzle up, springing back.
	_kick = maxf(0.0, _kick - delta / maxf(0.01, _kick_time))
	var kick: float = ease(_kick, 0.4)
	var back: float = (_kick_weapon.kick_back if _kick_weapon != null else 0.0) * kick * lerpf(1.0, 0.6, eased_aim)
	var climb: float = deg_to_rad((_kick_weapon.kick_angle if _kick_weapon != null else 0.0) * kick * lerpf(1.0, 0.5, eased_aim))
	var turn: Basis = Basis.from_euler(_motion_rotation + Vector3(climb, 0.0, 0.0))
	var pivot: Vector3 = PIVOT - base
	transform = Transform3D(Basis.IDENTITY, base + _motion_position + Vector3(0.0, 0.0, back) + pivot) * Transform3D(turn, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot)
	_place_hands(weapon)
	_tick_flash(delta)
	_tick_casings(delta)


func _update_motion(delta: float, eased_aim: float) -> void:
	var velocity: Vector3 = player.velocity
	var local: Vector3 = player.global_basis.inverse() * velocity
	var flat_speed: float = Vector2(velocity.x, velocity.z).length()
	var on_floor: bool = player.is_on_floor()
	var walk: float = Balance.config.walk_speed
	var walk_share: float = flat_speed / walk if on_floor else 0.0
	_bob_amount = move_toward(_bob_amount, minf(walk_share, 1.6), 6.0 * delta)
	_bob_phase = fmod(_bob_phase + sqrt(walk_share) * BOB_FREQUENCY * TAU * delta, TAU)
	var sprinting: bool = flat_speed > walk * 1.25 and on_floor and eased_aim < 0.1
	_sprint = move_toward(_sprint, 1.0 if sprinting else 0.0, 5.0 * delta)
	if on_floor and not _was_on_floor:
		_land_dip = minf(_fall_speed * LAND_DIP_PER_SPEED, LAND_DIP_MAX)
	_was_on_floor = on_floor
	_fall_speed = maxf(-velocity.y, 0.0)
	_land_dip = lerpf(_land_dip, 0.0, minf(8.0 * delta, 1.0))
	_look_lag = _look_lag.lerp(Vector2.ZERO, minf(LOOK_LAG_RECOVER * delta, 1.0))
	# Aimed, the gun is held tight to the eye: barely any bob, lag or lean.
	var loose: float = 1.0 - 0.85 * eased_aim
	var bob: Vector3 = Vector3(sin(_bob_phase) * BOB_SIDE, -absf(cos(_bob_phase)) * BOB_UP, 0.0) * _bob_amount * loose
	var sprint: float = smoothstep(0.0, 1.0, _sprint)
	var target_position: Vector3 = bob + SPRINT_OFFSET * sprint + Vector3(0.0, -_land_dip, 0.0)
	var target_rotation: Vector3 = Vector3(
			deg_to_rad(SPRINT_ROTATION.x * sprint + _look_lag.y * loose),
			deg_to_rad(SPRINT_ROTATION.y * sprint + _look_lag.x * loose),
			deg_to_rad(SPRINT_ROTATION.z * sprint - local.x / walk * STRAFE_ROLL * loose))
	var weight: float = minf(SMOOTHING * delta, 1.0)
	_motion_position = _motion_position.lerp(target_position, weight)
	_motion_rotation = _motion_rotation.lerp(target_rotation, weight)


## A shot: kick, flash, the slide blows back and a casing flies (guns that eject).
func fire(item: WorldItem) -> void:
	var weapon: WeaponData = item.data.weapon
	_kick_weapon = weapon
	_kick_time = weapon.kick_time
	_kick = 1.0
	_flash.position = weapon.muzzle
	_flash.rotation.z = randf() * TAU
	_flash.scale = Vector3.ONE * lerpf(1.0, 0.45, aim_amount) * weapon.flash_size
	_flash.visible = true
	_flash_left = FLASH_SECONDS
	var slide: Node3D = item.find_child("Slide", false, false) as Node3D
	if slide != null:
		var rest: Vector3 = slide.get_meta(&"rest", slide.position)
		slide.set_meta(&"rest", rest)
		var tween: Tween = slide.create_tween()
		slide.position = rest + Vector3(0.0, 0.0, 0.045)
		tween.tween_property(slide, "position", rest, weapon.kick_time * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if weapon.ejects_casing:
		_eject(item)


func _build_hands() -> void:
	_hands = Node3D.new()
	_hands.name = "Hands"
	add_child(_hands)
	var glove: StandardMaterial3D = BodyParts.rough(Color(0.13, 0.09, 0.06), 0.7, 0.4, 0.25)
	var sleeve: StandardMaterial3D = BodyParts.rough(Color(0.07, 0.07, 0.065), 0.95, 0.5, 0.15)
	_right_hand = _hand(glove, sleeve, 1.0)
	_left_hand = _hand(glove, sleeve, -1.0)
	_hands.visible = false


## A gloved fist with its forearm reaching back and down out of view (side 1 right, -1 left).
func _hand(glove: Material, sleeve: Material, side: float) -> Node3D:
	var hand: Node3D = Node3D.new()
	_hands.add_child(hand)
	BodyParts.add(hand, BodyParts.box(Vector3(0.045, 0.06, 0.075)), glove, Vector3.ZERO)
	BodyParts.add(hand, BodyParts.capsule(0.013, 0.05), glove, Vector3(-side * 0.026, 0.012, -0.025), Vector3(70, 0, 0))  # thumb
	# The forearm goes down and back, out of the bottom of the view (not towards the eye).
	BodyParts.add(hand, BodyParts.cylinder(0.026, 0.032, 0.26, 10), sleeve, Vector3(side * 0.035, -0.13, 0.07), Vector3(-25, side * -15, 0))
	BodyParts.add(hand, BodyParts.cylinder(0.031, 0.031, 0.025, 10), sleeve, Vector3(side * 0.008, -0.03, 0.02), Vector3(-25, side * -15, 0))  # cuff
	BodyParts.no_shadows(hand)
	for node: Node in hand.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).layers = 1
	return hand


func _place_hands(weapon: WeaponData) -> void:
	_hands.visible = weapon != null and player.alive
	if weapon == null or weapon == _hands_for:
		return
	_hands_for = weapon
	_right_hand.position = weapon.grip
	_right_hand.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
	_left_hand.position = weapon.support
	_left_hand.rotation_degrees = Vector3(-6.0, 0.0, 12.0)


func _build_flash() -> void:
	_flash = Node3D.new()
	_flash.name = "MuzzleFlash"
	add_child(_flash)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(1.0, 0.72, 0.35, 0.9)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for angle: float in [0.0, 60.0, 120.0]:
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(0.14, 0.035)
		var petal: MeshInstance3D = BodyParts.add(_flash, quad, material, Vector3(0.0, 0.0, -0.02), Vector3(0.0, 0.0, angle))
		petal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var core: QuadMesh = QuadMesh.new()
	core.size = Vector2(0.06, 0.06)
	BodyParts.add(_flash, core, material, Vector3.ZERO).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false


func _tick_flash(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		_flash.visible = _flash_left > 0.0


func _build_casings() -> void:
	var mesh: CylinderMesh = BodyParts.cylinder(0.0045, 0.0045, 0.018, 6)
	var brass: StandardMaterial3D = StandardMaterial3D.new()
	brass.albedo_color = Color(0.8, 0.62, 0.25)
	brass.metallic = 0.85
	brass.roughness = 0.35
	for i: int in CASINGS:
		var casing: MeshInstance3D = MeshInstance3D.new()
		casing.mesh = mesh
		casing.material_override = brass
		casing.top_level = true
		casing.visible = false
		casing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(casing)
		_casings.append(casing)
		_casing_velocity.append(Vector3.ZERO)
		_casing_left.append(0.0)


func _eject(item: WorldItem) -> void:
	var i: int = _next_casing
	_next_casing = (_next_casing + 1) % _casings.size()
	var camera_basis: Basis = player.camera.global_basis
	_casings[i].global_transform = Transform3D(camera_basis, item.global_transform * Vector3(0.018, 0.02, -0.02))
	var jitter: Vector3 = Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.2, 0.2))
	_casing_velocity[i] = camera_basis * (Vector3(1.8, 1.4, 0.4) + jitter) + player.velocity
	_casing_left[i] = CASING_SECONDS
	_casings[i].visible = true


func _tick_casings(delta: float) -> void:
	for i: int in _casings.size():
		if _casing_left[i] <= 0.0:
			continue
		_casing_left[i] -= delta
		_casing_velocity[i].y -= _gravity * delta
		_casings[i].global_position += _casing_velocity[i] * delta
		_casings[i].rotate_object_local(Vector3.RIGHT, 25.0 * delta)
		_casings[i].visible = _casing_left[i] > 0.0
