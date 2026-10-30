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
	if scenario == "settings":
		_game.hud._open_settings()  # for screenshots of its layout
		return
	if scenario == "hublook":
		# The notice board and the Grubnplan on the north wall, for screenshots.
		var viewer: Player = _game.local_player()
		viewer.teleport(_game.hub.global_transform * Transform3D(Basis.IDENTITY, Vector3(-0.5, 0.0, -3.2)))
		viewer.head.rotation.x = 0.05
		return
	if scenario == "coopclient":
		await _coop_client()
		return
	if scenario == "mptoolsclient":
		await _mp_tools_client()
		return
	if scenario == "mptools":
		while _game._ready_peers.size() < 2:
			await get_tree().process_frame
	if scenario == "coop":
		# Already in a pocket before the client joins: the join snapshot must say so.
		var pick: WorldItem = _game._spawn_item_at(&"spitzhacke", 0, _game.hub.counter_spot(), "ITestPick")
		await get_tree().create_timer(0.5).timeout
		_game.request_take(pick.get_path(), _game.local_player().peer_id)
		while _game._ready_peers.size() < 2:
			await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	if scenario == "salzsee" or scenario == "salzseelook":
		_game.biome_index = 1  # unlocked or not: this is a check of the section itself
	if scenario in ["tiefe", "percht", "tiefelook"]:
		_game.biome_index = 2
	_game.request_lift()
	while _game.phase != Game.Phase.SHIFT:
		await get_tree().process_frame
	match scenario:
		"salzsee":
			await _salzsee()
		"salzseelook":
			await _salzsee_look()
		"lamplook":
			# The beam down a tunnel, then held low (screenshots).
			for creature: Creature in _game.creatures():
				creature.queue_free()
			var miner: Player = _game.local_player()
			for light: OmniLight3D in _game.mine.lights:
				light.visible = false
			miner.teleport(Transform3D(_game.mine_cage.global_basis, _out_of_station(10.0)))
			await get_tree().create_timer(6.0).timeout
			miner.head.rotation.x = -0.4
		"mptools":
			await _mp_tools()
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
		"hazards":
			await _hazards()
		"tiefe":
			await _tiefe()
		"tiefelook":
			await _tiefe_look()
		"percht":
			await _percht()
		"weibl":
			await _weibl()
		"combat":
			await _combat()
		"combatlook":
			# For screenshots: the pistol in hand, a Grubenhund held still in the lamp light.
			for creature: Creature in _game.creatures():
				creature.queue_free()
			var miner: Player = _game.local_player()
			miner.teleport(Transform3D(_game.mine_cage.global_basis, _out_of_station(6.0)))
			await get_tree().create_timer(1.0).timeout
			for slot: int in miner.inventory.slots.size():
				if miner.inventory.slots[slot] != null:
					miner.inventory.select(slot)
			var dog: Creature = _game.spawn_creature(&"grubenhund", Transform3D(Basis.IDENTITY, miner.global_position - miner.global_basis.z * 3.5 + Vector3.UP * 0.2))
			dog.host_stun(60.0)
			await get_tree().create_timer(0.5).timeout
			dog.look_at(Vector3(miner.global_position.x, dog.global_position.y, miner.global_position.z), Vector3.UP)
			miner.head.rotation.x = -0.15
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
	# Two miners side by side: a Salzweibl right next to them does not dare and flees.
	_game.spawn_creature(&"salzweibl", Transform3D(Basis.IDENTITY, host.global_position - host.global_basis.z * 1.5))
	await get_tree().create_timer(1.5).timeout
	# Friendly fire (33 %), then down, helped up, then down for good.
	_game.request_shoot_player(client.peer_id, 30)
	await get_tree().create_timer(0.5).timeout
	print("[scenario] host: friendly fire, client health %d" % client.health)
	_game.host_damage_player(client, 1000)
	await get_tree().create_timer(1.0).timeout
	print("[scenario] host: client downed %s, alive %s" % [client.downed, client.alive])
	_game.request_help_up(client.get_path())
	await get_tree().create_timer(1.0).timeout
	print("[scenario] host: helped up, downed %s, health %d" % [client.downed, client.health])
	_game.host_damage_player(client, 1000)
	await get_tree().create_timer(1.0).timeout
	_game.host_damage_player(client, 1000)
	await get_tree().create_timer(5.0).timeout
	var corpses: int = 0
	for item: WorldItem in _game._items():
		corpses += 1 if item.data.id == &"leiche" else 0
	print("[scenario] host: %d corpse(s), client alive %s" % [corpses, client.alive])
	# The Wunderheilerin-Salbe on the body, well within the 30 s: the client is back.
	var salve: WorldItem = await _give(&"wunderheilerin_salbe")
	for item: WorldItem in _game._items():
		if item.data.id == &"leiche":
			host.teleport(Transform3D(Basis.IDENTITY, item.global_position + Vector3(1.0, 0.2, 0.0)))
			await get_tree().create_timer(0.3).timeout
			_game.request_revive(salve.get_path(), item.get_path())
	await get_tree().create_timer(1.0).timeout
	print("[scenario] host: client alive after the salve %s, health %d" % [client.alive, client.health])
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


