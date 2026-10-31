class_name Flare
extends Node3D
## A Leuchtkugel from the Leuchtpistole (DESIGN.md §7). Every peer flies the same arc from the
## same start and velocity (slow and heavy, a bright red star with a trail); the host's copy
## decides what it hits: a creature gets hurt and catches fire, a miner gets the friendly-fire
## share. Then it drops and lies burning for a while: it lights the tunnel red (a Kasermandl in
## the light freezes and can be shot), sets fire to creatures that step into it and sets off
## firedamp. Game keeps the list of burning flares (Game.flares).

const RADIUS: float = 0.04
const MAX_BOUNCES: int = 3
## Its own flight is lit too, a little less.
const FLIGHT_LIGHT_SHARE: float = 0.6
const TICK_SECONDS: float = 0.5

var velocity: Vector3 = Vector3.ZERO
## Who fired it (peer id), never hit by their own flare.
var shooter: int = 0
## Seconds it has left to burn.
var burn_left: float = 20.0

var _config: BalanceConfig
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _bounces: int = 0
var _resting: bool = false
var _exclude: Array[RID] = []
var _light: OmniLight3D
var _hiss: AudioStreamPlayer3D
var _sparks: CPUParticles3D
var _tick_left: float = 0.0


func _ready() -> void:
	_config = Balance.config
	burn_left = _config.flare_light_seconds
	var star: StandardMaterial3D = BodyParts.glow(Color(1.0, 0.25, 0.15), 8.0)
	BodyParts.add(self, BodyParts.sphere(RADIUS, 8), star, Vector3.ZERO)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.32, 0.22)
	_light.light_energy = 3.0
	_light.omni_range = _config.flare_light_range * FLIGHT_LIGHT_SHARE
	_light.omni_attenuation = 1.4
	_light.shadow_enabled = true
	add_child(_light)
	_sparks = CPUParticles3D.new()
	_sparks.amount = 40
	_sparks.lifetime = 0.7
	_sparks.local_coords = false
	_sparks.direction = Vector3.UP
	_sparks.spread = 60.0
	_sparks.gravity = Vector3(0.0, -3.0, 0.0)
	_sparks.initial_velocity_min = 0.2
	_sparks.initial_velocity_max = 1.2
	_sparks.scale_amount_min = 0.015
	_sparks.scale_amount_max = 0.035
	var spark: SphereMesh = BodyParts.sphere(0.5, 4)
	spark.material = BodyParts.glow(Color(1.0, 0.45, 0.25), 5.0)
	_sparks.mesh = spark
	add_child(_sparks)
	_hiss = AudioStreamPlayer3D.new()
	_hiss.bus = &"SFX"
	_hiss.max_distance = 22.0
	_hiss.unit_size = 3.0
	_hiss.volume_db = -6.0
	add_child(_hiss)
	var burn: AudioStreamOggVorbis = Audio.stream("flare_burn") as AudioStreamOggVorbis
	if burn != null:
		burn.loop = true
		_hiss.stream = burn
		_hiss.play()
	if Game.instance != null:
		Game.instance.flares.append(self)
		var own: Player = Game.instance.player_by_peer(shooter)
		if own != null:
			_exclude.append(own.get_rid())


func _exit_tree() -> void:
	if Game.instance != null:
		Game.instance.flares.erase(self)


func _process(_delta: float) -> void:
	# A flare flickers and spits.
	var full: float = _config.flare_light_range * (1.0 if _resting else FLIGHT_LIGHT_SHARE)
	var dying: float = clampf(burn_left / 2.0, 0.0, 1.0)
	_light.omni_range = full * lerpf(0.4, 1.0, dying)
	_light.light_energy = randf_range(2.4, 3.4) * dying


func _physics_process(delta: float) -> void:
	burn_left -= delta
	if burn_left <= 0.0:
		queue_free()
		return
	if multiplayer.is_server():
		_host_tick(delta)
	if _resting:
		return
	velocity.y -= _gravity * _config.flare_gravity_share * delta
	var from: Vector3 = global_position
	var to: Vector3 = from + velocity * delta
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1 | 2 | 8)
	query.exclude = _exclude
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		return
	var creature: Creature = _creature_of(hit.collider as Node)
	var player: Player = hit.collider as Player
	if creature != null or player != null:
		# Into flesh: it hurts, then drops from there.
		global_position = hit.position
		_exclude.append((hit.collider as CollisionObject3D).get_rid())
		velocity = Vector3(0.0, -1.0, 0.0)
		if multiplayer.is_server() and Game.instance != null:
			if creature != null and not creature.is_queued_for_deletion():
				creature.host_flared(_config.flare_damage, global_position - (to - from))
				print("[flare] hit %s" % creature.data.id)
			elif player != null:
				Game.instance.host_damage_player(player, WeaponMath.friendly_damage(_config.flare_damage, _config.friendly_fire))
		return
	var normal: Vector3 = hit.normal
	global_position = (hit.position as Vector3) + normal * RADIUS
	_bounces += 1
	if normal.y > 0.6 or _bounces >= MAX_BOUNCES:
		_rest()
	else:
		velocity = velocity.bounce(normal) * 0.3


func _rest() -> void:
	_resting = true
	velocity = Vector3.ZERO
	Audio.play_at("stone_hit", global_position, &"SFX", -10.0, 10.0, 1.4)


## Host: firedamp next to it goes up, creatures that come too close catch fire.
func _host_tick(delta: float) -> void:
	_tick_left -= delta
	if _tick_left > 0.0 or Game.instance == null:
		return
	_tick_left = TICK_SECONDS
	Game.instance.host_flame(global_position, 0.8)
	if not _resting:
		return
	for creature: Creature in Game.instance.creatures():
		if creature.global_position.distance_to(global_position) < _config.flare_ignite_radius and not creature.is_queued_for_deletion():
			creature.host_ignite(_config.flare_burn_seconds * 0.6, _config.flare_burn_dps)


## Whether its light reaches `point`: in range and no rock in between.
func lights_point(point: Vector3, share: float = 0.9) -> bool:
	if global_position.distance_to(point) > _light.omni_range * share:
		return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.1, point, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _creature_of(node: Node) -> Creature:
	while node != null and not node is Creature:
		node = node.get_parent()
	return node as Creature
