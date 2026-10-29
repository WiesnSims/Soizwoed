extends Node
## Dev tool: scripted situations to watch the game do something specific, for checks without a
## human at the keyboard. Added by Game when started with `-- --solo --scenario=<name>`; pair
## it with `--shots=<dir>` (screenshots) and `--smoke=<seconds>` (quit).
##   mandl  – a salt crystal in the station, a Bergmandl comes for it; later the player shouts.
##   cart   – in the Gasthaus: loads loot into the Schubkarre (E, G, dropped onto it), pushes it
##            around, checks the load stays on.
##   look   – a Bergmandl standing still right in front of the player (for screenshots).
##   loot   – the player fetches the three nearest loot items into the Förderkorb, rides up,
##            and they get sold.
##   coop   – host with one ENet client (`--wait-peers=1`): drops a crystal from above, carries
##            a salt block together with the client, hands it over, then the client dies.
##   coopclient – the client side of coop: logs what it sees of all that.

var _game: Game
var _log_left: float = 0.0


func run(game: Game, scenario: String) -> void:
	_game = game
	print("[scenario] %s" % scenario)
	while _game.phase != Game.Phase.HUB:
		await get_tree().process_frame
	if scenario == "cart":
		await _cart()
		return
	if scenario == "coopclient":
		await _coop_client()
		return
	if scenario == "coop":
		# Already in a pocket before the client joins: the join snapshot must say so.
		var pick: WorldItem = _game._spawn_item_at(&"spitzhacke", 0, _game.hub.counter_spot(), "ITestPick")
		await get_tree().create_timer(0.5).timeout
		_game.request_take(pick.get_path(), _game.local_player().peer_id)
		while _game._ready_peers.size() < 2:
			await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	_game.request_lift()
	while _game.phase != Game.Phase.SHIFT:
		await get_tree().process_frame
	match scenario:
		"mandl":
			await _mandl()
		"loot":
			await _loot()
		"look":
			await _look()
		"coop":
			await _coop()
		"tatzel":
			await _tatzel()
		"kaser":
			await _kaser()
		"meister":
			await _meister()
		"tools":
			await _tools()
		_:
			push_warning("unknown scenario %s" % scenario)


func _process(delta: float) -> void:
	if _game == null or _game.phase != Game.Phase.SHIFT:
		return
	_log_left -= delta
	if _log_left > 0.0:
		return
	_log_left = 0.5
	var player: Player = _game.local_player()
	for creature: Creature in _game.creatures():
		var mandl: Bergmandl = creature as Bergmandl
		var where: Vector3 = creature.global_position.snapped(Vector3.ONE * 0.1)
		var distance: float = creature.global_position.distance_to(player.global_position) if player != null else -1.0
		if mandl != null:
			print("[scenario] %s %s at %s carrying %s" % [mandl.name, Bergmandl.State.keys()[mandl.state], where, mandl.carried.name if mandl.carried != null else "-"])
		elif creature is Tatzelwurm:
			var wurm: Tatzelwurm = creature as Tatzelwurm
			print("[scenario] tatzelwurm %s emerge %.1f %.1f m away, player health %d" % [Tatzelwurm.State.keys()[wurm.state], wurm.net_emerge, distance, player.health])
		elif creature is Kasermandl:
			var kaser: Kasermandl = creature as Kasermandl
			print("[scenario] kasermandl lit %s %s %.1f m away, player health %d" % [kaser.net_lit, Kasermandl.State.keys()[kaser.state], distance, player.health])
		elif creature is Schichtmeister:
			print("[scenario] schichtmeister %.1f m away, in cage %s, player alive %s" % [distance, _game.in_mine_cage(creature.global_position), player.alive])


func _mandl() -> void:
	for creature: Creature in _game.creatures():
		creature.queue_free()
	var cage: Foerderkorb = _game.mine_cage
	var forward: Vector3 = -cage.global_basis.z
	var crystal_at: Vector3 = cage.global_position + forward * 4.5 + Vector3.UP * 0.4
	_game._spawn_item_at(&"salzkristall", 20, Transform3D(Basis.IDENTITY, crystal_at))
	var mandl_at: Vector3 = cage.global_position + forward * 11.0 + Vector3.UP * 0.3
	_game._creature_spawner.spawn(["CTest", &"bergmandl", Transform3D(Basis.IDENTITY, mandl_at)])
	await get_tree().create_timer(9.0).timeout
	var player: Player = _game.local_player()
	print("[scenario] player shouts")
	_game.request_shout(player.peer_id, player.global_position)


