class_name GunView
extends Node3D
## How the weapon in your hands looks and moves (local player only; purely visual). Modelled on
## Berghittn's viewmodel and weapon motion (owner request after the M6 playtest):
## - two gloved hands hold it (right on the grip, left under it or on the forend);
## - it glides between the hip and the eye, where its sights sit on the screen centre;
## - walking bobs it in a figure 8, sprinting lowers and turns it, mouse turns make it trail,
##   strafing leans it, landing dips it – all nearly gone while aiming;
## - every shot kicks it back with the muzzle climbing, blows the pistol's slide back and
##   throws out a casing, with a short muzzle flash;
## - reloads are animated (M6 playtest 3): the pistol is tipped, the magazine drops out and the
##   left hand brings a new one; the Flinte breaks open, the empty hulls fly, the left hand
##   pushes in one shell after the other and it snaps shut;
## - close to a wall the gun is pulled back and lowered instead of sticking into the rock;
## - the Spitzhacke is held in both hands and swung (`swing`);
## - a weapon taken in hand comes up from below (M10), with a rustle of cloth and steel.
## A gun follows this node (WorldItem.follow), the Spitzhacke follows `melee_point`, so everything
## here moves them too.

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
## Reload poses (camera-space offset, degrees pitch/yaw/roll): the pistol tipped so the magazine
## well faces the left hand, the Flinte muzzle down with the open breech towards the eye.
const MAG_RELOAD_OFFSET: Vector3 = Vector3(-0.07, 0.05, 0.06)
const MAG_RELOAD_ROTATION: Vector3 = Vector3(14.0, 10.0, 28.0)
const BREAK_RELOAD_OFFSET: Vector3 = Vector3(-0.08, 0.07, 0.08)
const BREAK_RELOAD_ROTATION: Vector3 = Vector3(-14.0, 12.0, 18.0)
## The Stutzen rolled onto its side, the open action towards the left hand.
const TOP_RELOAD_OFFSET: Vector3 = Vector3(-0.07, 0.06, 0.08)
const TOP_RELOAD_ROTATION: Vector3 = Vector3(6.0, 12.0, 32.0)
## The bolt pulled back (m) and turned up (degrees) when open.
const BOLT_BACK: float = 0.06
const BOLT_TURN: float = 65.0
const RELOAD_POSE_SPEED: float = 7.0
## How far the Flinte's barrels drop when broken open (degrees), and how fast.
const BREAK_ANGLE: float = 34.0
const BREAK_OPEN_SPEED: float = 7.0
const BREAK_CLOSE_SPEED: float = 10.0
## Close to a wall: pulled back and lowered (m, degrees at full), and from how near it starts.
const WALL_OFFSET: Vector3 = Vector3(-0.02, -0.06, 0.12)
const WALL_ROTATION: Vector3 = Vector3(-48.0, 14.0, 0.0)
const WALL_RANGE: float = 0.35
## The Spitzhacke: where the right hand holds it (camera space, relative to the hip point), how
## long a swing takes, and when in it the point strikes (Player waits as long before the hit).
const PICK_HAND: Vector3 = Vector3(0.05, -0.06, 0.08)
const PICK_GRIP: float = 0.08
const PICK_SUPPORT: float = 0.3
## Taking a weapon in hand: from this pose (m, degrees) up to the hip, in DRAW_SECONDS. Only a look:
## the gun can fire at once (a shot cuts the draw short).
const DRAW_OFFSET: Vector3 = Vector3(0.02, -0.16, 0.05)
const DRAW_ROTATION: Vector3 = Vector3(-40.0, 8.0, -14.0)
const DRAW_SECONDS: float = 0.28
const SWING_SECONDS: float = 0.55
const SWING_STRIKE: float = 0.17

