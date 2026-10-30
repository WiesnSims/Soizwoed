class_name Hazards
extends Node3D
## The mine's hazards (DESIGN.md §4), made by the Mine on every peer from the seed:
## - Schlagende Wetter: firedamp pockets under the roof, seen only as a faint shimmer. A burning
##   carbide lamp flares up near one; one inside it for `gas_fuse_seconds` sets it off (host).
##   So do bangs and other explosions, which chains pockets.
## - Sole: brine pools that slow you and make the carbide burn faster (local, per player).
## - Steinschlag: the host now and then picks a spot near a miner: creaking, grit trickling,
##   then rock comes down, sometimes leaving a pile that blocks the tunnel until it is picked away.
## Rotten bridges and ladders are props of their chunks (RottenBridge, Ladder).

const SHIMMER: Shader = preload("res://world/hazards/gas_shimmer.gdshader")
const FLAME_CHECK_SECONDS: float = 0.1

var pockets: Array[GasPocket] = []
var pools: Array[Area3D] = []

var _config: BalanceConfig
var _mine: Mine
var _flame_left: float = 0.0
var _rockfall_left: float = 0.0
var _next_rubble: int = 0
## Host: where the last rockfall comes down (for dev checks).
var last_rockfall: Vector3 = Vector3.INF
## The local player's lamp was flaring last frame (for the whoosh).
var _was_flaring: bool = false


class GasPocket:
	extends Node3D
	var radius: float = 3.0
	var fuse: float = 0.0
	var gone: bool = false


func build(mine: Mine, shift: int, rule: BiomeRule) -> void:
	_config = Balance.config
	_mine = mine
	_rockfall_left = _config.rockfall_interval
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = mine.seed_value ^ 0x6a5
	var gas_share: float = minf(0.85, _config.gas_share_for_shift(shift) * rule.gas_mult)
	var index: int = 0
	for cell: Vector2i in mine.layout.cells:
		var chunk: Chunk = mine.chunks[cell]
		var entry: ChunkEntry = mine.chunk_set.entries[mine.layout.chunk_index[cell]]
		var deep: bool = mine.cell_depth(chunk) >= 2
		var roll: float = rng.randf()
		var centre: Vector3 = mine.cell_centre(cell)
		centre += CaveMesher.wander(centre, mine.seed_value)
		# No firedamp where a lantern burns: the old miners never hung one there.
		if deep and entry.hazards and roll < gas_share and chunk.find_children("*", "OmniLight3D", true, false).is_empty():
			_add_pocket(centre + Vector3.UP * 1.8, "Gas%d" % index)
		elif deep and entry.hazards and roll > 1.0 - rule.brine_share:
			_add_pool(centre, "Brine%d" % index)
		index += 1


func _add_pocket(at: Vector3, pocket_name: String) -> void:
	var pocket: GasPocket = GasPocket.new()
	pocket.name = pocket_name
	pocket.radius = _config.gas_radius
	var shell: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = pocket.radius
	sphere.height = pocket.radius * 1.3
	sphere.radial_segments = 24
	sphere.rings = 12
	shell.mesh = sphere
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SHIMMER
	shell.material_override = material
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pocket.add_child(shell)
	add_child(pocket)
	pocket.global_position = at
	pockets.append(pocket)


func _add_pool(at: Vector3, pool_name: String) -> void:
	var pool: Area3D = Area3D.new()
	pool.name = pool_name
	pool.collision_layer = Climbable.LAYER
	pool.collision_mask = 2
	pool.monitorable = false
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = _config.brine_radius
	cylinder.height = 1.0
	shape.shape = cylinder
	pool.add_child(shape)
	var water: MeshInstance3D = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = _config.brine_radius
	disc.bottom_radius = _config.brine_radius
	disc.height = 0.02
	disc.radial_segments = 28
	disc.rings = 1
	water.mesh = disc
	var surface: StandardMaterial3D = StandardMaterial3D.new()
	surface.albedo_color = Color(0.18, 0.2, 0.19, 0.82)
	surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surface.metallic_specular = 0.9
	surface.roughness = 0.04
	water.material_override = surface
	water.position = Vector3.UP * 0.1
	pool.add_child(water)
	pool.body_entered.connect(func(body: Node3D) -> void: if body is Player: (body as Player).in_brine = true)
	pool.body_exited.connect(func(body: Node3D) -> void: if body is Player: (body as Player).in_brine = false)
	add_child(pool)
	pool.global_position = at
	pools.append(pool)