## Die Tiefe and the M5 loot: what spawned, then the hat, the Jausenbox and its Speckbrot, the
## Bronzeschwert, the Kuckucksuhr and the cursed Mann im Salz.
func _tiefe() -> void:
	for creature: Creature in _game.creatures():
		creature.queue_free()
	var player: Player = _game.local_player()
	var config: BalanceConfig = Balance.config
	var section: StringName = _game.mine.chunk_set.id
	var foreign: int = 0
	for item: WorldItem in _game._items():
		if item.is_loot() and not item.data.spawns_in(section):
			foreign += 1
	print("[scenario] section %s, %d chunks, cell %.0f m, relics %d, loot from other sections %d, rails %s" % [section, _game.mine.chunks.size(),
			_game.mine.chunk_set.cell_size, _count(&"mann_im_salz"), foreign, _game.mine.rails != null])
	player.teleport(Transform3D(_game.mine_cage.global_basis, _out_of_station(6.0)))
	await get_tree().create_timer(0.5).timeout
	# The Gamsbart-Hut: on the head, still in the pocket.
	var hat: WorldItem = await _give(&"gamsbart_hut")
	player._use_active()
	await get_tree().create_timer(0.4).timeout
	print("[scenario] hat worn %s on %s" % [hat.worn, hat.follow.name if hat.follow != null else "-"])
	player._use_cooldown = 0.0
	# The Jausenbox: a Speckbrot inside, and it makes you sick.
	config.speckbrot_chance = 1.0
	config.speckbrot_poison_chance = 1.0
	var box: WorldItem = await _give(&"alte_jausenbox")
	player._use_active()
	await get_tree().create_timer(0.8).timeout
	player._use_cooldown = 0.0
	var bread: WorldItem = null
	for item: Object in player.inventory.slots:
		if item != null and (item as WorldItem).data.id == &"speckbrot":
			bread = item as WorldItem
	print("[scenario] box opened %s, speckbrot in a pocket %s" % [box.opened, bread != null])
	player.set_health(50)
	player.inventory.select(player.inventory.slots.find(bread))
	player._use_active()
	await get_tree().create_timer(config.speckbrot_eat_seconds + 0.5).timeout
	var after_eating: int = player.health
	await get_tree().create_timer(config.speckbrot_poison_seconds + 1.0).timeout
	print("[scenario] speckbrot: health 50 -> %d, after the poisoning %d" % [after_eating, player.health])
	player.set_health(config.player_max_health)
	# The Bronzeschwert in both hands against a Bergmandl right in front.
	var sword: WorldItem = _game._spawn_item_at(&"keltisches_bronzeschwert", 100, player.global_transform.translated(Vector3.UP))
	await get_tree().create_timer(0.3).timeout
	_game.request_take(sword.get_path(), player.peer_id)
	await get_tree().create_timer(0.3).timeout
	player.head.rotation.x = -0.6  # a Bergmandl is small
	var mandl: Creature = _game.spawn_creature(&"bergmandl", Transform3D(Basis.IDENTITY, player.camera.global_position - player.camera.global_basis.z * 1.4 - Vector3.UP * 1.0))
	mandl.host_stun(5.0)  # or it snatches the sword first
	await get_tree().create_timer(0.3).timeout
	player._use_cooldown = 0.0
	player._use_active()
	await get_tree().create_timer(0.3).timeout
	print("[scenario] sword in hands %s, bergmandl health %d" % [player.inventory.hands == sword, mandl.health if is_instance_valid(mandl) else -1])
	_game.request_drop(sword.get_path(), player.hold_point.global_transform, Vector3.ZERO)
	# The Kuckucksuhr cuckoos on its own.
	var clock: WorldItem = _game._spawn_item_at(&"kuckucksuhr", 90, player.global_transform.translated(Vector3.UP * 0.5))
	await get_tree().create_timer(0.3).timeout
	_game._special_left[String(clock.name)] = 0.1
	await get_tree().create_timer(0.5).timeout
	# The Mann im Salz: carried, the creatures sense it from further away.
	var relic: WorldItem = _game._spawn_item_at(&"mann_im_salz", 500, player.global_transform.translated(Vector3.UP * 0.5))
	await get_tree().create_timer(0.3).timeout
	_game.request_take(relic.get_path(), player.peer_id)
	await get_tree().create_timer(config.curse_pulse_seconds * 3.0 + 0.5).timeout
	print("[scenario] relic held %s, carried %.0f s, sensed from %.0f m" % [player.inventory.hands == relic,
			float(_game._cursed_for.get(String(relic.name), 0.0)), _game.curse_reach(float(_game._cursed_for.get(String(relic.name), 0.0)))])