var player: Player
## 0 hip … 1 aimed, eased.
var aim_amount: float = 0.0
## The Spitzhacke follows this point (its handle in the hands).
var melee_point: Node3D

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
## A shell in the left hand on its way to the Flinte's breech.
var _hand_shell: Node3D
var _flash: Node3D
var _flash_left: float = 0.0
var _casings: Array[MeshInstance3D] = []
var _casing_velocity: Array[Vector3] = []
var _casing_left: Array[float] = []
var _next_casing: int = 0
var _brass: Mesh
var _brass_material: Material
var _hull: Mesh
var _hull_material: Material
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
## Reload animation: how far the gun is in its reload pose, how far the barrels are open, and
## whether the pistol was empty (then the slide is racked at the end).
var _reload_pose: float = 0.0
var _open: float = 0.0
var _was_reloading: bool = false
var _rack: bool = false
var _left_target: Vector3 = Vector3.ZERO
## Close to a wall, 0..1.
var _wall: float = 0.0
## The weapon last in hand, and how far it still is from being up (1 just taken … 0 up).
var _drawn_item: WorldItem
var _draw: float = 0.0
## Seconds into the current swing of the Spitzhacke (< 0: none).
var _swing_time: float = -1.0


func setup(owner_player: Player) -> void:
	player = owner_player
	name = "GunView"
	position = HIP
	player.camera.add_child(self)
	melee_point = Node3D.new()
	melee_point.name = "MeleePoint"
	add_child(melee_point)
	_build_hands()
	_build_flash()
	_build_casings()


func _unhandled_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look_lag = (_look_lag + motion.screen_relative * LOOK_LAG_PER_PIXEL).limit_length(LOOK_LAG_MAX)


## Whether `item` is held as a melee weapon here (the Spitzhacke), not as a gun.
static func is_melee(item: WorldItem) -> bool:
	return item != null and item.data.weapon == null and item.data.melee_damage > 0 and item.data.slot_kind() == ItemData.SlotKind.WEAPON


## Every frame: where the weapon is, how it moves, the hands on it. `reload` is the progress of
## the current reload step (0..1) while `reloading`.
func update(delta: float, item: WorldItem, aiming: bool, reloading: bool = false, reload: float = 0.0) -> void:
	var weapon: WeaponData = item.data.weapon if item != null else null
	var melee: bool = is_melee(item)
	aim_amount = move_toward(aim_amount, 1.0 if aiming and weapon != null else 0.0, AIM_SPEED * delta)
	var eased_aim: float = smoothstep(0.0, 1.0, aim_amount)
	var aimed: Vector3 = Vector3(0.0, -weapon.sight_height, -weapon.aim_distance) if weapon != null else HIP
	var base: Vector3 = HIP.lerp(aimed, eased_aim)
	_update_motion(delta, eased_aim)
	_tick_draw(delta, item)
	var draw: float = _draw * _draw
	# The kick: back and muzzle up, springing back.
	_kick = maxf(0.0, _kick - delta / maxf(0.01, _kick_time))
	var kick: float = ease(_kick, 0.4)
	var back: float = (_kick_weapon.kick_back if _kick_weapon != null else 0.0) * kick * lerpf(1.0, 0.6, eased_aim)
	var climb: float = deg_to_rad((_kick_weapon.kick_angle if _kick_weapon != null else 0.0) * kick * lerpf(1.0, 0.5, eased_aim))
	# Reload pose and the broken-open barrels.
	var breaks: bool = item != null and item.find_child("Barrels", false, false) != null
	var top: bool = weapon != null and weapon.top_loaded
	if reloading and not _was_reloading and item != null:
		_begin_reload(item, breaks)
	_was_reloading = reloading
	_reload_pose = move_toward(_reload_pose, 1.0 if reloading and weapon != null else 0.0, RELOAD_POSE_SPEED * delta)
	_open = move_toward(_open, 1.0 if reloading and (breaks or top) else 0.0, (BREAK_OPEN_SPEED if reloading else BREAK_CLOSE_SPEED) * delta)
	var pose: float = smoothstep(0.0, 1.0, _reload_pose)
	var pose_offset: Vector3 = (BREAK_RELOAD_OFFSET if breaks else (TOP_RELOAD_OFFSET if top else MAG_RELOAD_OFFSET)) * pose
	var pose_rotation: Vector3 = (BREAK_RELOAD_ROTATION if breaks else (TOP_RELOAD_ROTATION if top else MAG_RELOAD_ROTATION)) * pose
	# Close to a wall: pulled back and lowered.
	var reach: float = -base.z + (-weapon.muzzle.z if weapon != null else 0.45)
	_wall = move_toward(_wall, _wall_share(reach) if item != null else 0.0, 4.0 * delta)
	var wall: float = smoothstep(0.0, 1.0, _wall)
	var turn: Basis = Basis.from_euler(_motion_rotation + Vector3(climb, 0.0, 0.0) + _degrees(pose_rotation + WALL_ROTATION * wall + DRAW_ROTATION * draw))
	var pivot: Vector3 = PIVOT - base
	var offset: Vector3 = _motion_position + Vector3(0.0, 0.0, back) + pose_offset + WALL_OFFSET * wall + DRAW_OFFSET * draw
	transform = Transform3D(Basis.IDENTITY, base + offset + pivot) * Transform3D(turn, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot)
	if item != null and weapon != null:
		if breaks:
			_animate_break(item, reloading, reload)
		elif top:
			_animate_top(item, reloading, reload)
		else:
			_animate_magazine(item, reloading, reload)
	_tick_swing(delta, melee)
	_place_hands(delta, item, weapon, melee)
	_tick_flash(delta)
	_tick_casings(delta)


