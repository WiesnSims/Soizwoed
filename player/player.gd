class_name Player
extends CharacterBody3D
## First-person miner. Each player owns its own movement (client-authoritative, see
## DESIGN.md §11); everything that changes the world (items, hits, shouts) is a request to
## the host through Game. Solo is the same code with the local player being the host.
## Other peers see this player through the Sync node (`net_*` values, about 20 Hz) and show
## it smoothed by a NetInterpolator. Health and death belong to the host.

signal inventory_changed

const MOUSE_SENSITIVITY: float = 0.0022
const ACCEL_GROUND: float = 12.0
const ACCEL_AIR: float = 2.5
const STAND_HEAD: float = 1.62
const CROUCH_HEAD: float = 1.0
const STAND_HEIGHT: float = 1.75
const CROUCH_HEIGHT: float = 1.15
## Stride length grows with speed (metres per step): about two steps a second walking.
const STRIDE_MIN: float = 1.2
const STRIDE_MAX: float = 2.4
const STRIDE_PER_SPEED: float = 0.25
const BOB_AMOUNT: float = 0.03
const MELEE_DISTANCE: float = 2.2
## After dying you lie on the floor for this long, then watch a living teammate.
const DEATH_VIEW_SECONDS: float = 2.5
## Another player's name shows when you look at them from this close.
const NAMEPLATE_DISTANCE: float = 10.0
## Swimming, the feet hang this far under the surface (the head stays above it).
const SWIM_DEPTH: float = 1.35
## Downed, the eyes are this close to the floor.
const DOWNED_HEAD: float = 0.45

var peer_id: int = 1
## 1..4 in order of joining, for the name other players see ("Kumpl 2").
var player_number: int = 1
## The Steam name ("" without Steam, then "Kumpl N" is shown). Set by the host at spawn.
var steam_name: String = ""
## Proximity voice (Steam sessions only), else null.
var voice_chat: VoiceChat
## Spare ammo per type (the owner's counters; DESIGN.md §3: ammo takes no pocket slot).
var ammo: Dictionary = {}
## Shooting, aiming, reloading (local player only, else null).
var gunner: Gunner
## The owner lets the Salzweibl copy their voice (setting; the host keeps snippets only then).
var voice_lure_ok: bool = true
var inventory: Inventory
var health: int = 100
var stamina: float = 1.0
var lamp_fuel: float = 0.0
var lamp_on: bool = true:
	set(value):
		lamp_on = value
		if is_node_ready():
			_update_lamp()
## Wearing the Elektrische Stirnlampe instead of the carbide lamp: no flame, a battery.
var lamp_electric: bool = false:
	set(value):
		lamp_electric = value
		if is_node_ready():
			_update_lamp()
## Seconds of Stirnlampe battery left (charged in the Gasthaus before every shift).
var battery: float = 0.0
## Wading through brine right now (set by brine pools, local player only).
var in_brine: bool = false
## On a ladder or rope right now (local player).
var climbing: bool = false
## 0..1: how hard the carbide flame flares near firedamp (set by Hazards on every peer).
var gas_flare: float = 0.0
## The Salzsee lake you are swimming in (null on dry land).
var swim_lake: Lake
var crouching: bool = false
## At 0 health in co-op: down but not out, until a teammate helps up or it is too late (§3).
var downed: bool = false
var _downed_at: float = 0.0
var input_enabled: bool = true
## False after dying, until the next ride (host-authoritative).
var alive: bool = true
## Synced from the owner to every other peer (Sync node).
var net_position: Vector3 = Vector3.ZERO
var net_angles: Vector2 = Vector2.ZERO  # body yaw, head pitch
var net_slot: int = 0:
	set(value):
		net_slot = value
		if inventory != null and is_inside_tree() and not is_local() and inventory.selected != value:
			inventory.select(value)
## Local player while dead: the teammate whose eyes we look through (null: our own body).
var spectating: Player
## The interactable under the crosshair (local player only).
var focus: Node
## 0..1 progress of a held interaction (local player only).
var hold_progress: float = 0.0
## 0..1 progress of eating a Leberkässemmel (local player only, 0 when not eating).
var use_progress: float = 0.0

var _config: BalanceConfig
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _step_accum: float = 0.0
var _bob_phase: float = 0.0
var _head_height: float = STAND_HEAD
var _shout_cooldown: float = 0.0
var _use_cooldown: float = 0.0
var _hold_target: Node
var _hold_time: float = 0.0
var _net: NetInterpolator = NetInterpolator.new()
## After a teleport, snapshots from the old place may still be on the way: ignore them.
var _teleported_to: Vector3 = Vector3.INF
var _teleport_ignore_until: float = 0.0
var _dead_time: float = 0.0
var _nameplate: Label3D
var _alphorn_cooldown: float = 0.0
## The Leberkässemmel being eaten and the seconds of chewing left.
var _eating: WorldItem
var _eating_left: float = 0.0
## Obstler: seconds of wobbly view left, and the wobble's clock.
var _wobble_left: float = 0.0
var _wobble_time: float = 0.0
var _carbide_color: Color
## The Funkgerät's speaker (local player, made on first use) and when its crackle stops.
var _radio: AudioStreamPlayer
var _radio_until: float = 0.0
var _climbables: Array[Climbable] = []
var _climb_ignore_until: float = 0.0
var _pushed_cart: RailCart
## Camera shake from blasts and rockfalls (local player), 0..1, dies down by itself.
var _shake: float = 0.0
## Seconds climbing a rotten ladder with a heavy load, and until the next creak.
var _rotten_strain: float = 0.0
var _creak_left: float = 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
## The lamp: a beam where you look (with shadows) and a weak glow around you (without).
@onready var lamp: OmniLight3D = $Head/Lamp
@onready var beam: SpotLight3D = $Head/Camera/Beam
@onready var _lamp_flame: FlickerLight = $Head/Lamp as FlickerLight
@onready var _beam_flame: FlickerLight = $Head/Camera/Beam as FlickerLight
@onready var lamp_sound: AudioStreamPlayer3D = $Head/Lamp/Hiss
@onready var hold_point: Node3D = $Head/Camera/HoldPoint
@onready var hand_point: Node3D = $Head/Camera/HandPoint
@onready var cart_point: Node3D = $CartPoint
@onready var ray: RayCast3D = $Head/Camera/InteractRay
@onready var footsteps: AudioStreamPlayer3D = $Footsteps
@onready var voice: AudioStreamPlayer3D = $Head/Voice
@onready var shape: CollisionShape3D = $Shape
@onready var body_mesh: Node3D = $Body
@onready var sync: MultiplayerSynchronizer = $Sync