func _physics_process(delta: float) -> void:
	if Game.instance == null or Game.instance.phase != Game.Phase.SHIFT:
		return
	_update_flares()
	if not multiplayer.is_server():
		return
	_flame_left -= delta
	if _flame_left <= 0.0:
		_flame_left = FLAME_CHECK_SECONDS
		_host_check_flames(FLAME_CHECK_SECONDS)
	_rockfall_left -= delta
	if _rockfall_left <= 0.0:
		_rockfall_left = _config.rockfall_interval * randf_range(0.7, 1.3)
		if randf() < _config.rockfall_chance:
			_host_rockfall()


# --- firedamp --------------------------------------------------------------------------------------

## Every peer: carbide lamps flare and turn bluish near a pocket (the miners' old warning sign).
func _update_flares() -> void:
	for player: Player in Game.instance.players():
		var flare: float = 0.0
		if player.has_open_flame():
			var head: Vector3 = player.global_position + Vector3.UP * 1.6
			for pocket: GasPocket in pockets:
				if pocket.gone:
					continue
				var edge: float = head.distance_to(pocket.global_position) - pocket.radius
				flare = maxf(flare, clampf(1.0 - edge / _config.gas_warning_distance, 0.0, 1.0))
		player.gas_flare = flare
		if player.is_local():
			var flaring: bool = flare > 0.3
			if flaring and not _was_flaring:
				Audio.play_at("gas_flare", player.lamp.global_position, &"SFX", -4.0, 12.0)
			_was_flaring = flaring


## Host: an open flame inside a pocket for long enough sets it off.
func _host_check_flames(step: float) -> void:
	for pocket: GasPocket in pockets:
		if pocket.gone:
			continue
		var lit: bool = false
		for player: Player in Game.instance.players():
			if player.has_open_flame() and (player.global_position + Vector3.UP * 1.6).distance_to(pocket.global_position) < pocket.radius:
				lit = true
		pocket.fuse = pocket.fuse + step if lit else maxf(0.0, pocket.fuse - step)
		if pocket.fuse >= _config.gas_fuse_seconds:
			host_explode(pocket)


## Host: a flame or blast at `where` reaching `radius`: every pocket it touches goes up.
func host_flame(where: Vector3, radius: float) -> void:
	for pocket: GasPocket in pockets:
		if not pocket.gone and pocket.global_position.distance_to(where) < pocket.radius + radius:
			host_explode(pocket)


func host_explode(pocket: GasPocket) -> void:
	if pocket.gone:
		return
	pocket.gone = true
	_explode.rpc(pockets.find(pocket))
	var game: Game = Game.instance
	game.host_noise(pocket.global_position, _config.noise_explosion)
	game.host_blast(pocket.global_position, _config.gas_explosion_radius, _config.gas_explosion_damage)
	print("[hazards] firedamp %s went up" % pocket.name)


@rpc("authority", "call_local", "reliable")
func _explode(index: int) -> void:
	if index < 0 or index >= pockets.size():
		return
	var pocket: GasPocket = pockets[index]
	pocket.gone = true
	pocket.visible = false
	Audio.play_at("explosion", pocket.global_position, &"SFX", 8.0, 90.0)
	var fire: OmniLight3D = OmniLight3D.new()
	fire.light_color = Color(1.0, 0.62, 0.3)
	fire.light_energy = 12.0
	fire.omni_range = _config.gas_explosion_radius * 2.0
	add_child(fire)
	fire.global_position = pocket.global_position
	var tween: Tween = fire.create_tween()
	tween.tween_property(fire, "light_energy", 0.0, 0.8)
	tween.tween_callback(fire.queue_free)
	_dust(pocket.global_position, 60, pocket.radius)
	var me: Player = Game.instance.local_player()
	if me != null:
		me.shake(clampf(1.0 - me.global_position.distance_to(pocket.global_position) / 30.0, 0.0, 1.0))