## A new weapon in hand comes up from below; a shot (the kick) brings it up at once.
func _tick_draw(delta: float, item: WorldItem) -> void:
	if item != _drawn_item:
		_drawn_item = item
		if item != null:
			_draw = 1.0
			Audio.play_at("weapon_draw", player.camera.global_position, &"SFX", -10.0, 6.0, randf_range(0.95, 1.05))
	if _kick > 0.0:
		_draw = 0.0
	_draw = move_toward(_draw, 0.0, delta / DRAW_SECONDS)


## A swing of the Spitzhacke (the hit itself comes SWING_STRIKE s later, from Player).
func swing() -> void:
	_swing_time = 0.0


func _degrees(angles: Vector3) -> Vector3:
	return Vector3(deg_to_rad(angles.x), deg_to_rad(angles.y), deg_to_rad(angles.z))


## How far into a wall the weapon would reach: 0 free … 1 pulled back fully.
func _wall_share(reach: float) -> float:
	var from: Vector3 = player.camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - player.camera.global_basis.z * (reach + 0.05), 1)
	query.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return 0.0
	return clampf((reach + 0.05 - from.distance_to(hit.position)) / WALL_RANGE, 0.0, 1.0)


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
		_eject(item.global_transform * Vector3(0.018, 0.02, -0.02), Vector3(1.8, 1.4, 0.4), false)
	var bolt: Node3D = item.find_child("Bolt", false, false) as Node3D
	if bolt != null and weapon.cycle_sound != "" and item.rounds > 0:
		# Working the bolt: up, back (the case flies out), forward, down.
		var rest: Vector3 = bolt.get_meta(&"rest", bolt.position)
		bolt.set_meta(&"rest", rest)
		var tween: Tween = bolt.create_tween()
		tween.tween_interval(weapon.cycle_delay)
		tween.tween_property(bolt, "rotation:z", deg_to_rad(BOLT_TURN), 0.07)
		tween.tween_property(bolt, "position", rest + Vector3(0.0, 0.0, BOLT_BACK), 0.1)
		tween.tween_callback(func() -> void: _eject(item.global_transform * (rest + Vector3(0.02, 0.012, -0.03)), Vector3(1.6, 1.2, 0.2), false))
		tween.tween_property(bolt, "position", rest, 0.1)
		tween.tween_property(bolt, "rotation:z", 0.0, 0.07)


# --- reloads ---------------------------------------------------------------------------------------

func _begin_reload(item: WorldItem, breaks: bool) -> void:
	_rack = item.rounds == 0
	if breaks:
		# Breaking it open throws out the fired hulls, up and back past the shoulder.
		for i: int in maxi(0, item.data.weapon.magazine - item.rounds):
			var x: float = _chamber(item, i).x
			_eject(item.global_transform * Vector3(x, 0.02, -0.02), Vector3(0.6 + x * 20.0, 1.9, 1.2), true)


## Where chamber `index` of a break-action is (the shell nodes ShellL, ShellR), in the barrels'
## own space.
func _chamber(item: WorldItem, index: int) -> Vector3:
	var shell: Node3D = item.find_child("ShellL" if index == 0 else "ShellR", true, false) as Node3D
	return shell.position if shell != null else Vector3(0.0, 0.028, 0.0)