func _loot() -> void:
	for creature: Creature in _game.creatures():
		creature.queue_free()
	var player: Player = _game.local_player()
	var cage: Foerderkorb = _game.mine_cage
	var loot: Array[WorldItem] = []
	for item: WorldItem in _game._items():
		if item.is_loot() and item.global_position.y < Game.HUB_FLOOR_ABOVE:
			loot.append(item)
	loot.sort_custom(func(a: WorldItem, b: WorldItem) -> bool: return a.global_position.distance_to(cage.global_position) < b.global_position.distance_to(cage.global_position))
	var carried: int = 0
	for item: WorldItem in loot:
		if carried >= 3:
			break
		player.teleport(Transform3D(Basis.IDENTITY, item.global_position + Vector3(0.0, 0.2, 0.8)))
		await get_tree().create_timer(0.4).timeout
		if player.inventory.place_for(item.data.weight_class) == Inventory.NONE:
			continue
		_game.request_take(item.get_path(), player.peer_id)
		await get_tree().create_timer(0.3).timeout
		print("[scenario] took %s (%s, %d S), state %s" % [item.data.id, ItemData.WeightClass.keys()[item.data.weight_class], item.value, WorldItem.State.keys()[item.state]])
		carried += 1
		if player.inventory.hands != null:
			player.teleport(cage.player_spot(1))
			await get_tree().create_timer(0.4).timeout
			_game.request_drop(item.get_path(), cage.player_spot(0), Vector3.ZERO)
			await get_tree().create_timer(0.3).timeout
			print("[scenario] dropped %s in the cage: %s" % [item.data.id, cage.contains(item.global_position)])
	player.teleport(cage.player_spot(2))
	await get_tree().create_timer(0.5).timeout
	print("[scenario] inventory: %s" % [player.inventory.all_items().map(func(i: Object) -> String: return (i as WorldItem).data.id)])
	_game.request_lift()
	while _game.phase != Game.Phase.HUB:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	print("[scenario] back in the Gasthaus, money %d, inventory %d" % [GameState.run.money, player.inventory.all_items().size()])


func _cart() -> void:
	await get_tree().create_timer(0.5).timeout
	var player: Player = _game.local_player()
	var cart: Schubkarre = null
	for item: WorldItem in _game._items():
		if item is Schubkarre:
			cart = item
	var spot: Transform3D = cart.global_transform.translated(Vector3(0, 0.5, 0))
	var lamp: WorldItem = _game._spawn_item_at(&"antike_grubenlampe", 50, spot.translated(Vector3(1.5, 0, 0)))
	var crystal: WorldItem = _game._spawn_item_at(&"salzkristall", 20, spot.translated(Vector3(-1.5, 0, 0)))
	await get_tree().create_timer(1.0).timeout
	_game.request_take(lamp.get_path(), player.peer_id)
	await get_tree().create_timer(0.3).timeout
	cart.try_load_from(player)
	await get_tree().create_timer(0.3).timeout
	# Dropped onto the parked barrow: lands in the bed and gets loaded.
	var dropped: WorldItem = _game._spawn_item_at(&"salzkristall", 15, cart.global_transform.translated(Vector3(0, 1.0, 0)))
	# From the pocket with G, aimed at the barrow.
	var pocket: WorldItem = _game._spawn_item_at(&"kaiserliches_abzeichen", 150, player.global_transform.translated(Vector3(0, 0.5, 0)))
	await get_tree().create_timer(1.5).timeout
	_game.request_take(pocket.get_path(), player.peer_id)
	await get_tree().create_timer(0.3).timeout
	player.focus = cart
	player._drop_active()
	await get_tree().create_timer(0.3).timeout
	print("[scenario] dropped onto barrow: %s, pocket with G: %s, cargo %d" % [WorldItem.State.keys()[dropped.state], WorldItem.State.keys()[pocket.state], cart.cargo.size()])
	if pocket.state == WorldItem.State.CARTED:
		_game.request_take(pocket.get_path(), player.peer_id)
	await get_tree().create_timer(0.3).timeout
	_game.request_take(cart.get_path(), player.peer_id)
	await get_tree().create_timer(0.3).timeout
	_game.request_load_cart(cart.get_path(), crystal.get_path())
	await get_tree().create_timer(0.3).timeout
	print("[scenario] cargo %d, lamp %s, crystal %s" % [cart.cargo.size(), WorldItem.State.keys()[lamp.state], WorldItem.State.keys()[crystal.state]])
	var start: Vector3 = player.global_position
	for i: int in 120:
		player.velocity = Vector3(3.0, 0.0, 0.0) if i < 60 else Vector3(-3.0, 0.0, 0.0)
		player.global_position = start + Vector3(0.05 * (i if i < 60 else 120 - i), 0.0, 0.0)
		player.rotate_y(0.03)
		await get_tree().physics_frame
	await get_tree().create_timer(0.5).timeout
	for item: WorldItem in [lamp, crystal, dropped]:
		print("[scenario] %s %s, %.2f m from its slot" % [item.data.id, WorldItem.State.keys()[item.state], item.global_position.distance_to(item.follow.global_position) if item.follow != null else -1.0])


