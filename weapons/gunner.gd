class_name Gunner
extends Node
## The local player's shooting (DESIGN.md §3, §7): aim down the sights (hold `aim`), fire (the
## `use` click, via Player._use_active), reload (`reload`), recoil and spread. The shooter's own
## screen decides what was hit – zero delay, fine among friends (§11) – and tells the host,
## which applies the damage, makes the noise and shows the shot to everyone else.
## Rounds in the magazine live on the gun item (WorldItem.rounds); spare ammo is the player's
## counter (Player.ammo).

const RAY_MASK: int = 1 | 2 | 8  # rock, players, creatures
## How quickly the view comes back down after the kick (share per second).
const RECOIL_RECOVERY: float = 7.0
const RECOIL_RECOVER_SHARE: float = 0.65

var player: Player
var aiming: bool = false
var reloading: bool = false
## 0..1 of the current reload step (HUD bar).
var reload_progress: float = 0.0
## The gun in hand: hands, motion, kick, flash, casings (purely visual).
var view: GunView

var _cooldown: float = 0.0
var _reload_left: float = 0.0
var _reload_item: WorldItem
var _recoil_left: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _late_sound_played: bool = false


func _ready() -> void:
	player = get_parent() as Player
	_rng.randomize()
	view = GunView.new()
	view.setup(player)


## The gun in the selected pocket, if the hands are free for it (or the miner is downed –
## then only a light gun).
func weapon_item() -> WorldItem:
	if player.inventory.hands_busy() or not player.can_act():
		return null
	var item: WorldItem = player.inventory.slots[player.inventory.selected] as WorldItem
	if item == null or item.data.weapon == null or (player.downed and not item.data.weapon.usable_downed):
		return null
	return item


## What the view shows in the hands: the gun, or the Spitzhacke held as a melee weapon.
func view_item() -> WorldItem:
	var item: WorldItem = weapon_item()
	if item != null or player.inventory.hands_busy() or player.downed:
		return item
	var selected: WorldItem = player.inventory.slots[player.inventory.selected] as WorldItem
	return selected if GunView.is_melee(selected) else null