## Pistol: the magazine slides out, the left hand drops away and comes back with a full one,
## pushes it in; if the gun was empty, the slide is racked.
func _animate_magazine(item: WorldItem, reloading: bool, p: float) -> void:
	var magazine: Node3D = item.find_child("Magazine", false, false) as Node3D
	var support: Vector3 = item.data.weapon.support
	_hand_shell.visible = false
	if magazine == null:
		_left_target = support
		return
	var rest: Vector3 = magazine.get_meta(&"rest", magazine.position)
	magazine.set_meta(&"rest", rest)
	var down: Vector3 = magazine.basis.y.normalized()
	var drop: float = 0.0
	var hand: Vector3 = support
	if reloading:
		if p < 0.06:
			drop = 0.0
		elif p < 0.22:
			drop = remap(p, 0.06, 0.22, 0.0, 0.15)
		elif p < 0.38:
			drop = 0.3  # gone
		elif p < 0.5:
			drop = remap(p, 0.38, 0.5, 0.16, 0.05)
		elif p < 0.58:
			drop = remap(p, 0.5, 0.58, 0.05, 0.0)
		var below_magazine: Vector3 = rest - down * (drop + 0.07) + Vector3(0.0, 0.0, 0.01)
		if p < 0.1:
			hand = support
		elif p < 0.38:
			hand = support + Vector3(-0.03, -0.22, 0.06)
		elif p < 0.62:
			hand = below_magazine
		elif p < 0.85:
			hand = support + Vector3(0.0, -0.01, 0.01)
		if _rack and p > 0.7 and p < 0.86:
			var slide: Node3D = item.find_child("Slide", false, false) as Node3D
			if slide != null:
				var slide_rest: Vector3 = slide.get_meta(&"rest", slide.position)
				slide.set_meta(&"rest", slide_rest)
				slide.position = slide_rest + Vector3(0.0, 0.0, 0.045 * sin(remap(p, 0.7, 0.86, 0.0, PI)))
	magazine.position = rest - down * drop
	magazine.visible = drop < 0.2
	_left_target = hand


## Flinte: the barrels swing down on the hinge; per shell the left hand goes down to the
## cartridge belt and comes back to push one into the breech. Loaded shells show in the open
## chambers.
func _animate_break(item: WorldItem, reloading: bool, p: float) -> void:
	var barrels: Node3D = item.find_child("Barrels", false, false) as Node3D
	var support: Vector3 = item.data.weapon.support
	barrels.rotation.x = -deg_to_rad(BREAK_ANGLE) * smoothstep(0.0, 1.0, _open)
	var shown: int = item.rounds + (1 if reloading and p > 0.82 else 0)
	for i: int in 2:
		var shell: Node3D = barrels.get_node_or_null("ShellL" if i == 0 else "ShellR") as Node3D
		if shell != null:
			shell.visible = _open > 0.05 and i < shown
	_hand_shell.visible = false
	if not reloading:
		_left_target = support
		return
	# The chamber that gets this shell, in the gun's space: its mouth and a bit behind it.
	var chamber: Vector3 = _chamber(item, mini(item.rounds, 1))
	var mouth: Vector3 = barrels.transform * Vector3(chamber.x, chamber.y, 0.0)
	var behind: Vector3 = mouth + barrels.basis * Vector3(0.0, 0.0, 0.07)
	var belt: Vector3 = support + Vector3(-0.04, -0.24, 0.16)
	if p < 0.2:
		_left_target = belt
	elif p < 0.4:
		_left_target = belt
		_hand_shell.visible = true
	elif p < 0.82:
		_left_target = behind + Vector3(-0.02, -0.035, 0.0) if p < 0.65 else mouth + Vector3(-0.02, -0.035, 0.03)
		_hand_shell.visible = p < 0.8
	else:
		_left_target = mouth + Vector3(-0.03, -0.05, 0.06)