# --- rockfall --------------------------------------------------------------------------------------

## Host: somewhere near a miner (not in the station), the roof gives.
func _host_rockfall() -> void:
	var game: Game = Game.instance
	var miners: Array[Player] = []
	for player: Player in game.players():
		if player.alive and player.global_position.y < Game.HUB_FLOOR_ABOVE and not game.in_mine_cage(player.global_position) \
				and player.global_position.distance_to(_mine.station.global_position) > _mine.chunk_set.cell_size * 0.6:
			miners.append(player)
	if miners.is_empty():
		return
	var victim: Player = miners.pick_random()
	var spots: Array[int] = []
	for id: int in _mine.nav.get_point_ids():
		var d: float = _mine.nav.get_point_position(id).distance_to(victim.global_position)
		if d > 3.0 and d < 12.0 and not _mine.nav.is_point_disabled(id):
			spots.append(id)
	if spots.is_empty():
		return
	var spot: int = spots.pick_random()
	var at: Vector3 = _mine.nav.get_point_position(spot)
	var block: bool = randf() < _config.rockfall_block_chance and _can_block(spot)
	_next_rubble += 1
	var rubble_name: String = "Rubble%d" % _next_rubble if block else ""
	last_rockfall = at
	_rock_warn.rpc(at)
	print("[hazards] rockfall near P%d%s" % [victim.peer_id, " (blocks)" if block else ""])
	await get_tree().create_timer(_config.rockfall_warning_seconds).timeout
	if not is_inside_tree():
		return
	for player: Player in game.players():
		if player.global_position.distance_to(at) < _mine.chunk_set.passage_size.x:
			rubble_name = ""  # never bury anyone inside the pile
	_rock_fall.rpc(at, rubble_name, _tunnel_yaw(spot))
	for player: Player in game.players():
		var flat: Vector2 = Vector2(player.global_position.x - at.x, player.global_position.z - at.z)
		if flat.length() < _config.rockfall_radius and absf(player.global_position.y - at.y) < 2.5:
			game.host_damage_player(player, _config.rockfall_damage)
	for creature: Creature in game.creatures():
		if creature.global_position.distance_to(at) < _config.rockfall_radius:
			creature.host_hit(_config.rockfall_damage, at)
	game.host_noise(at, _config.noise_heavy_drop)


## Only block a tunnel if every miner still has a way back to the lift around it.
func _can_block(spot: int) -> bool:
	var game: Game = Game.instance
	var lift: int = _mine.nav.get_closest_point(game.mine_cage.global_position)
	if lift == spot or _mine.nav.get_point_connections(spot).size() > 2:
		return false  # never the lift, never a crossing
	_mine.nav.set_point_disabled(spot, true)
	var ok: bool = true
	for player: Player in game.players():
		if player.alive and player.global_position.y < Game.HUB_FLOOR_ABOVE:
			var from: int = _mine.nav.get_closest_point(player.global_position)
			if from != spot and _mine.nav.get_id_path(from, lift).is_empty():
				ok = false
	_mine.nav.set_point_disabled(spot, false)
	return ok


## Which way the tunnel runs at a waypoint (yaw of a wall across it).
func _tunnel_yaw(spot: int) -> float:
	var links: PackedInt64Array = _mine.nav.get_point_connections(spot)
	if links.is_empty():
		return 0.0
	var along: Vector3 = _mine.nav.get_point_position(links[0]) - _mine.nav.get_point_position(spot)
	return atan2(along.x, along.z)