## For screenshots: down a Tiefe tunnel, then at the Mann im Salz if this mine has him.
func _tiefe_look() -> void:
	for creature: Creature in _game.creatures():
		creature.queue_free()
	var player: Player = _game.local_player()
	player.teleport(Transform3D(_game.mine_cage.global_basis, _out_of_station(10.0)))
	await get_tree().create_timer(5.0).timeout
	for chunk: Chunk in _game.mine.chunks.values():
		var man: Node3D = chunk.find_child("SaltMan", true, false) as Node3D
		if man != null:
			var stand: Vector3 = man.global_position - man.global_basis.z * 3.2 + Vector3.UP * 0.1
			player.teleport(Transform3D(Basis.looking_at(-man.global_basis.z * -1.0), stand))
			player.head.rotation.x = 0.1
			print("[scenario] at the Mann im Salz")
			break
	await get_tree().create_timer(4.0).timeout
	var percht: Creature = _game.spawn_creature(&"percht", Transform3D(Basis.IDENTITY, player.global_position + player.global_basis.z * 4.0 + Vector3.UP * 0.2))
	percht.look_at(Vector3(player.global_position.x, percht.global_position.y, player.global_position.z), Vector3.UP)
	percht.host_stun(60.0)  # stands for its portrait
	player.rotate_y(PI)


## The Percht: sees a lit lamp from afar, a crouching miner in the dark not at all; hunts,
## loses you, is drawn off by a noise, strikes.
func _percht() -> void:
	for creature: Creature in _game.creatures():
		creature.queue_free()
	var player: Player = _game.local_player()
	var config: BalanceConfig = Balance.config
	var stand: Vector3 = _out_of_station(4.0)
	player.teleport(Transform3D(_game.mine_cage.global_basis, stand))
	player.lamp_on = false
	player.crouching = true
	var at: Vector3 = _out_of_station(13.0)
	await get_tree().create_timer(0.5).timeout
	var percht: Percht = _game.spawn_creature(&"percht", Transform3D(Basis.looking_at(stand - at), at + Vector3.UP * 0.2)) as Percht
	await get_tree().create_timer(0.5).timeout
	# Held still facing the miner for the sight check.
	percht.host_stun(30.0)
	percht.look_at(Vector3(player.global_position.x, percht.global_position.y, player.global_position.z), Vector3.UP)
	await get_tree().physics_frame
	print("[scenario] percht: dark and crouching at %.0f m: seen %s" % [percht.global_position.distance_to(player.global_position), percht._spot() != null])
	player.crouching = false
	player.lamp_on = true
	await get_tree().physics_frame
	print("[scenario] percht: lamp on: seen %s" % [percht._spot() == player])
	percht.stunned_left = 0.0
	await get_tree().create_timer(0.6).timeout
	print("[scenario] percht: then %s" % Percht.State.keys()[percht.state])
	# Gone round a corner, dark: it loses the scent and searches.
	player.lamp_on = false
	player.teleport(Transform3D(Basis.IDENTITY, _game.mine_cage.global_position + Vector3.UP * 0.2))
	await get_tree().create_timer(config.percht_lose_seconds + 1.5).timeout
	print("[scenario] percht: out of sight: %s" % Percht.State.keys()[percht.state])
	# A Böller-like bang further on draws it away.
	var bang: Vector3 = _out_of_station(30.0)
	_game.host_noise(bang, config.noise_boeller)
	await get_tree().create_timer(0.3).timeout
	print("[scenario] percht: after a bang: %s towards %.0f m off" % [Percht.State.keys()[percht.state], percht._goal.distance_to(bang)])
	# Face to face with a lamp on: it strikes.
	player.set_health(config.player_max_health)
	player.lamp_on = true
	player.teleport(Transform3D(Basis.IDENTITY, percht.global_position - percht.global_basis.z * 1.5 + Vector3.UP * 0.1))
	await get_tree().create_timer(2.0).timeout
	print("[scenario] percht: face to face, player health %d" % player.health)