## Stutzen: the bolt is up and back for the whole reload; per round the left hand goes down to
## the cartridge pouch and comes back over the open action to press one in from above.
func _animate_top(item: WorldItem, reloading: bool, p: float) -> void:
	var support: Vector3 = item.data.weapon.support
	_hand_shell.visible = false
	var bolt: Node3D = item.find_child("Bolt", false, false) as Node3D
	if bolt != null:
		var rest: Vector3 = bolt.get_meta(&"rest", bolt.position)
		bolt.set_meta(&"rest", rest)
		var open: float = smoothstep(0.0, 1.0, _open)
		if reloading or _open > 0.0:
			bolt.position = rest + Vector3(0.0, 0.0, BOLT_BACK * open)
			bolt.rotation.z = deg_to_rad(BOLT_TURN) * minf(1.0, open * 1.5)
	if not reloading:
		_left_target = support
		return
	var port: Vector3 = (bolt.get_meta(&"rest", bolt.position) as Vector3) + Vector3(-0.01, 0.03, -0.04) if bolt != null else Vector3(0.0, 0.04, 0.0)
	var pouch: Vector3 = support + Vector3(-0.05, -0.2, 0.25)
	if p < 0.25:
		_left_target = pouch
	elif p < 0.45:
		_left_target = pouch
		_hand_shell.visible = true
	elif p < 0.8:
		_left_target = port + Vector3(0.0, 0.03 * (1.0 - remap(p, 0.45, 0.8, 0.0, 1.0)), 0.0)
		_hand_shell.visible = p < 0.75
	else:
		_left_target = port + Vector3(-0.02, 0.02, 0.03)


# --- the Spitzhacke ----------------------------------------------------------------------------------

## The pick in both hands: resting up on the right shoulder side, a swing winds back, then
## brings the point down in front.
func _tick_swing(delta: float, melee: bool) -> void:
	if _swing_time >= 0.0:
		_swing_time += delta
		if _swing_time >= SWING_SECONDS:
			_swing_time = -1.0
	if not melee:
		return
	var t: float = _swing_time
	var pitch: float = -35.0
	var shift: Vector3 = Vector3.ZERO
	if t >= 0.0:
		if t < SWING_STRIKE - 0.05:
			var k: float = smoothstep(0.0, 1.0, t / (SWING_STRIKE - 0.05))
			pitch = lerpf(-35.0, 5.0, k)
			shift = Vector3(0.0, 0.03, 0.06) * k
		elif t < SWING_STRIKE + 0.05:
			var k: float = clampf((t - SWING_STRIKE + 0.05) / 0.1, 0.0, 1.0)
			pitch = lerpf(5.0, -100.0, k)
			shift = Vector3(0.0, 0.03, 0.06).lerp(Vector3(-0.12, -0.02, -0.12), k)
		else:
			var k: float = smoothstep(0.0, 1.0, (t - SWING_STRIKE - 0.05) / (SWING_SECONDS - SWING_STRIKE - 0.05))
			pitch = lerpf(-100.0, -35.0, k)
			shift = Vector3(-0.12, -0.02, -0.12).lerp(Vector3.ZERO, k)
	var held: Basis = Basis.from_euler(_degrees(Vector3(pitch, 40.0, 14.0)))
	melee_point.transform = Transform3D(held, PICK_HAND + shift) * Transform3D(Basis.IDENTITY, Vector3(0.0, -PICK_GRIP, 0.0))


# --- hands, flash, casings ------------------------------------------------------------------------

func _build_hands() -> void:
	_hands = Node3D.new()
	_hands.name = "Hands"
	add_child(_hands)
	var glove: StandardMaterial3D = BodyParts.rough(Color(0.13, 0.09, 0.06), 0.7, 0.4, 0.25)
	var sleeve: StandardMaterial3D = BodyParts.rough(Color(0.07, 0.07, 0.065), 0.95, 0.5, 0.15)
	_right_hand = _hand(glove, sleeve, 1.0)
	_left_hand = _hand(glove, sleeve, -1.0)
	var hull: StandardMaterial3D = StandardMaterial3D.new()
	hull.albedo_color = Color(0.55, 0.08, 0.06)
	hull.roughness = 0.6
	_hand_shell = Node3D.new()
	_left_hand.add_child(_hand_shell)
	var shell: MeshInstance3D = BodyParts.add(_hand_shell, BodyParts.cylinder(0.0105, 0.0105, 0.065, 10), hull, Vector3(0.022, 0.032, -0.02), Vector3(-90.0, 0.0, 0.0))
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hand_shell.visible = false
	_hands.visible = false