@rpc("authority", "call_local", "reliable")
func _rock_warn(at: Vector3) -> void:
	Audio.play_at("rockfall_warn", at + Vector3.UP * 3.0, &"SFX", 2.0, 35.0)
	_trickle(at)


@rpc("authority", "call_local", "reliable")
func _rock_fall(at: Vector3, rubble_name: String, yaw: float) -> void:
	Audio.play_at("rockfall", at + Vector3.UP * 2.0, &"SFX", 6.0, 60.0)
	_dust(at + Vector3.UP * 1.0, 50, _config.rockfall_radius)
	var me: Player = Game.instance.local_player()
	if me != null:
		me.shake(clampf(1.0 - me.global_position.distance_to(at) / 20.0, 0.0, 0.8))
	if rubble_name == "":
		_scatter_stones(at)
		return
	var pile: Breakable = Breakable.new()
	pile.name = rubble_name
	pile.kind = Breakable.Kind.RUBBLE
	pile.size = Vector3(_mine.chunk_set.passage_size.x + 1.6, _mine.chunk_set.passage_size.y + 0.6, 1.6)
	pile.rotation.y = yaw
	add_child(pile)
	pile.global_position = at - Vector3.UP * 0.1
	var spot: int = _mine.nav.get_closest_point(at)
	_mine.nav.set_point_disabled(spot, true)
	pile.nav_point = spot


## A few loose stones left on the floor where the roof came down.
func _scatter_stones(at: Vector3) -> void:
	var rock: Material = load("res://assets/materials/salt_rock.tres") as Material
	for i: int in 6:
		var stone: MeshInstance3D = MeshInstance3D.new()
		var ball: SphereMesh = SphereMesh.new()
		ball.radius = randf_range(0.12, 0.3)
		ball.height = ball.radius * 1.3
		ball.radial_segments = 8
		ball.rings = 4
		stone.mesh = ball
		stone.material_override = rock
		add_child(stone)
		stone.global_position = at + Vector3(randf_range(-1.2, 1.2), 0.08, randf_range(-1.2, 1.2))


## Grit trickling from the roof: the warning before a rockfall.
func _trickle(at: Vector3) -> void:
	var grit: CPUParticles3D = _particles(40, 2.5, Color(0.7, 0.66, 0.6, 0.9))
	grit.emission_box_extents = Vector3(1.2, 0.1, 1.2)
	grit.direction = Vector3.DOWN
	grit.spread = 10.0
	grit.initial_velocity_min = 0.5
	grit.initial_velocity_max = 1.5
	grit.explosiveness = 0.0
	grit.lifetime = 1.4
	add_child(grit)
	grit.global_position = at + Vector3.UP * 3.0
	grit.emitting = true


func _dust(at: Vector3, amount: int, spread: float) -> void:
	var dust: CPUParticles3D = _particles(amount, 2.4, Color(0.78, 0.74, 0.68, 0.55))
	dust.emission_box_extents = Vector3.ONE * spread * 0.5
	dust.direction = Vector3.UP
	dust.spread = 180.0
	dust.initial_velocity_min = 0.3
	dust.initial_velocity_max = 2.0
	dust.scale_amount_min = 0.2
	dust.scale_amount_max = 0.6
	add_child(dust)
	dust.global_position = at
	dust.emitting = true


func _particles(amount: int, lifetime: float, color: Color) -> CPUParticles3D:
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.one_shot = true
	particles.amount = amount
	particles.lifetime = lifetime
	particles.explosiveness = 0.8
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.scale_amount_min = 0.04
	particles.scale_amount_max = 0.12
	particles.color = color
	var grain: SphereMesh = SphereMesh.new()
	grain.radius = 0.5
	grain.height = 1.0
	grain.radial_segments = 4
	grain.rings = 2
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grain.material = material
	particles.mesh = grain
	particles.finished.connect(particles.queue_free)
	return particles