func _look() -> void:
	for creature: Creature in _game.creatures():
		creature.queue_free()
	var cage: Foerderkorb = _game.mine_cage
	var player: Player = _game.local_player()
	var forward: Vector3 = -cage.global_basis.z
	var at: Vector3 = player.global_position + forward * 1.6
	var mandl: Creature = _game._creature_spawner.spawn(["CLook", &"bergmandl", Transform3D(cage.global_basis.rotated(Vector3.UP, PI), at)]) as Creature
	mandl.set_physics_process(false)
	player.head.rotation.x = -0.45


func _coop() -> void:
	for creature: Creature in _game.creatures():
		creature.queue_free()
	var cage: Foerderkorb = _game.mine_cage
	var forward: Vector3 = -cage.global_basis.z
	var host: Player = _game.local_player()
	var client: Player = null
	for player: Player in _game.players():
		if player != host:
			client = player
	await get_tree().create_timer(1.0).timeout
	var fall_at: Vector3 = cage.global_position + forward * 3.0 + Vector3.UP * 2.5
	var falling: WorldItem = _game._spawn_item_at(&"salzkristall", 20, Transform3D(Basis.IDENTITY, fall_at), "ITestFall")
	await get_tree().create_timer(3.0).timeout
	print("[scenario] host: ITestFall fell %.2f m" % (fall_at.y - falling.global_position.y))
	# Thrown while walking forward: the client must see the same arc.
	var thrown: WorldItem = _game._spawn_item_at(&"salzkristall", 20, host.global_transform.translated(Vector3.UP * 1.0), "ITestThrow")
	await get_tree().create_timer(0.5).timeout
	_game.request_take(thrown.get_path(), host.peer_id)
	await get_tree().create_timer(0.5).timeout
	_track(thrown, "host")
	_game.request_drop(thrown.get_path(), host.hand_point.global_transform, forward * 2.0 + forward * Balance.config.walk_speed)
	await get_tree().create_timer(2.0).timeout
	# Now the client throws one (coopclient picks it up and throws it while walking).
	var client_thrown: WorldItem = _game._spawn_item_at(&"salzkristall", 20, client.global_transform.translated(Vector3.UP * 1.0), "ITestThrow2")
	_track(client_thrown, "host", "ITestThrow2")
	await get_tree().create_timer(3.5).timeout
	var block: WorldItem = _game._spawn_item_at(&"steinsalz_block", 120, host.global_transform.translated(forward * 1.0 + Vector3.UP * 0.3), "ITestBlock")
	await get_tree().create_timer(1.0).timeout
	_game.request_take(block.get_path(), host.peer_id)
	client.teleport.rpc(host.global_transform.translated(host.global_basis.x * 1.0))
	await get_tree().create_timer(1.0).timeout
	_game.host_help_carry(block, client)
	await get_tree().create_timer(1.5).timeout
	print("[scenario] host: block holder %d helper %d, speed %.2f" % [block.holder_peer, block.helper_peer, host.inventory.speed_factor(Balance.config)])
	_game.request_drop(block.get_path(), host.hold_point.global_transform, Vector3.ZERO)
	await get_tree().create_timer(1.5).timeout
	print("[scenario] host: after letting go, block holder %d helper %d" % [block.holder_peer, block.helper_peer])
	_game.host_damage_player(client, 1000)
	await get_tree().create_timer(5.0).timeout
	var corpses: int = 0
	for item: WorldItem in _game._items():
		corpses += 1 if item.data.id == &"leiche" else 0
	print("[scenario] host: %d corpse(s), client alive %s" % [corpses, client.alive])
	host.teleport(cage.player_spot(0))
	await get_tree().create_timer(0.5).timeout
	_game.request_lift()