## A gloved fist with its forearm reaching back towards the lower corner of the view on its side
## (side 1 right, -1 left), so the arms frame the gun like in other shooters.
func _hand(glove: Material, sleeve: Material, side: float) -> Node3D:
	var hand: Node3D = Node3D.new()
	_hands.add_child(hand)
	BodyParts.add(hand, BodyParts.box(Vector3(0.04, 0.05, 0.06)), glove, Vector3(0.0, -0.004, 0.008))  # back of the hand
	BodyParts.add(hand, BodyParts.capsule(0.022, 0.07), glove, Vector3(0.0, 0.008, -0.022), Vector3(0, 0, 90))  # curled fingers
	BodyParts.add(hand, BodyParts.capsule(0.012, 0.05), glove, Vector3(-side * 0.024, 0.016, -0.012), Vector3(70, 0, 0))  # thumb
	var arm: Vector3 = Vector3(side * 0.32, -0.72, 0.62).normalized()
	var length: float = 0.36
	BodyParts.add(hand, BodyParts.cylinder(0.03, 0.036, length, 10), sleeve, Vector3.ZERO).transform = _along(arm, arm * (0.035 + length / 2.0))
	BodyParts.add(hand, BodyParts.cylinder(0.031, 0.031, 0.03, 10), sleeve, Vector3.ZERO).transform = _along(arm, arm * 0.035)  # cuff
	BodyParts.no_shadows(hand)
	for node: Node in hand.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).layers = 1
	return hand


## A transform that lays a mesh's Y axis along `direction`, centred at `at`.
func _along(direction: Vector3, at: Vector3) -> Transform3D:
	var y: Vector3 = direction.normalized()
	var x: Vector3 = y.cross(Vector3.FORWARD).normalized()
	return Transform3D(Basis(x, y, x.cross(y)), at)


func _place_hands(delta: float, item: WorldItem, weapon: WeaponData, melee: bool) -> void:
	_hands.visible = (weapon != null or melee) and player.alive
	if not _hands.visible:
		return
	if melee:
		# Both fists around the handle, the right one low, the left one higher up.
		var handle: Transform3D = melee_point.transform
		_right_hand.transform = Transform3D(handle.basis * Basis.from_euler(_degrees(Vector3(90.0, 0.0, 0.0))), handle * Vector3(0.0, PICK_GRIP, 0.0))
		_left_hand.transform = Transform3D(handle.basis * Basis.from_euler(_degrees(Vector3(90.0, 0.0, 0.0))), handle * Vector3(0.0, PICK_SUPPORT, 0.0))
		_hand_shell.visible = false
		return
	_right_hand.position = weapon.grip
	_right_hand.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
	_left_hand.rotation_degrees = Vector3(-6.0, 0.0, 12.0)
	# The left hand moves with the reload (_left_target), quickly but never in a jump.
	var weight: float = 1.0 if _reload_pose <= 0.0 and _open <= 0.0 else minf(18.0 * delta, 1.0)
	_left_hand.position = _left_hand.position.lerp(_left_target if _left_target != Vector3.ZERO else weapon.support, weight)


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
	_brass = BodyParts.cylinder(0.0045, 0.0045, 0.018, 6)
	var brass: StandardMaterial3D = StandardMaterial3D.new()
	brass.albedo_color = Color(0.8, 0.62, 0.25)
	brass.metallic = 0.85
	brass.roughness = 0.35
	_brass_material = brass
	_hull = BodyParts.cylinder(0.0105, 0.0105, 0.065, 10)
	var hull: StandardMaterial3D = StandardMaterial3D.new()
	hull.albedo_color = Color(0.55, 0.08, 0.06)
	hull.roughness = 0.6
	_hull_material = hull
	for i: int in CASINGS:
		var casing: MeshInstance3D = MeshInstance3D.new()
		casing.top_level = true
		casing.visible = false
		casing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(casing)
		_casings.append(casing)
		_casing_velocity.append(Vector3.ZERO)
		_casing_left.append(0.0)


## Throws out a casing (or an empty shotgun hull) at `from`, with `speed` in camera space.
func _eject(from: Vector3, speed: Vector3, hull: bool) -> void:
	var i: int = _next_casing
	_next_casing = (_next_casing + 1) % _casings.size()
	var camera_basis: Basis = player.camera.global_basis
	_casings[i].mesh = _hull if hull else _brass
	_casings[i].material_override = _hull_material if hull else _brass_material
	_casings[i].global_transform = Transform3D(camera_basis, from)
	var jitter: Vector3 = Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.2, 0.2))
	_casing_velocity[i] = camera_basis * (speed + jitter) + player.velocity
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
