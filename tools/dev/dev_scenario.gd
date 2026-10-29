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
		_:
			push_warning("unknown scenario %s" % scenario)


func _process(delta: float) -> void:
	if _game == null or _game.phase != Game.Phase.SHIFT:
		return
	_log_left -= delta
	if _log_left > 0.0:
		return
	_log_left = 0.5
	for creature: Creature in _game.creatures():
		var mandl: Bergmandl = creature as Bergmandl
		if mandl != null:
			print("[scenario] %s %s at %s carrying %s" % [mandl.name, Bergmandl.State.keys()[mandl.state], mandl.global_position.snapped(Vector3.ONE * 0.1), mandl.carried.name if mandl.carried != null else "-"])


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