## A point along the tunnel out of the station, `metres` from the cage (on the waypoint graph).
func _out_of_station(metres: float) -> Vector3:
	var cage: Foerderkorb = _game.mine_cage
	var target: Vector3 = cage.global_position - cage.global_basis.z * metres
	var nav: AStar3D = _game.mine.nav
	return nav.get_point_position(nav.get_closest_point(target)) + Vector3.UP * 0.1


func _tatzel() -> void:
	for creature: Creature in _game.creatures():
		creature.queue_free()
	var player: Player = _game.local_player()
	var stand: Vector3 = _out_of_station(8.0)
	player.teleport(Transform3D(_game.mine_cage.global_basis, stand))
	await get_tree().create_timer(0.5).timeout
	_game.spawn_creature(&"tatzelwurm", Transform3D(Basis.IDENTITY, _out_of_station(20.0) + Vector3.UP * 0.3))
	await get_tree().create_timer(1.0).timeout
	print("[scenario] player sprints")
	for i: int in 3:
		_game.host_noise(player.global_position, Balance.config.noise_sprint)
		await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(5.0).timeout
	print("[scenario] player runs past it")
	for i: int in 40:
		player.velocity = Vector3(Balance.config.sprint_speed, 0.0, 0.0)
		await get_tree().physics_frame


func _kaser() -> void:
	for creature: Creature in _game.creatures():
		creature.queue_free()
	var player: Player = _game.local_player()
	player.teleport(Transform3D(_game.mine_cage.global_basis, _out_of_station(8.0)))
	for light: OmniLight3D in _game.mine.lights:
		light.visible = false  # only the lamp counts in this check
	await get_tree().create_timer(0.5).timeout
	_game.spawn_creature(&"kasermandl", Transform3D(Basis.IDENTITY, _out_of_station(24.0) + Vector3.UP * 0.3))
	await get_tree().create_timer(7.0).timeout
	print("[scenario] lamp off")
	player.lamp_on = false


func _meister() -> void:
	for creature: Creature in _game.creatures():
		creature.queue_free()
	var player: Player = _game.local_player()
	player.teleport(Transform3D(_game.mine_cage.global_basis, _out_of_station(14.0)))
	_game.shift_time_left = 0.5
	await get_tree().create_timer(Balance.config.schichtmeister_delay + 20.0).timeout


## Gives the local player a fresh `id` in the selected pocket slot.
func _give(id: StringName) -> WorldItem:
	var player: Player = _game.local_player()
	var item: WorldItem = _game._spawn_item_at(id, 0, player.global_transform.translated(Vector3.UP * 1.0))
	await get_tree().create_timer(0.3).timeout
	player.inventory.select(player.inventory.slots.find(null))
	_game.request_take(item.get_path(), player.peer_id)
	await get_tree().create_timer(0.2).timeout
	return item