## The Salzweibl in solo: calls with its own lines (no voice to copy), takes a lone miner.
func _weibl() -> void:
	for creature: Creature in _game.creatures():
		creature.queue_free()
	var player: Player = _game.local_player()
	player.teleport(Transform3D(_game.mine_cage.global_basis, _out_of_station(5.0)))
	await get_tree().create_timer(0.5).timeout
	player.lamp_on = false  # it never calls while a lamp is on it
	var weibl: Salzweibl = _game.spawn_creature(&"salzweibl", Transform3D(Basis.IDENTITY, _out_of_station(18.0) + Vector3.UP * 0.2)) as Salzweibl
	await get_tree().create_timer(6.0).timeout
	print("[scenario] salzweibl waits %.0f m away, shown %s" % [weibl.global_position.distance_to(player.global_position), weibl.net_shown])
	player.teleport(Transform3D(Basis.IDENTITY, weibl.global_position + Vector3(0.8, 0.1, 0.0)))
	await get_tree().create_timer(1.0).timeout
	print("[scenario] salzweibl: lone miner health %d, shown %s" % [player.health, weibl.net_shown])


## M6 combat: the kit from the company, a pack of Grubenhunde shot down (aiming like a player
## would), a reload, the shotgun, a Bergmandl throwing stones.
func _combat() -> void:
	for creature: Creature in _game.creatures():
		creature.queue_free()
	var player: Player = _game.local_player()
	var config: BalanceConfig = Balance.config
	await get_tree().create_timer(0.5).timeout
	var pistol: WorldItem = null
	for item: Object in player.inventory.slots:
		if item != null and (item as WorldItem).data.id == &"dienstpistole":
			pistol = item as WorldItem
	print("[scenario] kit: pistol %s, rounds %d, spare %d" % [pistol != null, pistol.rounds if pistol != null else -1, player.ammo_count(&"pistole")])
	player.inventory.select(player.inventory.slots.find(pistol))
	player.teleport(Transform3D(_game.mine_cage.global_basis, _out_of_station(4.0)))
	player.lamp_on = true
	await get_tree().create_timer(0.3).timeout
	var dogs: Array[Creature] = []
	for i: int in 2:
		dogs.append(_game.spawn_creature(&"grubenhund", Transform3D(Basis.IDENTITY, _out_of_station(16.0 + i) + Vector3(i * 0.8, 0.3, 0.0))))
	var shots: int = 0
	for frame: int in 600:
		await get_tree().physics_frame
		var target: Creature = null
		for dog: Creature in dogs:
			if is_instance_valid(dog) and not dog.is_queued_for_deletion():
				target = dog
		if target == null:
			break
		player.look_at(Vector3(target.global_position.x, player.global_position.y, target.global_position.z))
		var aim: Vector3 = target.global_position + Vector3.UP * 0.5 - player.camera.global_position
		player.head.rotation.x = atan2(aim.y, Vector2(aim.x, aim.z).length())
		if pistol.rounds == 0 and not player.gunner.reloading:
			player.gunner.start_reload()
		if player.gunner.fire():
			shots += 1
	var alive: int = 0
	for dog: Creature in dogs:
		alive += 1 if is_instance_valid(dog) and not dog.is_queued_for_deletion() else 0
	print("[scenario] dogs: %d left after %d shots, player health %d, rounds %d, spare %d" % [alive, shots, player.health, pistol.rounds, player.ammo_count(&"pistole")])
	# The shotgun: two shells, reloaded one by one.
	player.set_health(config.player_max_health)
	var flinte: WorldItem = await _give(&"salzschrot_flinte")
	_game._to_peer(player.peer_id, player, &"give_ammo", [&"schrot", 5, false])
	await get_tree().create_timer(0.2).timeout
	player.head.rotation.x = 0.0
	player.gunner._cooldown = 0.0
	var fired: bool = player.gunner.fire()
	await get_tree().create_timer(0.5).timeout
	player.gunner.start_reload()
	await get_tree().create_timer(flinte.data.weapon.reload_seconds * 2.0 + 0.5).timeout
	print("[scenario] flinte fired %s, rounds %d, spare shells %d" % [fired, flinte.rounds, player.ammo_count(&"schrot")])
	# A Bergmandl with nothing to steal throws stones.
	for item: WorldItem in _game._items():
		if item.state == WorldItem.State.FREE and item.global_position.y < Game.HUB_FLOOR_ABOVE:
			item.host_vanish()
	var mandl: Creature = _game.spawn_creature(&"bergmandl", Transform3D(Basis.IDENTITY, _out_of_station(12.0) + Vector3.UP * 0.3))
	player.teleport(Transform3D(_game.mine_cage.global_basis, _out_of_station(4.0)))
	await get_tree().create_timer(9.0).timeout
	print("[scenario] stones: player health %d, bergmandl alive %s" % [player.health, is_instance_valid(mandl)])
	if is_instance_valid(mandl):
		mandl.queue_free()
	# A dog right next to an unarmed miner bites.
	player.set_health(config.player_max_health)
	player.inventory.select(player.inventory.slots.find(null))
	_game.spawn_creature(&"grubenhund", Transform3D(Basis.IDENTITY, player.global_position - player.global_basis.z * 2.5 + Vector3.UP * 0.3))
	await get_tree().create_timer(2.5).timeout
	print("[scenario] bitten: player health %d" % player.health)
	for creature: Creature in _game.creatures():
		creature.queue_free()
	# Solo: the second wind saves you once, then you are gone.
	player.set_health(5)
	_game.host_damage_player(player, 50)
	var after_wind: int = player.health
	_game.host_damage_player(player, 50)
	var while_invulnerable: int = player.health
	await get_tree().create_timer(config.second_wind_seconds + 0.5).timeout
	_game.host_damage_player(player, 50)
	print("[scenario] second wind: health %d, still %d, then alive %s" % [after_wind, while_invulnerable, player.alive])


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
	# Walk along the track towards the lift, behind the cart.
	var walk_from: float = _game.mine.rails.closest_s(player.global_position)
	for i: int in 60:
		player.global_position = _game.mine.rails.transform_at(walk_from - i * config.walk_speed * 0.8 / 60.0).origin + Vector3.UP * 0.1
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
	for item: Object in player.inventory.slots:
		if item != null and (item as WorldItem).data.id == &"dienstpistole":
			(item as WorldItem).host_vanish()  # a free pocket for the pick
	await get_tree().create_timer(0.2).timeout
	await _give(&"spitzhacke")
	var hits: int = 0
	while wall.health > 0 and hits < 10:
		_game.request_break(wall.get_path(), 34)
		hits += 1
		await get_tree().create_timer(0.1).timeout
	print("[scenario] salt wall broken after %d hits: %s" % [hits, wall.health <= 0])


