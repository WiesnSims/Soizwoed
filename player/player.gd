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
## Your own lamp hangs right in front of your eyes: at full strength it would light the fog
## there and wash out the top of the screen. Others still see its full glow in the dust.
const OWN_LAMP_FOG_ENERGY: float = 0.15

var peer_id: int = 1
## 1..4 in order of joining, for the name other players see ("Kumpl 2").
var player_number: int = 1
## The Steam name ("" without Steam, then "Kumpl N" is shown). Set by the host at spawn.
var steam_name: String = ""
## Proximity voice (Steam sessions only), else null.
var voice_chat: VoiceChat
var inventory: Inventory
var health: int = 100
var stamina: float = 1.0
var lamp_fuel: float = 0.0
var lamp_on: bool = true:
	set(value):
		lamp_on = value
		if is_node_ready():
			_update_lamp()
var crouching: bool = false
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

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var lamp: FlickerLight = $Head/Lamp
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
	ray.target_position = Vector3(0, 0, -_config.interact_distance)
	ray.add_exception(self)
	var local: bool = is_local()
	camera.current = local
	body_mesh.visible = not local
	if local and not Game.dev_quiet:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if local:
		lamp.light_volumetric_fog_energy = OWN_LAMP_FOG_ENERGY
	if NetworkManager.voice_enabled():
		voice_chat = VoiceChat.new()
		voice_chat.name = "VoiceChat"
		add_child(voice_chat)
	if not local:
		_build_nameplate()
		sync.synchronized.connect(_on_synchronized)
		inventory.select(net_slot)
	_update_lamp()