func _process(delta: float) -> void:
	if not player.is_local():
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	var item: WorldItem = weapon_item()
	var held: WorldItem = view_item()
	var can_aim: bool = item != null and player.input_enabled and player.alive and not reloading
	_set_aiming(can_aim and Input.is_action_pressed(&"aim"), held)
	_tick_reload(delta, item)
	view.update(delta, held, aiming, reloading, reload_progress)
	_tick_recoil(delta)
	var fov: float = Settings.data.fov * (item.data.weapon.ads_zoom if aiming and item != null else 1.0)
	player.camera.fov = lerpf(player.camera.fov, fov, clampf(delta * 14.0, 0.0, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	if player.is_local() and player.input_enabled and player.alive and event.is_action_pressed(&"reload"):
		start_reload()


func _set_aiming(on: bool, item: WorldItem) -> void:
	if item != null and item.state == WorldItem.State.STORED and not item.worn:
		var point: Node3D = view.melee_point if GunView.is_melee(item) else view
		if item.follow != point:
			item.follow = point
	aiming = on


## Pulls the trigger. True when a shot went off.
func fire() -> bool:
	var item: WorldItem = weapon_item()
	if item == null or _cooldown > 0.0:
		return false
	var weapon: WeaponData = item.data.weapon
	if reloading:
		# A shell-by-shell reload can be cut short to shoot what is loaded.
		if weapon.reload_per_round and item.rounds > 0:
			_stop_reload()
		else:
			return false
	if item.rounds <= 0:
		_cooldown = 0.3
		Audio.play_at(weapon.dry_sound, player.camera.global_position, &"SFX", -4.0, 8.0)
		start_reload()
		return false
	item.rounds -= 1
	_cooldown = weapon.fire_interval
	var origin: Vector3 = player.camera.global_position
	var forward: Vector3 = -player.camera.global_basis.z
	var moving: bool = Vector2(player.velocity.x, player.velocity.z).length() > 0.6
	var cone: float = WeaponMath.spread(weapon, aiming, moving, player.crouching)
	var game: Game = player.game()
	var muzzle: Vector3 = item.global_transform * weapon.muzzle
	if weapon.projectile:
		# A flare: it flies and burns; the host's copy decides what it hits.
		var direction: Vector3 = WeaponMath.pellet_directions(forward, cone, 1, _rng)[0]
		game.request_flare.rpc_id(1, item.get_path(), item.rounds, muzzle, origin, direction * Balance.config.flare_speed + player.velocity * 0.5)
		Audio.play_at(weapon.sound, muzzle, &"SFX", -1.0, 60.0, randf_range(0.97, 1.03))
		_after_shot(item, weapon)
		return true
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var creature_damage: Dictionary = {}  # Creature -> int
	var creature_weak: Dictionary = {}  # Creature -> true when a pellet hit its weak spot
	var player_damage: Dictionary = {}  # peer id -> int
	var ends: PackedVector3Array = []
	var flesh: PackedByteArray = []
	for direction: Vector3 in WeaponMath.pellet_directions(forward, cone, weapon.pellets, _rng):
		var hit: Dictionary = _ray(space, origin, origin + direction * weapon.range)
		if hit.is_empty():
			ends.append(origin + direction * weapon.range)
			flesh.append(0)
			continue
		var at: Vector3 = hit.position
		ends.append(at)
		var damage: int = WeaponMath.damage_at(weapon, origin.distance_to(at))
		var creature: Creature = _creature_of(hit.collider as Node)
		var other: Player = hit.collider as Player
		flesh.append(1 if creature != null or other != null else 0)
		if creature != null:
			var mult: float = creature.weak_spot_mult(at)
			if mult > 1.0:
				creature_weak[creature] = true
			creature_damage[creature] = int(creature_damage.get(creature, 0)) + roundi(damage * mult)
		elif other != null and other != player:
			player_damage[other.peer_id] = int(player_damage.get(other.peer_id, 0)) + damage
	# No hit marker (owner decision): a hit shows as blood on the creature and its cry.
	for creature: Creature in creature_damage:
		game.request_hit.rpc_id(1, creature.get_path(), int(creature_damage[creature]), player.global_position, creature_weak.has(creature))
	for peer: int in player_damage:
		game.request_shoot_player.rpc_id(1, peer, int(player_damage[peer]))
	ShotFx.play(muzzle, ends, flesh, weapon.sound, false)  # the gun in hand shows its own flash
	game.request_fire.rpc_id(1, item.get_path(), item.rounds, muzzle, ends, flesh)
	_after_shot(item, weapon)
	return true


## The ray of one pellet: through anything bullets cannot touch (a Kasermandl in the dark).
func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var exclude: Array[RID] = [player.get_rid()]
	for attempt: int in 4:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, RAY_MASK)
		query.exclude = exclude
		var hit: Dictionary = space.intersect_ray(query)
		var creature: Creature = _creature_of(hit.collider as Node) if not hit.is_empty() else null
		if creature == null or creature.can_be_shot():
			return hit
		exclude.append(creature.get_rid())
	return {}


## Kick, the gun in hand, the view shake, and a bolt-action's bolt being worked.
func _after_shot(item: WorldItem, weapon: WeaponData) -> void:
	if weapon.cycle_sound != "" and item.rounds > 0:
		get_tree().create_timer(weapon.cycle_delay).timeout.connect(func() -> void:
			if is_instance_valid(player) and player.alive:
				Audio.play_at(weapon.cycle_sound, player.camera.global_position, &"SFX", -3.0, 12.0))
	_kick(weapon.recoil)
	view.fire(item)
	if weapon.shake > 0.0:
		player.shake(weapon.shake)


## Grabbed or thrown down: no aiming, the reload is lost.
func cancel() -> void:
	aiming = false
	_stop_reload()


func _creature_of(node: Node) -> Creature:
	while node != null and not node is Creature:
		node = node.get_parent()
	return node as Creature


func start_reload() -> void:
	var item: WorldItem = weapon_item()
	if item == null or reloading:
		return
	var weapon: WeaponData = item.data.weapon
	if WeaponMath.rounds_to_load(weapon, item.rounds, player.ammo_count(weapon.ammo_type)) <= 0:
		return
	reloading = true
	_reload_item = item
	_reload_left = weapon.reload_seconds
	reload_progress = 0.0
	_late_sound_played = false
	if weapon.reload_open_sound != "":
		Audio.play_at(weapon.reload_open_sound, player.camera.global_position, &"SFX", -4.0, 12.0)
		_play_later(weapon.reload_sound, weapon.reload_seconds * 0.5)
	else:
		Audio.play_at(weapon.reload_sound, player.camera.global_position, &"SFX", -4.0, 12.0)
	if weapon.rack_sound != "" and item.rounds == 0:
		_play_later(weapon.rack_sound, weapon.reload_seconds * weapon.rack_share)


func _tick_reload(delta: float, item: WorldItem) -> void:
	if not reloading:
		reload_progress = 0.0
		return
	if item == null or item != _reload_item or not player.alive:
		_stop_reload()  # switched away: the reload is lost
		return
	var weapon: WeaponData = item.data.weapon
	_reload_left -= delta
	reload_progress = 1.0 - _reload_left / weapon.reload_seconds
	if not _late_sound_played and weapon.reload_sound_late != "" and reload_progress >= weapon.reload_late_share:
		_late_sound_played = true
		Audio.play_at(weapon.reload_sound_late, player.camera.global_position, &"SFX", -4.0, 12.0)
	if _reload_left > 0.0:
		return
	var loaded: int = WeaponMath.rounds_to_load(weapon, item.rounds, player.ammo_count(weapon.ammo_type))
	item.rounds += loaded
	player.use_ammo(weapon.ammo_type, loaded)
	player.game().request_reload.rpc_id(1, item.get_path(), item.rounds)
	if weapon.reload_per_round and WeaponMath.rounds_to_load(weapon, item.rounds, player.ammo_count(weapon.ammo_type)) > 0:
		_reload_left = weapon.reload_seconds
		Audio.play_at(weapon.reload_sound, player.camera.global_position, &"SFX", -4.0, 12.0)
	else:
		_stop_reload()


func _stop_reload() -> void:
	if reloading and player.alive and _reload_item != null and _reload_item.data.weapon.reload_close_sound != "":
		Audio.play_at(_reload_item.data.weapon.reload_close_sound, player.camera.global_position, &"SFX", -4.0, 12.0)
	reloading = false
	_reload_item = null
	reload_progress = 0.0


## A reload sound a moment into the step (the shell after the gun is open), only if still reloading.
func _play_later(sound: String, seconds: float) -> void:
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if reloading and is_instance_valid(player):
			Audio.play_at(sound, player.camera.global_position, &"SFX", -4.0, 12.0))


## The muzzle kicks the view up; most of it comes back down by itself.
func _kick(degrees: float) -> void:
	var kick: float = deg_to_rad(degrees * _rng.randf_range(0.85, 1.15))
	player.head.rotation.x = clampf(player.head.rotation.x + kick, deg_to_rad(-85), deg_to_rad(85))
	player.rotate_y(deg_to_rad(degrees * _rng.randf_range(-0.2, 0.2)))
	_recoil_left += kick * RECOIL_RECOVER_SHARE


func _tick_recoil(delta: float) -> void:
	if _recoil_left <= 0.0:
		return
	var step: float = minf(_recoil_left, _recoil_left * RECOIL_RECOVERY * delta + 0.0005)
	_recoil_left -= step
	player.head.rotation.x = clampf(player.head.rotation.x - step, deg_to_rad(-85), deg_to_rad(85))