func _hazards() -> void:
	for creature: Creature in _game.creatures():
		creature.queue_free()
	var player: Player = _game.local_player()
	var config: BalanceConfig = Balance.config
	var hazards: Hazards = _game.mine.hazards
	# Only the test pockets count: the mine's own could go up wherever the checks lead.
	for pocket: Hazards.GasPocket in hazards.pockets:
		pocket.gone = true
		pocket.visible = false
	var stand: Vector3 = _out_of_station(8.0)
	player.teleport(Transform3D(_game.mine_cage.global_basis, stand))
	await get_tree().create_timer(0.5).timeout
	# Firedamp with the Stirnlampe: nothing happens. With the carbide flame: bang.
	player.lamp_electric = true
	hazards._add_pocket(stand + Vector3.UP * 1.8, "GasTest1")
	await get_tree().create_timer(config.gas_fuse_seconds + 0.5).timeout
	print("[scenario] gas with stirnlampe: still there %s, health %d" % [not hazards.pockets[-1].gone, player.health])
	player.lamp_electric = false
	player.lamp_on = true
	await get_tree().create_timer(0.2).timeout
	print("[scenario] gas: carbide flare %.2f" % player.gas_flare)
	await get_tree().create_timer(config.gas_fuse_seconds + 0.5).timeout
	print("[scenario] gas with carbide: gone %s, health %d" % [hazards.pockets[-1].gone, player.health])
	player.set_health(config.player_max_health)
	# A Böller sets off a pocket from outside.
	var far_gas: Vector3 = stand + _game.mine_cage.global_basis.x * 0.0 - _game.mine_cage.global_basis.z * 6.0 + Vector3.UP * 1.8
	hazards._add_pocket(far_gas, "GasTest2")
	_game.host_bang(far_gas - Vector3.UP * 1.6)
	await get_tree().create_timer(0.3).timeout
	print("[scenario] gas set off by a bang: %s" % hazards.pockets[-1].gone)
	player.set_health(config.player_max_health)
	# Brine slows and drains the carbide.
	hazards._add_pool(player.global_position, "BrineTest")
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().create_timer(0.2).timeout
	print("[scenario] brine: in brine %s, lamp drain x%.0f" % [player.in_brine, player.brine_lamp_drain()])
	# Rockfall next to the player.
	player.teleport(Transform3D(_game.mine_cage.global_basis, _out_of_station(22.0)))
	await get_tree().create_timer(0.5).timeout
	var before: int = player.health
	hazards._host_rockfall()
	await get_tree().create_timer(0.2).timeout
	print("[scenario] standing under the rockfall")
	player.teleport(Transform3D(Basis.IDENTITY, hazards.last_rockfall + Vector3.UP * 0.1))
	await get_tree().create_timer(config.rockfall_warning_seconds + 0.5).timeout
	print("[scenario] rockfall happened, health %d -> %d" % [before, player.health])
	player.set_health(config.player_max_health)
	await _gesenk(player, config)


