extends Node
## Dev tool: scripted situations to watch the game do something specific, for checks without a
## human at the keyboard. Added by Game when started with `-- --solo --scenario=<name>`; pair
## it with `--shots=<dir>` (screenshots) and `--smoke=<seconds>` (quit).
##   mandl  – a salt crystal in the station, a Bergmandl comes for it; later the player shouts.
##   loot   – the player fetches the three nearest loot items into the Förderkorb, rides up,
##            and they get sold.

var _game: Game
var _log_left: float = 0.0


func run(game: Game, scenario: String) -> void:
	_game = game
	print("[scenario] %s" % scenario)
	while _game.phase != Game.Phase.HUB:
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