func _tools() -> void:
	for creature: Creature in _game.creatures():
		creature.queue_free()
	var player: Player = _game.local_player()
	var config: BalanceConfig = Balance.config
	player.teleport(Transform3D(_game.mine_cage.global_basis, _out_of_station(8.0)))
	await get_tree().create_timer(0.5).timeout
	# Stirnlampe: switch over, the carbide lamp is no open flame any more.
	await _give(&"stirnlampe")
	player._use_active()
	await get_tree().create_timer(0.3).timeout
	print("[scenario] stirnlampe electric %s, open flame %s, battery %.0f" % [player.lamp_electric, player.has_open_flame(), player.battery])
	player._use_cooldown = 0.0
	# Obstler and Leberkässemmel heal.
	player.set_health(30)
	await _give(&"obstler")
	player._use_active()
	await get_tree().create_timer(0.4).timeout
	print("[scenario] obstler: health %d, wobble %.0f s" % [player.health, player._wobble_left])
	player._use_cooldown = 0.0
	await _give(&"leberkaessemmel")
	player._use_active()
	await get_tree().create_timer(config.leberkaese_eat_seconds + 0.5).timeout
	print("[scenario] leberkaessemmel: health %d" % player.health)
	# Alphorn: a Bergmandl in front stands dazed.
	var forward: Vector3 = -player.camera.global_basis.z
	var mandl: Creature = _game.spawn_creature(&"bergmandl", Transform3D(Basis.IDENTITY, _game.mine.nav.get_point_position(_game.mine.nav.get_closest_point(player.global_position + forward * 6.0)) + Vector3.UP * 0.3))
	await get_tree().create_timer(0.5).timeout
	player.head.rotation.x = 0.0
	player.look_at(Vector3(mandl.global_position.x, player.global_position.y, mandl.global_position.z))
	await _give(&"alphorn")
	var eyes: Vector3 = player.camera.global_position
	print("[scenario] alphorn: mandl %.1f m ahead, in cone %s, clear %s" % [eyes.distance_to(mandl.global_position),
			Game.in_cone(eyes, -player.camera.global_basis.z, mandl.global_position + Vector3.UP * 0.8, config.alphorn_range, config.alphorn_cone_degrees),
			_game.clear_line(eyes, mandl.global_position + Vector3.UP * 0.8)])
	player._use_active()
	await get_tree().create_timer(0.3).timeout
	print("[scenario] alphorn: mandl stunned %.1f s" % mandl.stunned_left)
	# Böller: thrown, goes off, the Bergmandl runs.
	player._use_cooldown = 0.0
	await _give(&"boeller")
	player._use_active()
	await get_tree().create_timer(config.boeller_fuse_seconds + 0.5).timeout
	print("[scenario] boeller gone off: %s" % (_count(&"boeller") == 0))
	# Rauchbombe: a cloud creatures avoid.
	player._use_cooldown = 0.0
	await _give(&"rauchbombe")
	player._use_active()
	await get_tree().create_timer(config.rauchbombe_fuse_seconds + 1.0).timeout
	print("[scenario] rauchbombe: smoke zones %d" % _game._smokes.size())
	# Pfeiferl: the Hunt rolls over from the lift.
	var cart: RailCart = null
	for item: WorldItem in _game._items():
		if item is RailCart:
			cart = item
	if cart == null:
		print("[scenario] no rail cart in this mine")
		return
	var far: Vector3 = _game.mine.rails.transform_at(_game.mine.rails.length() * 0.6).origin
	player.teleport(Transform3D(Basis.IDENTITY, far + Vector3(0.0, 0.1, 0.0)))
	await get_tree().create_timer(0.5).timeout
	var start: float = cart.global_position.distance_to(player.global_position)
	player._use_cooldown = 0.0
	await _give(&"pfeiferl")
	player._use_active()
	await get_tree().create_timer(0.5).timeout
	for i: int in 200:
		if not cart.moving:
			break
		await get_tree().create_timer(0.1).timeout
	print("[scenario] pfeiferl: hunt came from %.1f m to %.1f m" % [start, cart.global_position.distance_to(player.global_position)])
	# Load it and push it back towards the lift.
	var block: WorldItem = _game._spawn_item_at(&"steinsalz_block", 100, player.global_transform.translated(Vector3.UP * 0.5))
	await get_tree().create_timer(0.4).timeout
	_game.request_load_cart(cart.get_path(), block.get_path())
	await get_tree().create_timer(0.3).timeout
	_game.request_push_rail(cart.get_path())
	await get_tree().create_timer(0.2).timeout
	var before: float = cart.s
	var toward_lift: Vector3 = _game.mine.rails.transform_at(0.0).origin
	for i: int in 60:
		var step: Vector3 = (toward_lift - player.global_position)
		step.y = 0.0
		player.global_position += step.normalized() * config.walk_speed * 0.8 / 60.0
		await get_tree().physics_frame
	await get_tree().create_timer(0.5).timeout
	print("[scenario] pushed hunt from %.1f to %.1f, pusher P%d, cargo %d" % [before, cart.s, cart.pusher_peer, cart.cargo.size()])
	# A salt wall broken with the pick.
	var walls: Array[Node] = get_tree().get_nodes_in_group(&"breakables")
	if walls.is_empty():
		var test_wall: Breakable = Breakable.new()
		test_wall.name = "WallTest"
		_game.mine.add_child(test_wall)
		test_wall.global_position = player.global_position + Vector3(0.0, -0.1, -3.0)
		walls.append(test_wall)
		await get_tree().physics_frame
	var wall: Breakable = walls[0] as Breakable
	player.teleport(Transform3D(Basis.IDENTITY, wall.global_position + wall.global_basis.z * 1.2 + Vector3.UP * 0.1))
	await _give(&"spitzhacke")
	var hits: int = 0
	while wall.health > 0 and hits < 10:
		_game.request_break(wall.get_path(), 34)
		hits += 1
		await get_tree().create_timer(0.1).timeout
	print("[scenario] salt wall broken after %d hits: %s" % [hits, wall.health <= 0])