## A Gesenk chunk far below the mine: the bridge breaks under a salt block, the rotten ladder
## under someone carrying it, and a Seil goes down the edge and up again.
func _gesenk(player: Player, config: BalanceConfig) -> void:
	var scene: PackedScene = load("res://world/chunks/oberer_stollen/gesenk.tscn")
	var chunk: Chunk = scene.instantiate() as Chunk
	chunk.name = "GesenkTest"
	chunk.cell = Vector2i(100, 100)
	chunk.position = Vector3(0.0, -80.0, 0.0)
	chunk.setup(GridDir.N | GridDir.S, 0)
	_game.mine.add_child(chunk)
	chunk.build_cave(6.0, _game.mine.seed_value)
	await get_tree().physics_frame
	var bridge: RottenBridge = chunk.find_child("Bridge", true, false) as RottenBridge
	var top: Vector3 = chunk.global_position
	# Across the bridge alone: it holds.
	player.teleport(Transform3D(Basis.IDENTITY, bridge.global_position + Vector3(0, 0.2, 1.0)))
	await get_tree().create_timer(1.0).timeout
	print("[scenario] bridge with a miner on it: broken %s, standing at %.1f" % [bridge.broken, player.global_position.y - top.y])
	# With a salt block: it gives way, down into the pit.
	var block: WorldItem = _game._spawn_item_at(&"steinsalz_block", 100, player.global_transform.translated(Vector3.UP * 0.6))
	await get_tree().create_timer(0.3).timeout
	_game.request_take(block.get_path(), player.peer_id)
	await get_tree().create_timer(config.rotten_break_seconds + 1.6).timeout
	print("[scenario] bridge with a salt block: broken %s, fell to %.1f, health %d" % [bridge.broken, player.global_position.y - top.y, player.health])
	player.set_health(config.player_max_health)
	# Up the rotten ladder with the block: it breaks.
	var ladder: Ladder = chunk.find_child("LadderS", true, false) as Ladder
	player.teleport(Transform3D(Basis.IDENTITY, ladder.global_position + ladder.global_basis.z * -0.4 + Vector3.UP * 0.1))
	player.look_at(ladder.global_position + Vector3.UP * 1.0 + ladder.global_basis.z * -0.4 + (ladder.global_position - (ladder.global_position + ladder.global_basis.z * -0.4)) * 2.0)
	player.rotation.x = 0.0
	player.rotation.z = 0.0
	await get_tree().create_timer(0.3).timeout
	Input.action_press(&"move_forward")
	await get_tree().create_timer(1.5).timeout
	Input.action_release(&"move_forward")
	print("[scenario] ladder with a salt block: broken %s, climbed %s" % [ladder.broken, player.climbing or ladder.broken])
	_game.request_drop(block.get_path(), player.hold_point.global_transform, Vector3.ZERO)
	await get_tree().create_timer(0.5).timeout
	# A Seil down the edge from the ledge beside the pit, then climb it out.
	player.teleport(Transform3D(Basis.IDENTITY, top + Vector3(2.3, 0.1, 0.0)))
	await get_tree().create_timer(0.4).timeout
	var seil: WorldItem = await _give(&"seil")
	_game.request_rope(seil.get_path(), top + Vector3(1.9, 0.0, 0.0), Vector3.LEFT)
	await get_tree().create_timer(0.4).timeout
	var ropes: Array[Node] = _game.mine.find_children("Rope*", "Rope", false, false)
	if ropes.is_empty():
		print("[scenario] no rope placed")
		return
	var rope: Rope = ropes[0] as Rope
	print("[scenario] rope from %.1f down to %.1f" % [rope.top.y - top.y, rope.bottom.y - top.y])
	player.teleport(Transform3D(Basis.IDENTITY, rope.bottom + Vector3(-0.3, 0.1, 0.0)))
	player.look_at(Vector3(rope.top.x + 2.0, player.global_position.y, rope.top.z))
	await get_tree().create_timer(0.3).timeout
	Input.action_press(&"move_forward")
	await get_tree().create_timer(5.0).timeout
	Input.action_release(&"move_forward")
	await get_tree().create_timer(0.5).timeout
	print("[scenario] climbed the rope to %.1f, on the ledge %s" % [player.global_position.y - top.y, player.global_position.y > top.y - 0.3])