func _enter_tree() -> void:
	set_multiplayer_authority(peer_id)


func _ready() -> void:
	add_to_group(&"players")
	_config = Balance.config
	inventory = Inventory.new(_config.inventory_slots)
	inventory.changed.connect(_on_inventory_changed)
	health = _config.player_max_health
	lamp_fuel = _config.lamp_fuel_seconds
	battery = _config.stirnlampe_battery_seconds
	ray.target_position = Vector3(0, 0, -_config.interact_distance)
	ray.add_exception(self)
	_carbide_color = lamp.light_color
	var local: bool = is_local()
	camera.current = local
	body_mesh.visible = not local
	if local and not Game.dev_quiet:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if local:
		gunner = Gunner.new()
		gunner.name = "Gunner"
		add_child(gunner)
		lamp.light_volumetric_fog_energy = 0.0
		beam.light_volumetric_fog_energy = 0.0
		_on_settings_changed()
		Settings.changed.connect(_on_settings_changed)
	if NetworkManager.voice_enabled():
		voice_chat = VoiceChat.new()
		voice_chat.name = "VoiceChat"
		add_child(voice_chat)
	if not local:
		_build_nameplate()
		_right_arm()  # both arms, for others to see
		sync.synchronized.connect(_on_synchronized)
		inventory.select(net_slot)
	_update_lamp()


func _exit_tree() -> void:
	lamp_sound.stop()


func _on_settings_changed() -> void:
	camera.fov = Settings.data.fov
	if voice_lure_ok != Settings.data.voice_lure:
		_set_voice_lure_ok.rpc_id(1, Settings.data.voice_lure)  # only the host keeps snippets


@rpc("authority", "call_local", "reliable")
func _set_voice_lure_ok(allowed: bool) -> void:
	voice_lure_ok = allowed
	if not allowed and VoiceChat.snippets.has(peer_id):
		VoiceChat.snippets.erase(peer_id)  # what was kept is forgotten too


## On the ground, on every peer: remote players are not moved by physics here, so their
## smoothed vertical speed decides.
func is_on_floor_now() -> bool:
	return is_on_floor() if is_local() else absf(velocity.y) < 1.0


func is_local() -> bool:
	return peer_id == multiplayer.get_unique_id()


func game() -> Game:
	return Game.instance


func _unhandled_input(event: InputEvent) -> void:
	if not is_local() or not input_enabled:
		return
	if not alive:
		if event.is_action_pressed(&"use") or event.is_action_pressed(&"slot_next"):
			spectate_next(1)
		elif event.is_action_pressed(&"slot_prev"):
			spectate_next(-1)
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event
		var sensitivity: float = MOUSE_SENSITIVITY * Settings.data.mouse_sensitivity
		var pitch: float = motion.relative.y * sensitivity * (-1.0 if Settings.data.invert_y else 1.0)
		rotate_y(-motion.relative.x * sensitivity)
		head.rotation.x = clampf(head.rotation.x - pitch, deg_to_rad(-85), deg_to_rad(85))
	elif event.is_action_pressed(&"lamp"):
		_toggle_lamp()
	elif event.is_action_pressed(&"drop"):
		_drop_active()
	elif event.is_action_pressed(&"use"):
		_use_active()
	elif downed:
		return  # down: crawl, look, shoot the pistol – nothing else
	elif event.is_action_pressed(&"shout"):
		_shout()
	elif event.is_action_pressed(&"emote_jodler"):
		game().request_emote.rpc_id(1, Emote.JODLER)
	elif event.is_action_pressed(&"emote_wave"):
		game().request_emote.rpc_id(1, Emote.WAVE)
	elif event.is_action_pressed(&"emote_point"):
		game().request_emote.rpc_id(1, Emote.POINT)
	elif event.is_action_pressed(&"slot_next"):
		inventory.select(inventory.selected + 1)
	elif event.is_action_pressed(&"slot_prev"):
		inventory.select(inventory.selected - 1)
	else:
		for i: int in inventory.slots.size():
			if event.is_action_pressed(StringName("slot_%d" % (i + 1))):
				inventory.select(i)


func _physics_process(delta: float) -> void:
	_shout_cooldown = maxf(0.0, _shout_cooldown - delta)
	_use_cooldown = maxf(0.0, _use_cooldown - delta)
	_alphorn_cooldown = maxf(0.0, _alphorn_cooldown - delta)
	if _radio != null and _radio.playing and Time.get_ticks_msec() / 1000.0 > _radio_until:
		_radio.stop()
	_tick_lamp(delta)
	if not is_local():
		_update_crouch(delta)
		return
	if not alive:
		focus = null
		hold_progress = 0.0
		_stop_eating()
		_wobble_left = 0.0
		_update_death_view(delta)
		return
	_move(delta)
	_update_focus(delta)
	_tick_eating(delta)
	_tick_wobble(delta)
	_tick_shake(delta)
	_tick_rotten(delta)
	net_position = global_position
	net_angles = Vector2(rotation.y, head.rotation.x)


func _process(_delta: float) -> void:
	if is_local():
		return
	if _net.sample(Time.get_ticks_msec() / 1000.0):
		global_position = _net.position
		rotation.y = Basis(_net.rotation).get_euler().y
		head.rotation.x = _net.aux
		velocity = _net.velocity
	_update_nameplate()


## A new snapshot of a remote player arrived.
func _on_synchronized() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now < _teleport_ignore_until and net_position.distance_to(_teleported_to) > _net.snap_distance:
		return
	_net.push(now, net_position, Quaternion(Vector3.UP, net_angles.x), net_angles.y)