func _count(id: StringName) -> int:
	var count: int = 0
	for item: WorldItem in _game._items():
		count += 1 if item.data.id == id else 0
	return count


func _coop_client() -> void:
	await get_tree().create_timer(1.0).timeout
	var pick: WorldItem = _game.items_root.get_node_or_null(^"ITestPick") as WorldItem
	if pick != null:
		print("[scenario] client sees ITestPick %s by P%d" % [WorldItem.State.keys()[pick.state], pick.holder_peer])
	while _game.phase != Game.Phase.SHIFT:
		await get_tree().process_frame
	var me: Player = _game.local_player()
	var seen: Dictionary = {}
	_track_when_thrown()
	var fall_start: float = INF
	for i: int in 80:
		await get_tree().create_timer(0.25).timeout
		if _game.phase != Game.Phase.SHIFT:
			break
		var falling: WorldItem = _game.items_root.get_node_or_null(^"ITestFall") as WorldItem
		if falling != null:
			if fall_start == INF:
				fall_start = falling.global_position.y
			if fall_start - falling.global_position.y > 1.0 and not seen.has("fall"):
				seen.fall = true
				print("[scenario] client saw ITestFall fall %.2f m" % (fall_start - falling.global_position.y))
		var block: WorldItem = _game.items_root.get_node_or_null(^"ITestBlock") as WorldItem
		if block != null and block.helper_peer == me.peer_id and not seen.has("helper"):
			seen.helper = true
			print("[scenario] client carrying together with P%d, speed %.2f" % [block.holder_peer, me.inventory.speed_factor(Balance.config)])
		if block != null and block.holder_peer == me.peer_id and seen.has("helper") and not seen.has("holder"):
			seen.holder = true
			print("[scenario] client took the block over")
		if not me.alive and me.spectating != null and not seen.has("dead"):
			seen.dead = true
			print("[scenario] client dead, spectating P%d" % me.spectating.peer_id)


## Logs where a thrown item flies, every 0.1 s from the moment it is let go (host and client).
func _track(item: WorldItem, who: String, label: String = "ITestThrow") -> void:
	while item.state == WorldItem.State.FREE:
		await get_tree().process_frame
	while item.state != WorldItem.State.FREE:
		await get_tree().process_frame
	var start: Vector3 = item.global_position
	var path: PackedStringArray = []
	for i: int in 16:
		var offset: Vector3 = item.global_position - start
		path.append("%.2f/%.2f" % [Vector2(offset.x, offset.z).length(), offset.y])
		await get_tree().create_timer(0.1).timeout
	var flat: Vector3 = item.global_position - start
	print("[scenario] %s: %s path %s" % [who, label, " ".join(path)])
	print("[scenario] %s: %s flew %.2f m" % [who, label, Vector2(flat.x, flat.z).length()])


func _track_when_thrown() -> void:
	var item: WorldItem = null
	while item == null or item.state == WorldItem.State.FREE:
		await get_tree().process_frame
		item = _game.items_root.get_node_or_null(^"ITestThrow") as WorldItem
	await _track(item, "client")
	# The client's own throw, walking forward.
	while _game.items_root.get_node_or_null(^"ITestThrow2") == null:
		await get_tree().process_frame
	var mine: WorldItem = _game.items_root.get_node_or_null(^"ITestThrow2") as WorldItem
	var me: Player = _game.local_player()
	await get_tree().create_timer(0.5).timeout
	_game.request_take.rpc_id(1, mine.get_path(), me.peer_id)
	_track(mine, "client", "ITestThrow2")
	await get_tree().create_timer(0.3).timeout
	# Walk (real input) and throw with the drop key, as a player would.
	Input.action_press(&"move_forward")
	await get_tree().create_timer(0.6).timeout
	me._drop_active()
	await get_tree().create_timer(0.4).timeout
	Input.action_release(&"move_forward")