## A Salzsee shift: the section's mine, and a lake cavern far below it for swimming and the ferry.
func _salzsee() -> void:
	for creature: Creature in _game.creatures():
		creature.queue_free()
	var player: Player = _game.local_player()
	var config: BalanceConfig = Balance.config
	print("[scenario] section %s, %d chunks, cell %.0f m, echo %.1f" % [_game.mine.chunk_set.id, _game.mine.chunks.size(), _game.mine.chunk_set.cell_size, _game.mine.chunk_set.echo])
	var scene: PackedScene = load("res://world/chunks/salzsee/lake.tscn")
	var chunk: Chunk = scene.instantiate() as Chunk
	chunk.name = "LakeTest"
	chunk.cell = Vector2i(100, 100)
	chunk.position = Vector3(0.0, -80.0, 0.0)
	chunk.setup(GridDir.N | GridDir.S, 0)
	_game.mine.add_child(chunk)
	chunk.build_cave(8.0, _game.mine.seed_value)
	await get_tree().physics_frame
	var lake: Lake = chunk.find_child("Lake", true, false) as Lake
	var ferry: Ferry = chunk.find_child("Ferry", true, false) as Ferry
	# Into the water: swimming, the carbide lamp drowns, and something bites after a while.
	player.lamp_on = true
	player.teleport(Transform3D(Basis.IDENTITY, lake.global_position + Vector3(-3.0, 0.5, 0.0)))
	await get_tree().create_timer(1.0).timeout
	print("[scenario] in the lake: swimming %s, lamp on %s, head above water %s" % [player.swim_lake != null, player.lamp_on, player.global_position.y + 1.6 > lake.surface_y()])
	await get_tree().create_timer(config.deep_water_grace + 1.5).timeout
	print("[scenario] after %.0f s in the water: health %d" % [config.deep_water_grace + 2.5, player.health])
	# Swim to the north landing and pull out.
	player.look_at(Vector3(player.global_position.x, player.global_position.y, chunk.global_position.z - 8.0))
	Input.action_press(&"move_forward")
	for i: int in 80:
		await get_tree().create_timer(0.1).timeout
		if player.swim_lake == null:
			break
	Input.action_release(&"move_forward")
	print("[scenario] out of the water: %s at %.1f" % [player.swim_lake == null, player.global_position.y - chunk.global_position.y])
	player.set_health(config.player_max_health)
	# The ferry: stand on it at the north landing, ring, ride across.
	var deck: Vector3 = ferry.boat_position()
	player.teleport(Transform3D(Basis.IDENTITY, deck + Vector3.UP * 0.3))
	await get_tree().create_timer(0.6).timeout
	_game.request_ferry(ferry.get_path(), player.global_position)
	await get_tree().create_timer(config.ferry_seconds + 1.0).timeout
	print("[scenario] ferry crossed %.1f m, rider moved %.1f m, swimming %s" % [ferry.boat_position().distance_to(deck), player.global_position.distance_to(deck), player.swim_lake != null])


## For screenshots: on the north landing of a lake cavern with the Stirnlampe, looking across
## the lake at the ferry, a firedamp pocket in front; then a turn to the side.
func _salzsee_look() -> void:
	for creature: Creature in _game.creatures():
		creature.queue_free()
	var player: Player = _game.local_player()
	var chunk: Chunk = (load("res://world/chunks/salzsee/lake.tscn") as PackedScene).instantiate() as Chunk
	chunk.name = "LakeLook"
	chunk.position = Vector3(0.0, -80.0, 0.0)
	chunk.setup(GridDir.N | GridDir.S, 0)
	_game.mine.add_child(chunk)
	chunk.build_cave(8.0, _game.mine.seed_value)
	var lake: Lake = chunk.find_child("Lake", true, false) as Lake
	var ferry: Ferry = chunk.find_child("Ferry", true, false) as Ferry
	player.lamp_electric = true
	player.lamp_on = true
	player.teleport(Transform3D(Basis.IDENTITY, Vector3(lake.global_position.x + 1.0, chunk.global_position.y + 0.1, chunk.global_position.z - 6.2)))
	player.look_at(Vector3(lake.global_position.x, player.global_position.y, chunk.global_position.z + 4.0))
	player.head.rotation.x = -0.25
	_game.mine.hazards._add_pocket(player.global_position + Vector3(0.0, 1.8, 2.8), "GasLook")
	await get_tree().create_timer(6.0).timeout
	_game.request_ferry(ferry.get_path(), player.global_position)
	await get_tree().create_timer(6.0).timeout
	player.rotate_y(1.2)
	player.head.rotation.x = 0.1