func _move(delta: float) -> void:
	var controls: bool = input_enabled
	var input_dir: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back") if controls else Vector2.ZERO
	crouching = downed or (controls and Input.is_action_pressed(&"crouch"))
	var wants_sprint: bool = controls and Input.is_action_pressed(&"sprint") and input_dir.y < 0.0 and not crouching
	var can_sprint: bool = wants_sprint and stamina > 0.0 and _can_sprint_with_load()
	var speed: float = _config.crouch_speed if crouching else (_config.sprint_speed if can_sprint else _config.walk_speed)
	if downed:
		speed = _config.downed_crawl_speed
		can_sprint = false
	speed *= _load_speed_factor()
	if can_sprint:
		stamina = maxf(0.0, stamina - delta / _config.stamina_seconds)
	elif not wants_sprint:
		stamina = minf(1.0, stamina + delta * _config.stamina_regen_per_second)
	if in_brine:
		speed *= _config.brine_speed
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var accel: float = ACCEL_GROUND if is_on_floor() else ACCEL_AIR
	_update_climbing(controls, input_dir)
	if climbing:
		speed *= 0.35
		accel = ACCEL_GROUND
	var swimming: bool = swim_lake != null and is_instance_valid(swim_lake) and not climbing
	if swimming:
		speed = _config.swim_speed
		accel = ACCEL_AIR
	velocity.x = lerpf(velocity.x, direction.x * speed, clampf(accel * delta, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, direction.z * speed, clampf(accel * delta, 0.0, 1.0))
	if swimming:
		# Float with the head just above the surface; swimming against a low shore pulls you out.
		var feet: float = swim_lake.surface_y() - SWIM_DEPTH
		velocity.y = clampf((feet - global_position.y) * 4.0, -3.0, 2.0)
		if controls and input_dir.y < 0.0:
			_try_climb_out()
	elif climbing:
		velocity.y = _climb_velocity(input_dir)
		if controls and Input.is_action_just_pressed(&"jump"):
			_let_go_of_climbable()
	elif not is_on_floor():
		velocity.y -= _gravity * delta
	elif controls and Input.is_action_just_pressed(&"jump") and not crouching and not inventory.hands_busy():
		velocity.y = _config.jump_velocity
	var falling: float = -velocity.y if not is_on_floor() and not climbing and not swimming else 0.0
	move_and_slide()
	if falling > 0.0 and is_on_floor():
		var damage: int = _config.fall_damage(falling)
		if damage > 0:
			game().request_fall_damage.rpc_id(1, damage)
	_update_crouch(delta)
	_footsteps_and_bob(delta)


func _can_sprint_with_load() -> bool:
	var cart: Schubkarre = inventory.hands as Schubkarre
	return cart == null and inventory.can_sprint() and pushed_cart() == null and swim_lake == null


# --- swimming (Salzsee) --------------------------------------------------------------------------------

## Fell into deep water: the carbide lamp goes out and nothing heavy can be held.
func enter_water(lake: Lake) -> void:
	swim_lake = lake
	climbing = false
	if not is_local():
		return
	if lamp_on and not lamp_electric:
		_set_lamp.rpc(false)
		game().show_message(tr("MSG_LAMP_DROWNED"))
	var held: WorldItem = inventory.hands as WorldItem
	if held != null and held.data.weight_class != ItemData.WeightClass.LIGHT:
		game().request_drop.rpc_id(1, held.get_path(), hold_point.global_transform, Vector3.ZERO)
		game().show_message(tr("MSG_TOO_HEAVY_TO_SWIM"))


func exit_water(lake: Lake) -> void:
	if swim_lake == lake:
		swim_lake = null


## Pulls you up onto a shore or boat in front when there is floor just above the water there.
func _try_climb_out() -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var ahead: Vector3 = -global_basis.z * 0.8
	var from: Vector3 = global_position + Vector3.UP * (SWIM_DEPTH + 1.2) + ahead
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.8, 1)
	query.exclude = [get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return
	var ledge: Vector3 = hit.position
	if ledge.y > swim_lake.surface_y() - 0.3 and ledge.y < swim_lake.surface_y() + 0.9:
		global_position = ledge + Vector3.UP * 0.05
		velocity = Vector3.ZERO


func _load_speed_factor() -> float:
	if gunner != null and gunner.aiming:
		return _config.ads_move_speed
	if inventory.hands is Schubkarre:
		return _config.schubkarre_speed
	if pushed_cart() != null:
		return _config.rail_cart_push_speed
	return inventory.speed_factor(_config)


## The rail cart this player is pushing, if any (on every peer).
func pushed_cart() -> RailCart:
	if _pushed_cart != null and is_instance_valid(_pushed_cart) and _pushed_cart.pusher_peer == peer_id:
		return _pushed_cart
	_pushed_cart = null
	return null


# --- climbing ladders and ropes ---------------------------------------------------------------------

func enter_climbable(climbable: Climbable) -> void:
	if not climbable in _climbables:
		_climbables.append(climbable)


func exit_climbable(climbable: Climbable) -> void:
	_climbables.erase(climbable)
	if _climbables.is_empty():
		climbing = false


## Grabs on when moving in a ladder or rope zone (or hanging in one); never with a Schubkarre.
func _update_climbing(controls: bool, input_dir: Vector2) -> void:
	_climbables = _climbables.filter(func(c: Climbable) -> bool: return is_instance_valid(c))
	var now: float = Time.get_ticks_msec() / 1000.0
	if _climbables.is_empty() or now < _climb_ignore_until or inventory.hands is CargoItem:
		climbing = false
		return
	if not climbing:
		climbing = (controls and input_dir.y != 0.0) or not is_on_floor()
	elif is_on_floor() and controls and input_dir.y > 0.0:
		climbing = false  # stepped off at the bottom


## Up when pushing forward (down while looking down), down when pulling back. Slower with a
## heavy load in the hands.
func _climb_velocity(input_dir: Vector2) -> float:
	var up: float = -input_dir.y
	if head.rotation.x < -0.5:
		up = -absf(up) if input_dir.y < 0.0 else up
	var factor: float = _config.climb_heavy_factor if inventory.hands_busy() and inventory.hands_weight == ItemData.WeightClass.HEAVY else 1.0
	return up * _config.climb_speed * factor


## A rotten ladder creaks under you, and gives way if you carry something heavy up or down it.
func _tick_rotten(delta: float) -> void:
	var climb: Climbable = _climbables.back() if climbing and not _climbables.is_empty() else null
	if climb == null or not climb.rotten:
		_rotten_strain = 0.0
		return
	_creak_left -= delta
	if _creak_left <= 0.0:
		_creak_left = randf_range(0.7, 1.5)
		Audio.play_at("plank_creak", global_position + Vector3.UP, &"SFX", -6.0, 15.0)
	if not (inventory.hands_busy() and inventory.hands_weight == ItemData.WeightClass.HEAVY):
		return
	_rotten_strain += delta
	var ladder: Ladder = climb.get_parent() as Ladder
	if _rotten_strain >= _config.rotten_break_seconds and ladder != null:
		_rotten_strain = -INF  # asked once
		game().request_break_ladder.rpc_id(1, ladder.get_path())


func _let_go_of_climbable() -> void:
	climbing = false
	_climb_ignore_until = Time.get_ticks_msec() / 1000.0 + 0.5
	velocity += transform.basis.z * 2.0 + Vector3.UP * 1.5


func _update_crouch(delta: float) -> void:
	var target: float = DOWNED_HEAD if downed else (CROUCH_HEAD if crouching else STAND_HEAD)
	_head_height = lerpf(_head_height, target, clampf(10.0 * delta, 0.0, 1.0))
	var capsule: CapsuleShape3D = shape.shape as CapsuleShape3D
	capsule.height = CROUCH_HEIGHT if crouching else STAND_HEIGHT
	shape.position.y = capsule.height / 2.0
	if not is_local():
		head.position.y = _head_height
		body_mesh.scale.y = _head_height / STAND_HEAD


func _footsteps_and_bob(delta: float) -> void:
	var horizontal: float = Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horizontal > 0.3:
		_step_accum += horizontal * delta
		var stride: float = clampf(0.9 + horizontal * STRIDE_PER_SPEED, STRIDE_MIN, STRIDE_MAX)
		_bob_phase += horizontal * delta * PI / stride
		if _step_accum >= stride:
			_step_accum = 0.0
			_play_footstep.rpc(_surface())
	else:
		_bob_phase = lerpf(_bob_phase, roundf(_bob_phase / PI) * PI, clampf(6.0 * delta, 0.0, 1.0))
	var bob: float = BOB_AMOUNT if Settings.data.head_bob else 0.0
	head.position.y = _head_height + absf(sin(_bob_phase)) * bob


enum Surface { GRAVEL, WOOD, BRINE, SALT }


func _surface() -> Surface:
	if global_position.y > Game.HUB_FLOOR_ABOVE:
		return Surface.WOOD
	if in_brine:
		return Surface.BRINE
	var mine: Mine = game().mine
	return Surface.SALT if mine != null and mine.chunk_set.footsteps == "footstep_salt" else Surface.GRAVEL


@rpc("authority", "call_local", "unreliable")
func _play_footstep(surface: Surface) -> void:
	Audio.play_on(footsteps, ["footstep_gravel", "footstep_wood", "wade", "footstep_salt"][surface], 0.06)
	footsteps.volume_db = -14.0 if crouching else -6.0


@rpc("any_peer", "call_local", "reliable")
func teleport(to: Transform3D) -> void:
	global_transform = to
	velocity = Vector3.ZERO
	head.rotation.x = 0.0
	net_position = to.origin
	net_angles = Vector2(rotation.y, 0.0)
	_net.clear()
	_teleported_to = to.origin
	_teleport_ignore_until = Time.get_ticks_msec() / 1000.0 + 0.5


## Back in the game at the ride (after dying or being left behind).
@rpc("any_peer", "call_local", "reliable")
func revive() -> void:
	health = _config.player_max_health
	set_downed(false)
	if alive:
		return
	alive = true
	shape.set_deferred(&"disabled", false)
	body_mesh.visible = not is_local()
	if is_local():
		_spectate(null)
		head.rotation.z = 0.0


@rpc("any_peer", "call_local", "reliable")
func set_health(value: int) -> void:
	health = value


## Died (the host decided; Game turns the body into a corpse item). The player watches the
## others until the next ride.
@rpc("any_peer", "call_local", "reliable")
func die() -> void:
	if not alive:
		return
	alive = false
	health = 0
	_dead_time = 0.0
	shape.set_deferred(&"disabled", true)
	body_mesh.visible = false
	if _nameplate != null:
		_nameplate.visible = false
	print("[player] P%d died" % peer_id)


# --- downed (co-op) ------------------------------------------------------------------------------------

## Down or back up (the host decides). A downed miner can be aimed at and helped up: their
## body joins the interactables layer on every peer.
@rpc("any_peer", "call_local", "reliable")
func set_downed(on: bool) -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return
	downed = on
	_downed_at = Time.get_ticks_msec() / 1000.0
	collision_layer = 2 | (WorldItem.LAYER_INTERACT if on else 0)
	if on and is_local():
		_stop_eating()


## Seconds until a downed miner bleeds out (the host's own clock decides; this is for the HUD).
func downed_left() -> float:
	return maxf(0.0, _config.downed_seconds - (Time.get_ticks_msec() / 1000.0 - _downed_at)) if downed else 0.0


## Teammates see "help up" on a downed miner (hold E).
func interaction_text(other: Player) -> String:
	if downed and alive and other != self and other.alive and not other.downed:
		return tr("PROMPT_HELP_UP") % display_name()
	return ""


func interact_hold_seconds(_other: Player) -> float:
	return _config.help_up_seconds


func interact(other: Player) -> void:
	game().request_help_up.rpc_id(1, get_path())
	other.hold_progress = 0.0


# --- death and spectating (local player) ------------------------------------------------------------

func _update_death_view(delta: float) -> void:
	_dead_time += delta
	if _dead_time < DEATH_VIEW_SECONDS:
		# Sink to the floor and tip over.
		head.position.y = lerpf(head.position.y, 0.25, clampf(3.0 * delta, 0.0, 1.0))
		head.rotation.z = lerpf(head.rotation.z, 1.2, clampf(2.0 * delta, 0.0, 1.0))
		return
	var living: Array[Player] = _living_teammates()
	if spectating == null or not is_instance_valid(spectating) or not spectating in living:
		_spectate(living[0] if not living.is_empty() else null)


func _living_teammates() -> Array[Player]:
	var result: Array[Player] = []
	for player: Player in game().players():
		if player != self and player.alive:
			result.append(player)
	return result


## Switches to the next (step 1) or previous (-1) living teammate.
func spectate_next(step: int) -> void:
	var living: Array[Player] = _living_teammates()
	if living.is_empty() or _dead_time < DEATH_VIEW_SECONDS:
		return
	_spectate(living[posmod(living.find(spectating) + step, living.size())])


func _spectate(target: Player) -> void:
	if target == spectating:
		return
	if spectating != null and is_instance_valid(spectating):
		spectating.body_mesh.visible = spectating.alive
	spectating = target
	if target != null:
		target.camera.current = true
		target.body_mesh.visible = false
		print("[player] spectating P%d" % target.peer_id)
	else:
		camera.current = true


# --- nameplate (other players) ----------------------------------------------------------------------

func display_name() -> String:
	return steam_name if steam_name != "" else tr("PLAYER_NAME") % player_number


func _build_nameplate() -> void:
	_nameplate = Label3D.new()
	_nameplate.text = display_name()
	_nameplate.position = Vector3(0.0, 2.0, 0.0)
	_nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_nameplate.pixel_size = 0.0035
	_nameplate.font_size = 40
	_nameplate.outline_size = 10
	_nameplate.modulate = Color(0.96, 0.9, 0.78, 0.85)
	_nameplate.visible = false
	add_child(_nameplate)


## Shown only while you look right at the player from close by, so it never lights up the dark.
func _update_nameplate() -> void:
	var viewer: Camera3D = get_viewport().get_camera_3d()
	if viewer == null or viewer == camera or not alive:
		_nameplate.visible = false
		return
	var to_me: Vector3 = global_position + Vector3.UP * 1.6 - viewer.global_position
	_nameplate.visible = to_me.length() < NAMEPLATE_DISTANCE and to_me.normalized().dot(-viewer.global_basis.z) > 0.97


# --- lamp ------------------------------------------------------------------------------------------

func _toggle_lamp() -> void:
	if lamp_share() <= 0.0:
		return
	_set_lamp.rpc(not lamp_on)


@rpc("authority", "call_local", "reliable")
func _set_lamp(on: bool) -> void:
	lamp_on = on
	Audio.play_at("lamp_click", lamp.global_position, &"SFX", -8.0, 8.0)
	_update_lamp()


## Puts on the Stirnlampe (true) or goes back to the carbide lamp (false); the new one is on.
@rpc("authority", "call_local", "reliable")
func _set_lamp_kind(electric: bool) -> void:
	lamp_electric = electric
	lamp_on = lamp_share() > 0.0
	Audio.play_at("lamp_click", lamp.global_position, &"SFX", -8.0, 8.0)
	_update_lamp()


func _tick_lamp(delta: float) -> void:
	# Carbide and battery only run down in the mine. Other players' levels come with their sync.
	if not lamp_on or global_position.y > Game.HUB_FLOOR_ABOVE:
		return
	if not is_local():
		_update_lamp()
		return
	if lamp_electric:
		battery = maxf(0.0, battery - delta)
	else:
		lamp_fuel = maxf(0.0, lamp_fuel - delta * brine_lamp_drain())
	if lamp_share() <= 0.0:
		lamp_on = false
	_update_lamp()


## Brine splashing up into the carbide lamp makes it burn faster (DESIGN.md §4 "Sole").
func brine_lamp_drain() -> float:
	return _config.brine_lamp_drain if in_brine and not lamp_electric else 1.0


func _update_lamp() -> void:
	var share: float = lamp_share()
	var low: bool = share < _config.lamp_low_fuel_share
	var strength: float = 0.6 + 0.4 * minf(1.0, share / _config.lamp_low_fuel_share)
	lamp.visible = lamp_on
	beam.visible = lamp_on
	var reach: float = 0.0
	var energy: float = 0.0
	var color: Color
	if lamp_electric:
		# A steady, colder, narrower beam that dims as the battery dies.
		reach = _config.stirnlampe_range * strength
		energy = _config.stirnlampe_energy * (0.5 if low else 1.0)
		_lamp_flame.flicker = 0.12 if low else 0.0
		color = Color(0.86, 0.9, 1.0)
		beam.spot_angle = _config.stirnlampe_beam_degrees
	else:
		# Near firedamp the flame flares up tall and bluish.
		reach = _config.lamp_range * strength * (1.0 + gas_flare * 0.25)
		energy = _config.lamp_energy * (0.55 if low else 1.0) * (1.0 + gas_flare * 1.4)
		_lamp_flame.flicker = maxf(0.35 if low else 0.07, gas_flare * 0.45)
		color = _carbide_color.lerp(Color(0.62, 0.78, 1.0), gas_flare * 0.7)
		beam.spot_angle = _config.lamp_beam_degrees
	beam.spot_range = reach
	_beam_flame.base_energy = energy * _config.lamp_beam_energy
	_beam_flame.flicker = _lamp_flame.flicker
	beam.light_color = color
	lamp.omni_range = _config.lamp_glow_range * strength
	_lamp_flame.base_energy = energy * _config.lamp_glow_energy
	lamp.light_color = color
	# Only other players' carbide lamps hiss: your own would be a constant noise in your ear.
	var hiss: bool = lamp_on and not lamp_electric and not is_local()
	if hiss and not lamp_sound.playing:
		lamp_sound.play()
	elif not hiss and lamp_sound.playing:
		lamp_sound.stop()


## An open flame that can set off firedamp: a burning carbide lamp.
func has_open_flame() -> bool:
	return alive and lamp_on and not lamp_electric


## A fresh battery for the Stirnlampe (in the Gasthaus, before each shift).
func recharge_battery() -> void:
	battery = _config.stirnlampe_battery_seconds
	_update_lamp()


func refill_lamp(share: float) -> void:
	lamp_fuel = minf(_config.lamp_fuel_seconds, lamp_fuel + share * _config.lamp_fuel_seconds)
	Audio.play_at("lamp_refill", lamp.global_position, &"SFX", -4.0, 10.0)
	if not lamp_on:
		_set_lamp.rpc(true)


## How far this player's lamp beam reaches right now (0 when it is off), on every peer.
func light_range() -> float:
	return beam.spot_range if lamp_on and beam.visible and alive else 0.0


## Whether this player's lamp lights `point`: inside the beam up to `share` of its reach, or
## within the glow close around them. Rock in between is not checked here.
func lights_point(point: Vector3, share: float = 1.0) -> bool:
	if light_range() <= 0.0:
		return false
	if point.distance_to(lamp.global_position) < lamp.omni_range * 0.8:
		return true
	var to: Vector3 = point - beam.global_position
	if to.length() > beam.spot_range * share:
		return false
	return to.normalized().dot(-beam.global_basis.z) >= cos(deg_to_rad(beam.spot_angle))


## What is left of the lamp in use: carbide, or the Stirnlampe's battery (0–1).
func lamp_share() -> float:
	if lamp_electric:
		return battery / _config.stirnlampe_battery_seconds
	return lamp_fuel / _config.lamp_fuel_seconds


# --- interaction -----------------------------------------------------------------------------------

## The object under the crosshair that can be interacted with (walks up from the collider).
func _interactable_under_crosshair() -> Node:
	if not ray.is_colliding():
		return null
	var node: Node = ray.get_collider() as Node
	while node != null and not node.has_method(&"interaction_text"):
		node = node.get_parent()
	return node


func _update_focus(delta: float) -> void:
	focus = _interactable_under_crosshair() if input_enabled and not downed else null
	if focus != null and focus.interaction_text(self) == "":
		focus = null
	var holding: bool = input_enabled and Input.is_action_pressed(&"interact") and focus != null
	if not holding or focus != _hold_target:
		_hold_target = focus if holding else null
		_hold_time = 0.0
		hold_progress = 0.0
	if focus == null:
		return
	var needed: float = focus.interact_hold_seconds(self) if focus.has_method(&"interact_hold_seconds") else 0.0
	if needed <= 0.0:
		if Input.is_action_just_pressed(&"interact"):
			_interact(focus)
		return
	if holding:
		_hold_time += delta
		hold_progress = clampf(_hold_time / needed, 0.0, 1.0)
		if _hold_time >= needed:
			_interact(focus)
			_hold_time = -INF  # once per press


func _interact(target: Node) -> void:
	if target is WorldItem:
		_try_take(target as WorldItem)
	elif target.has_method(&"interact"):
		target.interact(self)


func _try_take(item: WorldItem) -> void:
	if item.can_help_carry(self):
		game().request_help_carry.rpc_id(1, item.get_path())
		return
	if item is RailCart:
		if not (item as RailCart).try_load_from(self):
			_pushed_cart = item as RailCart
			game().request_push_rail.rpc_id(1, item.get_path())
		return
	if item is CargoItem and (item as CargoItem).try_load_from(self):
		return
	var cart: Schubkarre = inventory.hands as Schubkarre
	if cart != null and item != cart and item.data.kind == ItemData.Kind.LOOT:
		game().request_load_cart.rpc_id(1, cart.get_path(), item.get_path())
		return
	if inventory.place_for(item.data.weight_class) == Inventory.NONE:
		game().show_message(tr("MSG_HANDS_FULL"))
		return
	game().request_take.rpc_id(1, item.get_path(), peer_id)


func _drop_active() -> void:
	if pushed_cart() != null:
		game().request_push_rail.rpc_id(1, pushed_cart().get_path())  # lets go of it
		return
	var item: WorldItem = inventory.active_item() as WorldItem
	if item == null:
		return
	# Aimed at a Schubkarre: put it in instead of on the floor.
	var aimed_cart: CargoItem = focus as CargoItem
	if aimed_cart != null and aimed_cart != item and item.is_loot():
		game().request_load_cart.rpc_id(1, aimed_cart.get_path(), item.get_path())
		return
	var heavy: bool = item.data.weight_class != ItemData.WeightClass.LIGHT
	var at: Transform3D = (hold_point if heavy else hand_point).global_transform
	if item is Schubkarre:
		at = cart_point.global_transform
	var toss: Vector3 = -camera.global_basis.z * (0.5 if heavy else _config.throw_speed * 0.4) + velocity
	game().request_drop.rpc_id(1, item.get_path(), at, toss)


func _use_active() -> void:
	if _use_cooldown > 0.0 or _eating != null:
		return
	if downed:
		if gunner != null:
			gunner.fire()  # only a gun that works lying down (Gunner.weapon_item)
		return
	var held: WorldItem = inventory.hands as WorldItem
	if inventory.hands_busy():
		# Something in both hands can still be swung if it is a weapon (the Bronzeschwert).
		if held != null and held.data.melee_damage > 0 and not inventory.shared_carry:
			_use_cooldown = 0.8
			_melee(held.data.melee_damage, false, held.data.breaks_rock)
		return
	var item: WorldItem = inventory.slots[inventory.selected] as WorldItem
	var use: ItemData.Use = item.data.use if item != null else ItemData.Use.NONE
	match use:
		ItemData.Use.REFILL_LAMP:
			_use_cooldown = 1.0
			game().request_consume.rpc_id(1, item.get_path(), peer_id)
			refill_lamp(_config.karbid_refill_share)
		ItemData.Use.HEADLAMP:
			_use_cooldown = 0.5
			if not lamp_electric and battery <= 0.0:
				game().show_message(tr("MSG_BATTERY_EMPTY"))
				return
			_set_lamp_kind.rpc(not lamp_electric)
			game().show_message(tr("MSG_LAMP_ELECTRIC") if lamp_electric else tr("MSG_LAMP_CARBIDE"))
		ItemData.Use.ALPHORN:
			if _alphorn_cooldown > 0.0:
				game().show_message(tr("MSG_OUT_OF_BREATH"))
				return
			_alphorn_cooldown = _config.alphorn_cooldown
			_use_cooldown = 1.0
			game().request_alphorn.rpc_id(1, camera.global_position, -camera.global_basis.z)
		ItemData.Use.THROW:
			_use_cooldown = 0.6
			var toss: Vector3 = (-camera.global_basis.z + Vector3.UP * 0.25).normalized() * _config.throw_tool_speed + velocity
			game().request_throw.rpc_id(1, item.get_path(), hand_point.global_transform, toss)
		ItemData.Use.DRINK:
			_use_cooldown = 1.0
			game().request_consume.rpc_id(1, item.get_path(), peer_id)
			_wobble_left = _config.obstler_wobble_seconds
		ItemData.Use.EAT, ItemData.Use.EAT_OLD:
			_eating = item
			_eating_left = _eat_seconds(item)
			game().play_sound_everywhere.rpc("eat", camera.global_position)
		ItemData.Use.WEAR:
			_use_cooldown = 0.5
			game().request_wear.rpc_id(1, item.get_path())
		ItemData.Use.OPEN:
			_use_cooldown = 1.0
			game().request_open.rpc_id(1, item.get_path())
		ItemData.Use.SHOOT:
			if gunner != null:
				gunner.fire()
		ItemData.Use.REVIVE:
			_use_cooldown = 1.0
			var body: WorldItem = focus as WorldItem
			if body == null or body.data.id != &"leiche":
				game().show_message(tr("MSG_REVIVE_AIM"))
				return
			game().request_revive.rpc_id(1, item.get_path(), body.get_path())
		ItemData.Use.ROPE:
			_use_cooldown = 1.0
			_place_rope(item)
		ItemData.Use.PFEIFERL:
			_use_cooldown = _config.pfeiferl_cooldown
			game().request_call_cart.rpc_id(1, global_position)
		ItemData.Use.RADIO:
			_use_cooldown = 1.5
			game().request_radio_call.rpc_id(1)
		_:
			var damage: int = _config.watschn_damage if item == null else item.data.melee_damage
			if damage <= 0:
				return
			_use_cooldown = 0.6
			_melee(damage, item == null, item != null and item.data.breaks_rock)


## Chewing on a Leberkässemmel: it only counts once it is eaten up, still in your hand.
func _tick_eating(delta: float) -> void:
	if _eating == null:
		use_progress = 0.0
		return
	if not is_instance_valid(_eating) or inventory.slots[inventory.selected] != _eating or inventory.hands_busy():
		_stop_eating()
		return
	_eating_left -= delta
	use_progress = 1.0 - _eating_left / _eat_seconds(_eating)
	if _eating_left <= 0.0:
		game().request_consume.rpc_id(1, _eating.get_path(), peer_id)
		_stop_eating()


func _eat_seconds(item: WorldItem) -> float:
	return _config.speckbrot_eat_seconds if item.data.use == ItemData.Use.EAT_OLD else _config.leberkaese_eat_seconds


## A hundred-year-old Speckbrot disagrees with you: the view swims for a while.
func feel_sick(seconds: float) -> void:
	_wobble_left = maxf(_wobble_left, seconds)


func _stop_eating() -> void:
	_eating = null
	_eating_left = 0.0
	use_progress = 0.0


## After an Obstler the view sways and rolls a little, fading out at the end.
func _tick_wobble(delta: float) -> void:
	if _wobble_left <= 0.0:
		camera.rotation.z = 0.0
		return
	_wobble_left -= delta
	_wobble_time += delta
	var strength: float = clampf(_wobble_left / 4.0, 0.0, 1.0)
	camera.rotation.z = sin(_wobble_time * 1.1) * 0.07 * strength
	camera.rotation.y = sin(_wobble_time * 0.7 + 1.0) * 0.03 * strength


## A jolt from a blast or a rockfall nearby (mount 0..1).
func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _tick_shake(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 1.2)
	camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.06
	camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.06


## The Seil: thrown down the edge you look at; the host checks that there is a drop.
func _place_rope(item: WorldItem) -> void:
	if not ray.is_colliding():
		game().show_message(tr("MSG_ROPE_NO_EDGE"))
		return
	var flat: Vector3 = -camera.global_basis.z
	flat.y = 0.0
	game().request_rope.rpc_id(1, item.get_path(), ray.get_collision_point(), flat.normalized())


func _melee(damage: int, bare_hand: bool, breaks_rock: bool) -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * MELEE_DISTANCE, 1 | 8)
	query.exclude = [get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	var creature: Node = null
	var rock: Breakable = null
	if not hit.is_empty():
		creature = hit.collider as Node
		rock = hit.collider as Breakable
		while creature != null and not creature.is_in_group(&"creatures"):
			creature = creature.get_parent()
	var sound: String = "swing"
	if creature != null:
		sound = "watschn" if bare_hand else "pick_hit"
	elif rock != null and breaks_rock:
		sound = "pick_hit"
	game().play_sound_everywhere.rpc(sound, camera.global_position - camera.global_basis.z * 1.0)
	if creature != null:
		game().request_hit.rpc_id(1, creature.get_path(), damage, global_position)
	elif rock != null and breaks_rock:
		game().request_break.rpc_id(1, rock.get_path(), damage)
	elif rock != null:
		game().show_message(tr("MSG_NEED_PICK"))


func _shout() -> void:
	if _shout_cooldown > 0.0:
		return
	_shout_cooldown = _config.shout_cooldown
	game().request_shout.rpc_id(1, peer_id, global_position)


## Shouted into the voice chat (VoiceChat): scares Bergmandl like the shout key, same cooldown.
func voice_shout() -> void:
	if _shout_cooldown > 0.0:
		return
	_shout_cooldown = _config.shout_cooldown
	game().request_shout.rpc_id(1, peer_id, global_position, false)


## Emotes (DESIGN.md §9): wave, point, and the Jodler, which carries far – creatures too.
enum Emote { JODLER, WAVE, POINT }


## Shows an emote on every peer: the yodel is heard, the arm moves on the body others see.
func play_emote(kind: Emote) -> void:
	if kind == Emote.JODLER:
		Audio.play_on(voice, "jodler", 0.04)
		return
	var arm: Node3D = _right_arm()
	var tween: Tween = arm.create_tween()
	if kind == Emote.WAVE:
		tween.tween_property(arm, "rotation_degrees", Vector3(0, 0, 150), 0.25)
		for i: int in 3:
			tween.tween_property(arm, "rotation_degrees", Vector3(0, 0, 125), 0.18)
			tween.tween_property(arm, "rotation_degrees", Vector3(0, 0, 165), 0.18)
	else:
		tween.tween_property(arm, "rotation_degrees", Vector3(80, 0, 0), 0.2)
		tween.tween_interval(1.4)
	tween.tween_property(arm, "rotation_degrees", Vector3.ZERO, 0.3)


## The arms on the body other players see (made on first use; the right one does the emotes).
func _right_arm() -> Node3D:
	var arm: Node3D = body_mesh.get_node_or_null(^"ArmR") as Node3D
	if arm != null:
		return arm
	var jacket: Material = (body_mesh.get_node(^"Torso") as MeshInstance3D).get_surface_override_material(0)
	for side: float in [-1.0, 1.0]:
		var pivot: Node3D = Node3D.new()
		pivot.name = "ArmR" if side > 0.0 else "ArmL"
		pivot.position = Vector3(side * 0.34, 1.4, 0.0)
		body_mesh.add_child(pivot)
		BodyParts.add(pivot, BodyParts.capsule(0.07, 0.65), jacket, Vector3(0.0, -0.3, 0.0))
		BodyParts.add(pivot, BodyParts.sphere(0.06, 10), _hand_material(), Vector3(0.0, -0.63, 0.0))
	return body_mesh.get_node(^"ArmR") as Node3D


static func _hand_material() -> StandardMaterial3D:
	var glove: StandardMaterial3D = StandardMaterial3D.new()
	glove.albedo_color = Color(0.3, 0.22, 0.14)
	glove.roughness = 0.9
	return glove


func play_shout() -> void:
	Audio.play_on(voice, "shout_%d" % (randi() % 3 + 1), 0.05)


## The Funkgerät in your pocket crackles for `seconds` (local player's own speaker).
func play_radio(seconds: float) -> void:
	if _radio == null:
		_radio = AudioStreamPlayer.new()
		_radio.name = "Radio"
		_radio.bus = &"Radio"
		_radio.volume_db = -10.0
		_radio.stream = Audio.stream("radio_static")
		add_child(_radio)
	_radio_until = maxf(_radio_until, Time.get_ticks_msec() / 1000.0 + seconds)
	if not _radio.playing:
		_radio.play()


# --- held items ------------------------------------------------------------------------------------

## Where an item in `place` should ride: the hands, a slot (shown in the hand when selected).
func follow_point_for(item: WorldItem, place: int) -> Node3D:
	if item is Schubkarre:
		return cart_point
	if item.worn and place != Inventory.HANDS:
		return _hat_point()
	return hold_point if place == Inventory.HANDS else hand_point


## Where a worn hat sits: on top of the helmet (made on first use).
func _hat_point() -> Node3D:
	var point: Node3D = head.get_node_or_null(^"HatPoint") as Node3D
	if point == null:
		point = Node3D.new()
		point.name = "HatPoint"
		point.position = Vector3(0.0, 0.16, 0.02)
		head.add_child(point)
	return point


func _on_inventory_changed() -> void:
	refresh_held_items()
	if is_local():
		net_slot = inventory.selected
		# Dropped or lost the Stirnlampe: back to the carbide lamp (deferred: items also leave
		# the inventory while the whole scene is being freed).
		if lamp_electric:
			_check_headlamp.call_deferred()
	inventory_changed.emit()


## Only the selected slot item shows in the hand, and only while the hands are free. A worn
## hat shows on the head, to everyone but its wearer.
func refresh_held_items() -> void:
	for i: int in inventory.slots.size():
		var item: WorldItem = inventory.slots[i] as WorldItem
		if item != null and item.worn:
			item.visible = not is_local() and alive
		elif item != null:
			item.visible = i == inventory.selected and not inventory.hands_busy()


func _check_headlamp() -> void:
	if lamp_electric and not has_tool(&"stirnlampe"):
		_set_lamp_kind.rpc(false)


func ammo_count(ammo_type: StringName) -> int:
	return int(ammo.get(ammo_type, 0))


## Takes `amount` rounds off a counter (the owner, when reloading).
func use_ammo(ammo_type: StringName, amount: int) -> void:
	ammo[ammo_type] = maxi(0, ammo_count(ammo_type) - amount)
	_share_ammo.rpc(ammo)


## The owner's counters, for everyone else (the host's cap check, teammates' HUD later).
@rpc("authority", "call_remote", "reliable")
func _share_ammo(counts: Dictionary) -> void:
	ammo = counts.duplicate()


## The host hands this miner ammo (a box picked up, the shift ration). `at_least`: top up to
## `amount` instead of adding it. Capped per type.
@rpc("any_peer", "call_local", "reliable")
func give_ammo(ammo_type: StringName, amount: int, at_least: bool = false) -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return  # only the host hands out ammo
	var have: int = ammo_count(ammo_type)
	var total: int = maxi(have, amount) if at_least else have + amount
	ammo[ammo_type] = mini(total, _config.ammo_cap(ammo_type))
	if is_local():
		_share_ammo.rpc(ammo)


## Everything spare is gone (death).
@rpc("any_peer", "call_local", "reliable")
func clear_ammo() -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return
	ammo.clear()
	if is_local():
		_share_ammo.rpc(ammo)


## Whether an item of type `id` is in the pockets or hands.
func has_tool(id: StringName) -> bool:
	for item: Object in inventory.all_items():
		var world_item: WorldItem = item as WorldItem
		if world_item != null and world_item.data.id == id:
			return true
	return false