func _exit_tree() -> void:
	lamp_sound.stop()


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
		rotate_y(-motion.relative.x * MOUSE_SENSITIVITY)
		head.rotation.x = clampf(head.rotation.x - motion.relative.y * MOUSE_SENSITIVITY, deg_to_rad(-85), deg_to_rad(85))
	elif event.is_action_pressed(&"lamp"):
		_toggle_lamp()
	elif event.is_action_pressed(&"drop"):
		_drop_active()
	elif event.is_action_pressed(&"use"):
		_use_active()
	elif event.is_action_pressed(&"shout"):
		_shout()
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
	_tick_lamp(delta)
	if not is_local():
		_update_crouch(delta)
		return
	if not alive:
		focus = null
		hold_progress = 0.0
		_update_death_view(delta)
		return
	_move(delta)
	_update_focus(delta)
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
	crouching = controls and Input.is_action_pressed(&"crouch")
	var wants_sprint: bool = controls and Input.is_action_pressed(&"sprint") and input_dir.y < 0.0 and not crouching
	var can_sprint: bool = wants_sprint and stamina > 0.0 and _can_sprint_with_load()
	var speed: float = _config.crouch_speed if crouching else (_config.sprint_speed if can_sprint else _config.walk_speed)
	speed *= _load_speed_factor()
	if can_sprint:
		stamina = maxf(0.0, stamina - delta / _config.stamina_seconds)
	elif not wants_sprint:
		stamina = minf(1.0, stamina + delta * _config.stamina_regen_per_second)
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var accel: float = ACCEL_GROUND if is_on_floor() else ACCEL_AIR
	velocity.x = lerpf(velocity.x, direction.x * speed, clampf(accel * delta, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, direction.z * speed, clampf(accel * delta, 0.0, 1.0))
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif controls and Input.is_action_just_pressed(&"jump") and not crouching and not inventory.hands_busy():
		velocity.y = _config.jump_velocity
	var falling: float = -velocity.y if not is_on_floor() else 0.0
	move_and_slide()
	if falling > 0.0 and is_on_floor():
		var damage: int = _config.fall_damage(falling)
		if damage > 0:
			game().request_fall_damage.rpc_id(1, damage)
	_update_crouch(delta)
	_footsteps_and_bob(delta)


func _can_sprint_with_load() -> bool:
	var cart: Schubkarre = inventory.hands as Schubkarre
	return cart == null and inventory.can_sprint()


func _load_speed_factor() -> float:
	if inventory.hands is Schubkarre:
		return _config.schubkarre_speed
	return inventory.speed_factor(_config)


func _update_crouch(delta: float) -> void:
	var target: float = CROUCH_HEAD if crouching else STAND_HEAD
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
			_play_footstep.rpc(global_position.y > Game.HUB_FLOOR_ABOVE)
	else:
		_bob_phase = lerpf(_bob_phase, roundf(_bob_phase / PI) * PI, clampf(6.0 * delta, 0.0, 1.0))
	head.position.y = _head_height + absf(sin(_bob_phase)) * BOB_AMOUNT


@rpc("authority", "call_local", "unreliable")
func _play_footstep(on_wood: bool) -> void:
	Audio.play_on(footsteps, "footstep_wood" if on_wood else "footstep_gravel", 0.06)
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
	if lamp_fuel <= 0.0:
		return
	_set_lamp.rpc(not lamp_on)


@rpc("authority", "call_local", "reliable")
func _set_lamp(on: bool) -> void:
	lamp_on = on
	Audio.play_at("lamp_click", lamp.global_position, &"SFX", -8.0, 8.0)
	_update_lamp()


func _tick_lamp(delta: float) -> void:
	# The carbide only burns down in the mine. Other players' fuel comes with their sync.
	if not lamp_on or global_position.y > Game.HUB_FLOOR_ABOVE:
		return
	if not is_local():
		_update_lamp()
		return
	lamp_fuel = maxf(0.0, lamp_fuel - delta)
	if lamp_fuel <= 0.0:
		lamp_on = false
	_update_lamp()


func _update_lamp() -> void:
	var share: float = lamp_fuel / _config.lamp_fuel_seconds
	var low: bool = share < _config.lamp_low_fuel_share
	lamp.visible = lamp_on
	lamp.omni_range = _config.lamp_range * (0.6 + 0.4 * minf(1.0, share / _config.lamp_low_fuel_share))
	lamp.base_energy = _config.lamp_energy * (0.55 if low else 1.0)
	lamp.flicker = 0.35 if low else 0.07
	# Only other players' lamps hiss: your own would be a constant noise in your ear.
	if lamp_on and not lamp_sound.playing and not is_local():
		lamp_sound.play()
	elif not lamp_on and lamp_sound.playing:
		lamp_sound.stop()


func refill_lamp(share: float) -> void:
	lamp_fuel = minf(_config.lamp_fuel_seconds, lamp_fuel + share * _config.lamp_fuel_seconds)
	Audio.play_at("lamp_refill", lamp.global_position, &"SFX", -4.0, 10.0)
	if not lamp_on:
		_set_lamp.rpc(true)


func lamp_share() -> float:
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
	focus = _interactable_under_crosshair() if input_enabled else null
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
	if item is Schubkarre and (item as Schubkarre).try_load_from(self):
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
	var item: WorldItem = inventory.active_item() as WorldItem
	if item == null:
		return
	# Aimed at a Schubkarre: put it in instead of on the floor.
	var aimed_cart: Schubkarre = focus as Schubkarre
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
	if _use_cooldown > 0.0 or inventory.hands_busy():
		return
	var item: WorldItem = inventory.slots[inventory.selected] as WorldItem
	if item != null and item.data.id == &"karbidpatrone":
		_use_cooldown = 1.0
		game().request_consume.rpc_id(1, item.get_path(), peer_id)
		refill_lamp(_config.karbid_refill_share)
		return
	var damage: int = _config.watschn_damage if item == null else item.data.melee_damage
	if damage <= 0:
		return
	_use_cooldown = 0.6
	_melee(damage, item == null)


func _melee(damage: int, bare_hand: bool) -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var from: Vector3 = camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * MELEE_DISTANCE, 1 | 8)
	query.exclude = [get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	var creature: Node = null
	if not hit.is_empty():
		creature = hit.collider as Node
		while creature != null and not creature.is_in_group(&"creatures"):
			creature = creature.get_parent()
	var sound: String = ("watschn" if bare_hand else "pick_hit") if creature != null else "swing"
	game().play_sound_everywhere.rpc(sound, camera.global_position - camera.global_basis.z * 1.0)
	if creature != null:
		game().request_hit.rpc_id(1, creature.get_path(), damage, global_position)


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


func play_shout() -> void:
	Audio.play_on(voice, "shout_%d" % (randi() % 3 + 1), 0.05)


# --- held items ------------------------------------------------------------------------------------

## Where an item in `place` should ride: the hands, a slot (shown in the hand when selected).
func follow_point_for(item: WorldItem, place: int) -> Node3D:
	if item is Schubkarre:
		return cart_point
	return hold_point if place == Inventory.HANDS else hand_point


func _on_inventory_changed() -> void:
	# Only the selected slot item shows in the hand, and only while the hands are free.
	for i: int in inventory.slots.size():
		var item: WorldItem = inventory.slots[i] as WorldItem
		if item != null:
			item.visible = i == inventory.selected and not inventory.hands_busy()
	if is_local():
		net_slot = inventory.selected
	inventory_changed.emit()