## Host side of the multiplayer tool check: hands the client its tools one after another
## (mptoolsclient uses each as it arrives) and logs what the host sees.
func _mp_tools() -> void:
	for creature: Creature in _game.creatures():
		creature.queue_free()
	var host: Player = _game.local_player()
	var client: Player = null
	for player: Player in _game.players():
		if player != host:
			client = player
	var stand: Vector3 = _out_of_station(10.0)
	client.teleport.rpc(Transform3D(_game.mine_cage.global_basis, stand))
	host.teleport(Transform3D(_game.mine_cage.global_basis, stand + _game.mine_cage.global_basis.x * 1.5))
	client.set_health.rpc(30)
	await get_tree().create_timer(1.0).timeout
	for id: StringName in [&"stirnlampe", &"obstler", &"boeller", &"alphorn", &"rauchbombe", &"funkgeraet", &"pfeiferl"]:
		var item: WorldItem = _game._spawn_item_at(id, 0, client.global_transform.translated(Vector3.UP * 1.0), "ITool_%s" % id)
		await get_tree().create_timer(0.5).timeout
		_game.request_take(item.get_path(), client.peer_id)
		await get_tree().create_timer(2.5 if id == &"boeller" else 1.5).timeout
	print("[scenario] host sees P%d: lamp electric %s, health %d" % [client.peer_id, client.lamp_electric, client.health])
	# A Grubenhund held still in front of the client: the client shoots it, the host applies it.
	var dog: Creature = _game.spawn_creature(&"grubenhund", Transform3D(Basis.IDENTITY, client.global_position - client.global_basis.z * 5.0 + Vector3.UP * 0.3))
	dog.host_stun(60.0)
	await get_tree().create_timer(6.0).timeout
	print("[scenario] host: dog shot dead by the client %s" % (not is_instance_valid(dog)))
	host.teleport(_game.mine_cage.player_spot(0))
	await get_tree().create_timer(0.5).timeout
	_game.request_lift()


## Client side: uses every tool that lands in a pocket, the way a player would (click).
func _mp_tools_client() -> void:
	while _game.phase != Game.Phase.SHIFT:
		await get_tree().process_frame
	var me: Player = _game.local_player()
	var used: Dictionary = {}
	var cart_from: Vector3 = Vector3.INF
	for i: int in 160:
		await get_tree().create_timer(0.2).timeout
		if _game.phase != Game.Phase.SHIFT:
			break
		for creature: Creature in _game.creatures():
			if creature is Grubenhund:
				_client_shoot_at(me, creature)
		for slot: int in me.inventory.slots.size():
			var item: WorldItem = me.inventory.slots[slot] as WorldItem
			if item == null or used.has(item.name):
				continue
			used[item.name] = true
			me.inventory.select(slot)
			me._use_cooldown = 0.0
			me._alphorn_cooldown = 0.0
			if item.data.id == &"pfeiferl":
				for other: WorldItem in _game._items():
					if other is RailCart:
						cart_from = other.global_position
			me._use_active()
			print("[scenario] client used %s" % item.data.id)
			if item.data.id == &"alphorn":
				await get_tree().create_timer(0.3).timeout
				me._drop_active()  # pockets: the company pistol needs one now
			if item.data.id == &"obstler":
				await get_tree().create_timer(0.6).timeout
				print("[scenario] client health after obstler %d" % me.health)
	for other: WorldItem in _game._items():
		if other is RailCart and cart_from != Vector3.INF:
			print("[scenario] client saw the hunt roll %.1f m" % other.global_position.distance_to(cart_from))


## The client aims its pistol at `target` and pulls the trigger (one shot per call).
func _client_shoot_at(me: Player, target: Creature) -> void:
	for slot: int in me.inventory.slots.size():
		var item: WorldItem = me.inventory.slots[slot] as WorldItem
		if item != null and item.data.id == &"dienstpistole":
			me.inventory.select(slot)
	me.look_at(Vector3(target.global_position.x, me.global_position.y, target.global_position.z))
	var aim: Vector3 = target.global_position + Vector3.UP * 0.5 - me.camera.global_position
	me.head.rotation.x = atan2(aim.y, Vector2(aim.x, aim.z).length())
	if me.gunner.fire():
		print("[scenario] client fired, rounds %d" % me.gunner.weapon_item().rounds)


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
	for i: int in 140:
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
		if me.downed and not seen.has("downed"):
			seen.downed = true
			print("[scenario] client downed, crouching %s" % me.crouching)
		if seen.has("downed") and not me.downed and me.alive and me.health > 0 and not seen.has("up"):
			seen.up = true
			print("[scenario] client up again, health %d" % me.health)
		if not me.alive and me.spectating != null and not seen.has("dead"):
			seen.dead = true
			print("[scenario] client dead, spectating P%d" % me.spectating.peer_id)
		if seen.has("dead") and me.alive and me.health < Balance.config.player_max_health and not seen.has("revived"):
			seen.revived = true
			print("[scenario] client revived, health %d, own camera %s" % [me.health, me.camera.current])


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
	me.inventory.select(me.inventory.slots.find(mine))  # the company pistol is in the other pocket
	# Walk (real input) and throw with the drop key, as a player would.
	Input.action_press(&"move_forward")
	await get_tree().create_timer(0.6).timeout
	me._drop_active()
	await get_tree().create_timer(0.4).timeout
	Input.action_release(&"move_forward")
