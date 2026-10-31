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
##   notration – nearly out of ammo, a kill drops a few rounds; with ammo it does not.
##   shoplook – the shop, every shelf (screenshots).
##   cheat  – in the Gasthaus: types the money cheat word, logs the money before and after.
##   fundstueck – the M7 loop: the lever refuses without the Fundstück, taking it sounds the
##            alarm, waves come, delivered it pays; the next shift runs out of time (fired).
##   giveup – two pulls of the mine lever without the Fundstück: fired.
##   boss   – the Fundstück guarded by Da Bergkini: locked, he wakes, throws dynamite, calls
##            Bergmandl; dead, the Fundstück is free.
##   upgrades – buys run upgrades in the Gasthaus, checks guns, caps, armour and lamp, and the
##            armour taking its share down in the mine.
##   weapons – M8: the Stutzen on a dog's head, a flare by a Kasermandl and in the Schichtmeister's
##            face, Dynamit bringing the roof down.
##   seemuada / schiachpercht – the Salzsee and Die Tiefe bosses at their Fundort: awake,
##            fighting, then killed.
##   elites – a Raunacht Grubenhund next to a plain one, killed: its box of ammo.

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
	if scenario == "shoplook":
		# The shop with money for some of it, every shelf in turn (screenshots).
		DisplayServer.window_set_size(Vector2i(1280, 720))
		GameState.run.add_cheat_money(250)
		_game._broadcast_run()
		for category: int in ItemData.ShopCategory.values():
			_game.hud._shop_category = category
			_game.hud.open_shop()
			await get_tree().create_timer(1.5).timeout
			await _snap("shop_%d" % category)
		print("[scenario] shoplook done")
		return
	if scenario == "brieflook":
		# The Knappenbrief with some Ehrenzeichen, both sheets, then the frame on the wall.
		DisplayServer.window_set_size(Vector2i(1280, 720))
		GameState.profile.earn(14)
		GameState.profile.buy(Balance.config.perk(&"gsund"))
		GameState.profile.buy(Balance.config.perk(&"lampe_gruenspan"))
		for sheet: int in 2:
			_game.hud._brief_sheet = sheet
			_game.hud.open_knappenbrief()
			await get_tree().create_timer(1.5).timeout
			await _snap("knappenbrief_%d" % sheet)
		_game.hud.close_panels()
		var viewer: Player = _game.local_player()
		viewer.teleport(_game.hub.global_transform * Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(6.0, 0.0, -1.3)))
		viewer.head.rotation.x = 0.0
		await get_tree().create_timer(1.0).timeout
		await _snap("knappenbrief_wall")
		print("[scenario] brieflook done")
		return
	if scenario == "notration":
		await _notration()
		return
	if scenario == "cheat":
		await _cheat()
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
		# The host's Knappenbrief: the late-joining client must see it.
		GameState.profile.earn(10)
		GameState.profile.buy(Balance.config.perk(&"gsund"))
		GameState.profile.buy(Balance.config.perk(&"hut_gamsbart"))
		_game.local_player().submit_loadout.rpc_id(1, GameState.profile.loadout())
		while _game._ready_peers.size() < 2:
			await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	if scenario == "salzsee" or scenario == "salzseelook":
		_game.biome_index = 1  # unlocked or not: this is a check of the section itself
	if scenario in ["tiefe", "percht", "tiefelook"]:
		_game.biome_index = 2
	if scenario in ["boss", "bosslook"]:
		_game._force_boss = true
	if scenario == "seemuada":
		_game.biome_index = 1
		_game._force_boss = true
	if scenario == "schiachpercht":
		_game.biome_index = 2
		_game._force_boss = true
	if scenario == "upgrades":
		await _upgrades_hub()
	if scenario == "knappenbrief":
		await _knappenbrief_hub()
	if scenario == "overtime":
		GameState.run.overtime.assign([&"finster", &"frueh", &"eile", &"knapp", &"panzerhunde", &"zaach"])
		_game._broadcast_run()
		await get_tree().create_timer(0.3).timeout
		print("[scenario] overtime board: %s" % _game.hub.board_text.text.get_slice("\n\n", _game.hub.board_text.text.get_slice_count("\n\n") - 1))
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
		"smooth":
			await _smooth()
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
			for id: StringName in [&"salzschrot_flinte", &"boeller", &"obstler", &"seil", &"karbidpatrone"]:
				await _give(id)
			for slot: int in miner.inventory.slots.size():
				if miner.inventory.slots[slot] != null and (miner.inventory.slots[slot] as WorldItem).data.id == &"dienstpistole":
					miner.inventory.select(slot)
			await get_tree().create_timer(4.0).timeout
			Input.action_press(&"aim")  # then down the sights
		"gunlook":
			await _gun_look()
		"fundstueck":
			await _fundstueck()
		"giveup":
			await _give_up()
		"boss":
			await _boss()
		"bosslook":
			await _boss_look()
		"upgrades":
			await _upgrades_mine()
		"knappenbrief":
			await _knappenbrief_mine()
		"overtime":
			await _overtime_mine()
		"weapons":
			await _weapons()
		"impacts":
			await _impacts()
		"seemuada", "schiachpercht":
			await _boss_fight(scenario)
		"elites":
			await _elites()
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
		if player.inventory.place_for(item.data.weight_class, item.data.slot_kind()) == Inventory.NONE:
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
	await _game.dev_deliver()
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
	player.inventory.select(player.inventory.slots.find(pocket))  # it went into an item pocket (5–9)
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


## Out of ammo (one round left, no spare): a creature killed drops a few rounds; with a full
## pocket of ammo it does not.
func _notration() -> void:
	var miner: Player = _game.local_player()
	await _give(&"dienstpistole")
	_select(miner, &"dienstpistole")
	await get_tree().process_frame
	var pistol: WorldItem = miner.gunner.weapon_item()
	for spare: int in [0, 30]:
		pistol.rounds = 1
		miner.use_ammo(&"pistole", 999)
		miner.give_ammo(&"pistole", spare)
		var dog: Creature = _game.spawn_creature(&"grubenhund", miner.global_transform.translated(-miner.global_basis.z * 3.0))
		await get_tree().create_timer(0.3).timeout
		var boxes_before: int = _ammo_boxes()
		_game.request_hit(dog.get_path(), 999, miner.global_position)
		await get_tree().create_timer(0.5).timeout
		print("[scenario] notration with %d spare: boxes %+d" % [spare, _ammo_boxes() - boxes_before])


func _ammo_boxes() -> int:
	var count: int = 0
	for item: WorldItem in _game._items():
		count += 1 if item.data.kind == ItemData.Kind.AMMO else 0
	return count


func _cheat() -> void:
	var before: int = GameState.run.money
	for letter: String in Game.CHEAT_MONEY_WORD:
		var key: InputEventKey = InputEventKey.new()
		key.pressed = true
		key.unicode = letter.unicode_at(0)
		Input.parse_input_event(key)
		await get_tree().process_frame
	for i: int in 10:
		await get_tree().process_frame
	print("[scenario] cheat: money %d -> %d, shown %d" % [before, GameState.run.money, int(_game.run_info.money)])


## For screenshots: each weapon at the hip, aimed, reloading (several moments), against a
## wall, and the Spitzhacke swung. Saves named pictures into the --shots folder.
func _gun_look() -> void:
	for creature: Creature in _game.creatures():
		creature.queue_free()
	DisplayServer.window_set_size(Vector2i(960, 540))
	var miner: Player = _game.local_player()
	var station: Transform3D = Transform3D(_game.mine_cage.global_basis, _out_of_station(6.0))
	miner.teleport(station)
	await _give(&"salzschrot_flinte")
	await _give(&"spitzhacke")
	miner.ammo[&"schrot"] = 20
	miner.head.rotation.x = -0.05
	# A work light at the eye, so the pictures show the shapes.
	var work_light: OmniLight3D = OmniLight3D.new()
	work_light.light_energy = 1.5
	work_light.omni_range = 3.0
	work_light.position = Vector3(0.3, 0.3, 0.2)
	miner.camera.add_child(work_light)
	for id: StringName in [&"dienstpistole", &"salzschrot_flinte"]:
		_select(miner, id)
		await get_tree().create_timer(1.5).timeout
		await _snap("%s_hip" % id)
		Input.action_press(&"aim")
		await get_tree().create_timer(1.0).timeout
		await _snap("%s_aimed" % id)
		Input.action_release(&"aim")
		await get_tree().create_timer(0.6).timeout
		miner.gunner.fire()
		await get_tree().create_timer(0.5).timeout
		miner.gunner.start_reload()
		var reload: float = miner.gunner.view_item().data.weapon.reload_seconds
		for share: float in [0.15, 0.3, 0.45, 0.6, 0.75]:
			await get_tree().create_timer(reload * 0.15).timeout
			await _snap("%s_reload_%02d" % [id, int(share * 100)])
		await get_tree().create_timer(2.5).timeout
	# Against a wall: turned to the nearest rock.
	_select(miner, &"salzschrot_flinte")
	miner.rotate_y(PI / 2.0)
	for i: int in 30:
		miner.teleport(miner.global_transform.translated(-miner.global_basis.z * 0.1))
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	await _snap("flinte_wall")
	miner.teleport(station)
	_select(miner, &"spitzhacke")
	await get_tree().create_timer(1.5).timeout
	await _snap("spitzhacke_rest")
	miner.gunner.view.swing()
	for t: String in ["a", "b", "c", "d"]:
		await get_tree().create_timer(0.08).timeout
		await _snap("spitzhacke_swing_" + t)
	print("[scenario] gunlook done")


func _select(miner: Player, id: StringName) -> void:
	for slot: int in miner.inventory.slots.size():
		if miner.inventory.slots[slot] != null and (miner.inventory.slots[slot] as WorldItem).data.id == id:
			miner.inventory.select(slot)


func _snap(picture: String) -> void:
	var dir: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(Game.SHOTS_ARG):
			dir = arg.trim_prefix(Game.SHOTS_ARG)
	if dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(picture + ".png"))


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
	print("[scenario] host: voice snippets from the client %d" % (VoiceChat.snippets.get(client.peer_id, []) as Array).size())
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
	# G while looking at the teammate: half of the host's pistol rounds go over.
	host.give_ammo(&"pistole", 20)
	var to_client: Vector3 = client.global_position - host.global_position
	host.rotation.y = atan2(-to_client.x, -to_client.z)
	host.head.rotation.x = -0.25
	await get_tree().create_timer(0.3).timeout
	var host_before: int = host.ammo_count(&"pistole")
	var client_before: int = client.ammo_count(&"pistole")
	host._drop_active()
	await get_tree().create_timer(1.0).timeout
	print("[scenario] host: handed ammo, client %+d, host %+d" % [client.ammo_count(&"pistole") - client_before, host.ammo_count(&"pistole") - host_before])
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
	await _game.dev_deliver()
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
	# v2: up out of the floor it can be shot – the throat is soft, the scales are not.
	player.velocity = Vector3.ZERO
	await get_tree().create_timer(1.5).timeout  # the lunge lands first
	print("[scenario] after the lunge: player health %d" % player.health)
	player.set_meta(&"invulnerable_until", INF)
	var wurm: Tatzelwurm = null
	for creature: Creature in _game.creatures():
		wurm = creature as Tatzelwurm if creature is Tatzelwurm else wurm
	if wurm == null:
		return
	while wurm.state != Tatzelwurm.State.SURFACE and wurm.state != Tatzelwurm.State.LUNGE:
		_game.host_noise(player.global_position, Balance.config.noise_sprint)
		await get_tree().create_timer(0.5).timeout
	while wurm.net_emerge < 1.0:
		await get_tree().physics_frame
	var throat: Vector3 = wurm._head.global_position - wurm._head.global_basis.y * 0.25
	var scales: Vector3 = wurm.global_position + Vector3.UP * 0.3
	print("[scenario] tatzelwurm shootable %s: throat x%.2f, scales x%.2f" % [wurm.can_be_shot(), wurm.weak_spot_mult(throat), wurm.weak_spot_mult(scales)])
	var before: int = wurm.health
	_game.request_hit(wurm.get_path(), 20, player.global_position, true)
	print("[scenario] tatzelwurm hit while up: health %d -> %d, %s" % [before, wurm.health, Tatzelwurm.State.keys()[wurm.state]])
	_game.request_hit(wurm.get_path(), 5000, player.global_position, true)
	await get_tree().physics_frame
	print("[scenario] tatzelwurm dead %s" % (not is_instance_valid(wurm) or wurm.is_queued_for_deletion()))


func _kaser() -> void:
	for creature: Creature in _game.creatures():
		creature.queue_free()
	var player: Player = _game.local_player()
	player.teleport(Transform3D(_game.mine_cage.global_basis, _out_of_station(8.0)))
	for light: OmniLight3D in _game.mine.lights:
		light.visible = false  # only the lamp counts in this check
	await get_tree().create_timer(0.5).timeout
	var kaser: Creature = _game.spawn_creature(&"kasermandl", Transform3D(Basis.IDENTITY, _out_of_station(24.0) + Vector3.UP * 0.3))
	# The beam only lights what the miner looks at, and the tunnel may bend: keep facing it.
	var until: float = Time.get_ticks_msec() / 1000.0 + 7.0
	while Time.get_ticks_msec() / 1000.0 < until:
		await get_tree().process_frame
		if is_instance_valid(kaser):
			player.look_at(Vector3(kaser.global_position.x, player.global_position.y, kaser.global_position.z))
			player.head.rotation.x = 0.0
	# v2: in the light it can be shot, in the dark everything goes through it.
	if is_instance_valid(kaser):
		var lit_health: int = kaser.health
		_game.request_hit(kaser.get_path(), 10, player.global_position)
		print("[scenario] kasermandl shot while lit: health %d -> %d, shootable %s" % [lit_health, kaser.health, kaser.can_be_shot()])
	print("[scenario] lamp off")
	player.lamp_on = false
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(kaser):
		var dark_health: int = kaser.health
		_game.request_hit(kaser.get_path(), 10, player.global_position)
		print("[scenario] kasermandl shot in the dark: health %d -> %d, shootable %s" % [dark_health, kaser.health, kaser.can_be_shot()])


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
	# v2: the mask is its weak spot, the hide is armour.
	var mask: Vector3 = percht._mask.global_position
	print("[scenario] percht: mask x%.2f, body x%.2f" % [percht.weak_spot_mult(mask), percht.weak_spot_mult(percht.global_position + Vector3.UP * 0.8)])
	# A few metres off in plain sight, lamp on: it lowers its horns and charges.
	player.set_health(config.player_max_health)
	player.set_meta(&"invulnerable_until", 0.0)
	percht._charge_left = 0.0
	# Back where they first saw each other: the miner near the station, the Percht down the tunnel.
	percht.global_position = at + Vector3.UP * 0.2
	percht.velocity = Vector3.ZERO
	percht.look_at(Vector3(stand.x, percht.global_position.y, stand.z), Vector3.UP)
	player.teleport(Transform3D(_game.mine_cage.global_basis, stand))
	print("[scenario] percht: miner %.1f m away in plain sight" % player.global_position.distance_to(percht.global_position))
	var saw_windup: bool = false
	var saw_charge: bool = false
	for frame: int in 240:
		await get_tree().physics_frame
		saw_windup = saw_windup or percht.state == Percht.State.WINDUP
		saw_charge = saw_charge or percht.state == Percht.State.CHARGE
	print("[scenario] percht: windup %s, charge %s, player health %d, knocked %s" % [saw_windup, saw_charge, player.health, player.knocked_left > 0.0 or player.health < config.player_max_health])
	var before: int = percht.health
	_game.request_hit(percht.get_path(), 5000, player.global_position, true)
	await get_tree().physics_frame
	print("[scenario] percht: killed %s (had %d)" % [not is_instance_valid(percht) or percht.is_queued_for_deletion(), before])


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
	var can_act: bool = player.can_act()
	player.inventory.select(0)
	var fired: bool = player.gunner.fire() if player.gunner != null else false
	print("[scenario] salzweibl: lone miner pinned %s, can act %s, could shoot %s, health %d" % [player.pinned, can_act, fired, player.health])
	# Solo it lets go after a few seconds.
	await get_tree().create_timer(Balance.config.salzweibl_pin_seconds_solo + 0.5).timeout
	print("[scenario] salzweibl let go: pinned %s, health %d, shown %s" % [player.pinned, player.health, weibl.net_shown])


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
	# Aiming down the sights: the bead and the notch sit on the screen centre, where shots go.
	Input.action_press(&"aim")
	await get_tree().create_timer(0.6).timeout
	var sights: PackedStringArray = []
	for part: String in ["Bead", "NotchL"]:
		var at: Vector3 = player.camera.to_local((pistol.find_child(part, false, false) as Node3D).global_position)
		sights.append("%s %.2f°" % [part, rad_to_deg(atan2(Vector2(at.x, at.y).length(), -at.z))])
	Input.action_release(&"aim")
	print("[scenario] sights off the centre while aiming: %s" % ", ".join(sights))
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
	await get_tree().create_timer(14.0).timeout
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


## Walks forward for a few seconds and measures how evenly the camera and a held gun move from
## one rendered frame to the next (stutter = uneven steps).
func _smooth() -> void:
	if "--no-interp" in OS.get_cmdline_user_args():
		get_tree().physics_interpolation = false  # the old behaviour, for comparison
	for creature: Creature in _game.creatures():
		creature.queue_free()
	var player: Player = _game.local_player()
	player.teleport(Transform3D(_game.mine_cage.global_basis, _out_of_station(3.0)))
	await get_tree().create_timer(1.0).timeout
	for slot: int in player.inventory.slots.size():
		if player.inventory.slots[slot] != null:
			player.inventory.select(slot)
	Input.action_press(&"move_forward")
	await get_tree().create_timer(0.8).timeout
	var probe: SmoothProbe = SmoothProbe.new()
	probe.gun = player.gunner.weapon_item() if player.gunner != null else null
	add_child(probe)
	await get_tree().create_timer(0.3).timeout
	probe.camera = player.camera
	var speeds: Array[float] = []
	var wobble: float = 0.0
	var last: Vector3 = player.camera.global_position
	var last_time: int = Time.get_ticks_usec()
	var gun: WorldItem = player.gunner.weapon_item() if player.gunner != null else null
	for i: int in 180:
		await get_tree().process_frame
		var now: Vector3 = player.camera.global_position
		var time: int = Time.get_ticks_usec()
		speeds.append(Vector2(now.x - last.x, now.z - last.z).length() / maxf(0.000001, get_process_delta_time()))
		last = now
		last_time = time
		if gun != null and gun.follow != null:
			wobble = maxf(wobble, gun.global_position.distance_to(gun.follow.global_position))
	Input.action_release(&"move_forward")
	var mean: float = 0.0
	for speed: float in speeds:
		mean += speed
	mean /= speeds.size()
	var variance: float = 0.0
	for speed: float in speeds:
		variance += (speed - mean) * (speed - mean)
	print("[scenario] smooth: %d frames at %d fps, speed %.2f m/s, uneven %.0f %%, gun off its point at draw time %.3f m, uneven at draw time %.0f %%" % [speeds.size(),
			Engine.get_frames_per_second(), mean, sqrt(variance / speeds.size()) / maxf(mean, 0.0001) * 100.0, probe.worst, probe.unevenness()])
	probe.queue_free()


## Gives the local player a fresh `id` in the selected pocket slot.
func _give(id: StringName) -> WorldItem:
	var player: Player = _game.local_player()
	var item: WorldItem = _game._spawn_item_at(id, 0, player.global_transform.translated(Vector3.UP * 1.0))
	await get_tree().create_timer(0.3).timeout
	_game.request_take(item.get_path(), player.peer_id)
	await get_tree().create_timer(0.2).timeout
	player.inventory.select(player.inventory.slots.find(item))
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
	# M8: the client fires a flare and throws Dynamit.
	for id: StringName in [&"leuchtpistole", &"dynamit"]:
		var tool: WorldItem = _game._spawn_item_at(id, 0, client.global_transform.translated(Vector3.UP * 1.0), "ITool_%s" % id)
		await get_tree().create_timer(0.5).timeout
		_game.request_take(tool.get_path(), client.peer_id)
		await get_tree().create_timer(4.0).timeout
	host.teleport(_game.mine_cage.player_spot(0))
	await _game.dev_deliver()
	_game.request_lift()


## M7: the Fundstück loop, start to finish, and then a shift that runs out of time.
func _fundstueck() -> void:
	for creature: Creature in _game.creatures():
		creature.queue_free()
	var player: Player = _game.local_player()
	var cage: Foerderkorb = _game.mine_cage
	var item: FundstueckItem = _game.fundstueck
	var fundort: Vector2i = _game.mine.layout.fundort
	var in_fundort: bool = Vector2(item.global_position.x, item.global_position.z).distance_to(Vector2(fundort.x, fundort.y) * _game.mine.chunk_set.cell_size) < _game.mine.chunk_set.cell_size * 0.5
	print("[scenario] fundstueck %s in the Fundort %s, %.0f m from the cage, board %s" % [item.data.id, in_fundort, item.global_position.distance_to(cage.global_position), _game.run_info.get("auftrag", "")])
	player.teleport(cage.player_spot(0))
	await get_tree().create_timer(0.3).timeout
	_game.request_lift()
	await get_tree().create_timer(0.5).timeout
	print("[scenario] lever without it: phase %s, alarm %s" % [Game.Phase.keys()[_game.phase], _game.alarm_on])
	player.teleport(Transform3D(Basis.IDENTITY, item.global_position + Vector3(0.0, -1.0, 1.2)))
	await get_tree().create_timer(0.5).timeout
	_game.request_take(item.get_path(), player.peer_id)
	await get_tree().create_timer(0.5).timeout
	print("[scenario] taken: %s, alarm %s, %.0f s left, carrier P%d" % [WorldItem.State.keys()[item.state], _game.alarm_on, _game.alarm_left, _game.fundstueck_carrier().peer_id if _game.fundstueck_carrier() != null else 0])
	player.set_meta(&"invulnerable_until", INF)  # the waves are for the count, not the fight
	await get_tree().create_timer(9.0).timeout
	print("[scenario] after the first wave: %d creatures" % _game.creatures().size())
	player.teleport(cage.player_spot(0))
	await get_tree().create_timer(0.5).timeout
	var money_before: int = GameState.run.money
	print("[scenario] on board %s" % _game.fundstueck_on_board())
	_game.request_lift()
	while _game.phase != Game.Phase.HUB:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	print("[scenario] delivered: shift %d, money +%d, ehrenzeichen %d, fired %s" % [GameState.run.shift_index + 1, GameState.run.money - money_before, GameState.run.ehrenzeichen, GameState.run.fired])
	player.remove_meta(&"invulnerable_until")
	_game.hud.close_panels()
	# The second shift: the timer runs out.
	_game.request_lift()
	while _game.phase != Game.Phase.SHIFT:
		await get_tree().process_frame
	for creature: Creature in _game.creatures():
		creature.queue_free()
	await _game.dev_deliver()  # moved off its place: the alarm
	await get_tree().create_timer(0.3).timeout
	_game.fundstueck.host_move(Transform3D(Basis.IDENTITY, _game._fundstueck_home))
	_game.alarm_left = 1.0
	while _game.phase == Game.Phase.SHIFT:
		await get_tree().process_frame
	while _game.phase == Game.Phase.ASCENDING:
		await get_tree().process_frame
	print("[scenario] timed out: phase %s, fired %s, score %s" % [Game.Phase.keys()[_game.phase], GameState.run.fired, GameState.run.score()])


## Two pulls of the mine lever without the Fundstück: given up, fired.
func _give_up() -> void:
	_game.local_player().teleport(_game.mine_cage.player_spot(0))
	await get_tree().create_timer(0.3).timeout
	_game.request_lift()
	await get_tree().create_timer(1.0).timeout
	_game.request_lift()
	while _game.phase != Game.Phase.OVER:
		await get_tree().process_frame
	print("[scenario] gave up: fired %s" % GameState.run.fired)


## Da Bergkini at the Fundort: the Fundstück locked, the fight, and free once he is dead.
func _boss() -> void:
	var player: Player = _game.local_player()
	var item: FundstueckItem = _game.fundstueck
	var boss: Creature = _game._boss
	for creature: Creature in _game.creatures():
		if creature != boss:
			creature.queue_free()
	await get_tree().create_timer(0.5).timeout
	print("[scenario] boss %s, health %d, fundstueck locked %s" % [boss.data.id if boss != null else "none", boss.health if boss != null else 0, item.locked])
	_game.request_take(item.get_path(), player.peer_id)
	await get_tree().create_timer(0.3).timeout
	print("[scenario] taking it while he lives: %s, alarm %s" % [WorldItem.State.keys()[item.state], _game.alarm_on])
	# In sight of him at the mouth of his hall.
	var mouth: Vector3 = boss.global_position - (boss.global_position - _game.mine_cage.global_position).normalized() * 0.0
	# The mouth of his hall if no waypoint 6–9 m off has him in sight (never on top of him).
	var fundort: Chunk = _game.mine.chunks[_game.mine.layout.fundort]
	var best: Vector3 = (fundort.find_child("Nav_Mouth", true, false) as Marker3D).global_position
	for id: int in _game.mine.nav.get_point_ids():
		var point: Vector3 = _game.mine.nav.get_point_position(id)
		var gap: float = point.distance_to(mouth)
		if gap > 6.0 and gap < 9.0 and _game.clear_line(point + Vector3.UP * 1.5, boss.global_position + Vector3.UP * 1.0):
			best = point
	player.teleport(Transform3D(Basis.IDENTITY, best + Vector3.UP * 0.1))
	player.set_meta(&"invulnerable_until", INF)
	print("[scenario] miner %.1f m from the boss" % best.distance_to(boss.global_position))
	var bergmandl_before: int = _game.alive_count(&"bergmandl")
	await get_tree().create_timer(9.0).timeout
	print("[scenario] boss state %s, bergmandl %d -> %d" % [Bergkini.State.keys()[(boss as Bergkini).state], bergmandl_before, _game.alive_count(&"bergmandl")])
	_game.request_hit(boss.get_path(), 5000, player.global_position)
	await get_tree().create_timer(0.8).timeout
	print("[scenario] boss dead %s, fundstueck locked %s" % [not is_instance_valid(boss), item.locked])
	player.teleport(Transform3D(Basis.IDENTITY, item.global_position + Vector3(0.0, -1.0, 1.2)))
	await get_tree().create_timer(0.5).timeout
	_game.request_take(item.get_path(), player.peer_id)
	await get_tree().create_timer(0.5).timeout
	print("[scenario] taken after the boss: %s, alarm %s" % [WorldItem.State.keys()[item.state], _game.alarm_on])


## For screenshots: Da Bergkini awake in his hall, seen from its mouth.
func _boss_look() -> void:
	var player: Player = _game.local_player()
	var boss: Creature = _game._boss
	for creature: Creature in _game.creatures():
		if creature != boss:
			creature.queue_free()
	var fundort: Chunk = _game.mine.chunks[_game.mine.layout.fundort]
	var mouth: Marker3D = fundort.find_child("Nav_Mouth", true, false) as Marker3D
	player.teleport(Transform3D(Basis.IDENTITY, mouth.global_position + Vector3.UP * 0.1))
	player.set_meta(&"invulnerable_until", INF)
	await get_tree().create_timer(0.5).timeout
	player.look_at(Vector3(boss.global_position.x, player.global_position.y, boss.global_position.z))
	boss.host_stun(4.0)


## Upgrades bought in the Gasthaus: guns, caps, lamp and armour change on this peer.
func _upgrades_hub() -> void:
	var player: Player = _game.local_player()
	GameState.run.add_cheat_money(2000)
	var pistol: ItemData = _game.catalog.by_id(&"dienstpistole")
	var magazine_before: int = pistol.weapon.magazine
	for id: StringName in [&"pistole_magazine", &"pistole_damage", &"lederschurz", &"grubenhelm", &"cap_pistole", &"reflektor"]:
		_game.request_buy_upgrade(id)
	_game.request_buy_upgrade(&"pistole_magazine")  # only one level: refused
	await get_tree().create_timer(0.5).timeout
	print("[scenario] upgrades: pistol magazine %d -> %d, damage %d, pistol cap %d, armour %d, lamp x%.2f, money %d" % [magazine_before, pistol.weapon.magazine,
			pistol.weapon.damage, _game.ammo_cap(&"pistole"), player.armour, _game.lamp_mult, GameState.run.money])


## M9: Ehrenzeichen buy perks on the Knappenbrief; the host learns what they bring.
func _knappenbrief_hub() -> void:
	var player: Player = _game.local_player()
	var profile: PlayerProfile = GameState.profile
	profile.earn(100)
	for id: StringName in [&"gsund", &"gsund", &"eigene_flinte", &"munition_schrot", &"startgeld", &"lederweste", &"sanitaeter", &"grubentaschn", &"hut_knappe", &"lampe_mond"]:
		profile.buy(Balance.config.perk(id))
	var money_before: int = GameState.run.money
	for sheet: int in 2:
		_game.hud._brief_sheet = sheet
		_game.hud.open_knappenbrief()
	_game.hud._on_perk_choice(&"eigene_flinte", false)
	_game.hud._on_perk_choice(&"eigene_flinte", true)  # sends the loadout to the host
	_game.hud.close_panels()
	GameState.run.add_cheat_money(1000)
	for id: StringName in [&"rucksack", &"batterie"]:
		_game.request_buy_upgrade(id)
	await get_tree().create_timer(0.5).timeout
	print("[scenario] knappenbrief: honours %d left, max health %d, health %d, start money +%d, slots %d, help up %.1f s, armour %d, lamp %s" % [profile.ehrenzeichen,
			player.max_health, player.health, GameState.run.money + _spent_on([&"rucksack", &"batterie"]) - money_before - 1000, player.inventory.open_slots,
			player.interact_hold_seconds(player), player.armour, player.beam.light_color.b > player.beam.light_color.r])
	# A second loadout (bought more) brings no second starting money.
	money_before = GameState.run.money
	player.submit_loadout.rpc_id(1, profile.loadout())
	await get_tree().create_timer(0.3).timeout
	print("[scenario] knappenbrief: again +%d" % (GameState.run.money - money_before))


func _spent_on(ids: Array[StringName]) -> int:
	var spent: int = 0
	for id: StringName in ids:
		spent += Balance.config.run_upgrade(id).price_after(0)
	return spent


func _knappenbrief_mine() -> void:
	for creature: Creature in _game.creatures():
		creature.queue_free()
	var player: Player = _game.local_player()
	await get_tree().create_timer(1.5).timeout
	print("[scenario] knappenbrief kit: flinte %s, pistol %s, shells %d, pistol rounds %d, armour %d, battery %.0f s" % [player.has_tool(&"salzschrot_flinte"),
			player.has_tool(&"dienstpistole"), player.ammo_count(&"schrot"), player.ammo_count(&"pistole"), player.armour, player.battery_max()])
	var before: int = GameState.profile.ehrenzeichen
	await _game.dev_deliver()
	_game.request_lift()
	while _game.phase != Game.Phase.HUB:
		await get_tree().process_frame
	print("[scenario] knappenbrief: delivered, honours %d -> %d" % [before, GameState.profile.ehrenzeichen])


## M9: the Überstunden in force; a ping and the crew overlay.
func _overtime_mine() -> void:
	var lit: int = 0
	for light: OmniLight3D in _game.mine.lights:
		lit += 1 if light.visible else 0
	var boxes: int = 0
	for item: WorldItem in _game._items():
		boxes += 1 if item.data.kind == ItemData.Kind.AMMO else 0
	var dog: Creature = null
	for creature: Creature in _game.creatures():
		if creature.data.id == &"grubenhund" and dog == null:
			dog = creature
		elif creature.data.id != &"grubenhund":
			creature.queue_free()
	var player: Player = _game.local_player()
	if dog == null:
		dog = _game.spawn_creature(&"grubenhund", Transform3D(Basis.IDENTITY, _out_of_station(8.0)))
	await get_tree().create_timer(0.5).timeout
	var health: int = dog.health
	dog.host_damage(20, player.global_position)
	print("[scenario] overtime: lanterns lit %d of %d, shift %.0f s, ammo boxes %d, dog health %d (base %d), hit 20 -> -%d" % [lit, _game.mine.lights.size(),
			_game.shift_length, boxes, health, Balance.config.grubenhund_health, health - dog.health])
	dog.process_mode = Node.PROCESS_MODE_DISABLED
	player.look_at(dog.global_position + Vector3.UP * 0.4)
	player.head.rotation.x = 0.0
	player._place_camera()
	player.ping()
	await get_tree().create_timer(0.5).timeout
	print("[scenario] ping: marks %d" % _game.hud.team.ping_count())
	await _game.dev_deliver()
	while not _game.alarm_on:
		await get_tree().process_frame
	var run: RunState = GameState.run
	var usual: float = Balance.config.rueckweg_seconds(run.shift_index, run.player_count, _game._way_to_lift(_game._fundstueck_home))
	print("[scenario] overtime alarm: %.2f of the usual" % (_game.alarm_length / usual))


func _upgrades_mine() -> void:
	for creature: Creature in _game.creatures():
		creature.queue_free()
	var player: Player = _game.local_player()
	await get_tree().create_timer(1.0).timeout
	var kit: WorldItem = null
	for item: Object in player.inventory.slots:
		if item != null and (item as WorldItem).data.id == &"dienstpistole":
			kit = item as WorldItem
	var armour: int = player.armour
	_game.host_damage_player(player, 20)
	print("[scenario] in the mine: kit pistol rounds %d, armour %d -> %d, health %d" % [kit.rounds if kit != null else -1, armour, player.armour, player.health])


## Client side: uses every tool that lands in a pocket, the way a player would (click).
func _mp_tools_client() -> void:
	while _game.phase != Game.Phase.SHIFT:
		await get_tree().process_frame
	var me: Player = _game.local_player()
	var used: Dictionary = {}
	var cart_from: Vector3 = Vector3.INF
	for i: int in 220:
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
	var host: Player = _game.player_by_peer(1)
	if host != null:
		print("[scenario] client sees the host: max health %d, hat %s" % [host.max_health, host.head.get_node_or_null(^"HatPoint/CosmeticHat") != null])
	while _game.phase != Game.Phase.SHIFT:
		await get_tree().process_frame
	var me: Player = _game.local_player()
	me.ping()
	var seen: Dictionary = {}
	_track_when_thrown()
	_send_test_voice(me)
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


## One second of a tone as voice packets, the way the voice chat sends them (no microphone in
## headless runs): the host must get them and keep them as a snippet.
func _send_test_voice(me: Player) -> void:
	await get_tree().create_timer(1.0).timeout
	for i: int in 25:
		var samples: PackedFloat32Array = PackedFloat32Array()
		for n: int in Mic.PACKET_SAMPLES:
			samples.append(sin(TAU * 220.0 * (i * Mic.PACKET_SAMPLES + n) / Mic.RATE) * 0.3)
		me.voice_chat._voice_packet.rpc(Mic.encode(samples))
		await get_tree().create_timer(0.04).timeout
	print("[scenario] client sent 1 s of voice")


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


## Points the local player's eyes at `point`.
func _aim_at(player: Player, point: Vector3) -> void:
	player.look_at(Vector3(point.x, player.global_position.y, point.z))
	await get_tree().physics_frame
	var aim: Vector3 = point - player.camera.global_position
	player.head.rotation.x = atan2(aim.y, Vector2(aim.x, aim.z).length())
	player._place_camera()  # process_frame comes before the player's own _process
	await get_tree().process_frame


## Aims down the sights at point and pulls the trigger (like a player would).
func _shoot_at(player: Player, point: Vector3) -> bool:
	Input.action_press(&"aim")
	await get_tree().create_timer(0.6).timeout
	await _aim_at(player, point)
	player.gunner._cooldown = 0.0
	var fired: bool = player.gunner.fire()
	Input.action_release(&"aim")
	return fired


## A spot `metres` in front of the player along the tunnel with nothing in between.
func _ahead(player: Player, metres: float) -> Vector3:
	var nav: AStar3D = _game.mine.nav
	var best: Vector3 = player.global_position - player.global_basis.z * metres
	var best_gap: float = INF
	for id: int in nav.get_point_ids():
		var point: Vector3 = nav.get_point_position(id)
		var gap: float = absf(point.distance_to(player.global_position) - metres)
		if gap < best_gap and _game.clear_line(player.camera.global_position, point + Vector3.UP * 0.6):
			best_gap = gap
			best = point
	return best


## M10 feel: what the mine's bodies are made of (rock, timber, iron), a shot leaving its hole, a
## dead dog its pool, Da Bergkini's head, and a weapon coming up when taken in hand.
func _impacts() -> void:
	for creature: Creature in _game.creatures():
		creature.queue_free()
	var player: Player = _game.local_player()
	player.set_meta(&"invulnerable_until", INF)
	var counts: Array[int] = [0, 0, 0]
	var bodies: Array[Node] = _game.mine.find_children("*", "StaticBody3D", true, false)
	bodies.append(_game.mine_cage.get_node(^"Floor"))
	for body: Node in bodies:
		counts[ImpactFx.surface_of(body)] += 1
	print("[scenario] surfaces: rock %d, wood %d, metal %d, cage floor %s" % [counts[0], counts[1], counts[2],
			ImpactFx.Surface.keys()[ImpactFx.surface_of(_game.mine_cage.get_node(^"Floor"))]])
	player.teleport(Transform3D(_game.mine_cage.global_basis, _out_of_station(5.0)))
	await get_tree().create_timer(0.5).timeout
	var pistol: WorldItem = null
	var pick: WorldItem = null
	for item: Variant in player.inventory.slots:
		if item is WorldItem and (item as WorldItem).data.id == &"dienstpistole":
			pistol = item
		elif item is WorldItem and (item as WorldItem).data.id == &"spitzhacke":
			pick = item
	player.inventory.select(player.inventory.slots.find(pick))
	await get_tree().create_timer(0.5).timeout
	player.inventory.select(player.inventory.slots.find(pistol))
	await get_tree().process_frame
	await get_tree().process_frame
	print("[scenario] draw: just taken %.2f" % player.gunner.view._draw)
	await get_tree().create_timer(0.5).timeout
	print("[scenario] draw: after 0.5 s %.2f" % player.gunner.view._draw)
	# A shot into the rock beside the tunnel.
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var from: Vector3 = player.camera.global_position
	var wall: Dictionary = {}
	for i: int in 16:
		var out: Vector3 = (-player.global_basis.z).rotated(Vector3.UP, TAU * i / 16.0)
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + out * 12.0, 1))
		if not hit.is_empty() and from.distance_to(hit.position) > 1.5 and ImpactFx.surface_of(hit.collider) == ImpactFx.Surface.ROCK:
			wall = hit
			break
	var marks_before: int = ImpactFx._marks.size()
	var fired: bool = not wall.is_empty() and await _shoot_at(player, wall.position)
	await get_tree().create_timer(0.3).timeout
	print("[scenario] shot the rock %s: marks %d -> %d" % [fired, marks_before, ImpactFx._marks.size()])
	# A dog dies: its pool spreads under it.
	var dog: Creature = _game.spawn_creature(&"grubenhund", Transform3D(Basis.IDENTITY, _ahead(player, 4.0) + Vector3.UP * 0.3))
	dog.host_stun(30.0)
	await get_tree().create_timer(0.8).timeout
	marks_before = ImpactFx._marks.size()
	dog.host_damage(999, player.global_position)
	await get_tree().create_timer(0.5).timeout
	print("[scenario] dog died: marks %d -> %d" % [marks_before, ImpactFx._marks.size()])
	# Da Bergkini's head under the crown.
	var king: Bergkini = _game.spawn_creature(&"bergkini", Transform3D(Basis.IDENTITY, _ahead(player, 6.0) + Vector3.UP * 0.3)) as Bergkini
	await get_tree().create_timer(0.5).timeout
	var crown: Node3D = king.body.get_node(^"Crown") as Node3D
	var head: Vector3 = crown.global_position - king.body.global_basis.y.normalized() * 0.12 * king.body.global_basis.get_scale().x
	print("[scenario] bergkini head x%.2f, belly x%.2f" % [king.weak_spot_mult(head), king.weak_spot_mult(king.global_position + Vector3.UP * 0.5)])
	king.queue_free()
	print("[scenario] impacts done")


## M8 weapons: the Stutzen (a dog's head, the bolt, round-by-round reloading), the Leuchtpistole
## (a flare that burns, lights a Kasermandl and blinds the Schichtmeister) and Dynamit (the blast,
## the roof).
func _weapons() -> void:
	for creature: Creature in _game.creatures():
		creature.queue_free()
	var player: Player = _game.local_player()
	var config: BalanceConfig = Balance.config
	player.teleport(Transform3D(_game.mine_cage.global_basis, _out_of_station(5.0)))
	player.set_meta(&"invulnerable_until", INF)
	for light: OmniLight3D in _game.mine.lights:
		light.visible = false
	await get_tree().create_timer(0.5).timeout
	# The Stutzen, loaded round by round.
	var stutzen: WorldItem = await _give(&"mannlicher_stutzen")
	_game._to_peer(player.peer_id, player, &"give_ammo", [&"gewehr", 10, false])
	await get_tree().create_timer(0.2).timeout
	player.gunner.start_reload()
	await get_tree().create_timer(stutzen.data.weapon.reload_seconds * 5.0 + 1.0).timeout
	print("[scenario] stutzen loaded %d, spare %d" % [stutzen.rounds, player.ammo_count(&"gewehr")])
	var spot: Vector3 = _ahead(player, 7.0)
	var dog: Grubenhund = _game.spawn_creature(&"grubenhund", Transform3D(Basis.IDENTITY, spot + Vector3.UP * 0.3)) as Grubenhund
	dog.host_stun(30.0)
	await get_tree().create_timer(0.6).timeout
	dog.look_at(Vector3(player.global_position.x, dog.global_position.y, player.global_position.z), Vector3.UP)
	await get_tree().physics_frame
	var head: Vector3 = dog.body.to_global(Grubenhund.HEAD_AT)
	print("[scenario] dog head x%.2f, flank x%.2f" % [dog.weak_spot_mult(head), dog.weak_spot_mult(dog.global_position + Vector3.UP * 0.3 + dog.global_basis.z * 0.4)])
	var fired: bool = await _shoot_at(player, head)
	await get_tree().create_timer(0.5).timeout
	print("[scenario] stutzen fired %s, rounds %d, dog dead %s" % [fired, stutzen.rounds, not is_instance_valid(dog) or dog.is_queued_for_deletion()])
	# The Leuchtpistole: a flare by a Kasermandl in the dark lights it up.
	_game.request_drop(stutzen.get_path(), player.hand_point.global_transform, Vector3.ZERO)  # a weapon slot for it
	await get_tree().create_timer(0.3).timeout
	player.lamp_on = false
	var flare_gun: WorldItem = await _give(&"leuchtpistole")
	_game._to_peer(player.peer_id, player, &"give_ammo", [&"leucht", 3, false])
	await get_tree().create_timer(0.2).timeout
	player.gunner.start_reload()
	await get_tree().create_timer(flare_gun.data.weapon.reload_seconds + 0.6).timeout
	var kaser_at: Vector3 = _ahead(player, 8.0)
	var kaser: Kasermandl = _game.spawn_creature(&"kasermandl", Transform3D(Basis.IDENTITY, kaser_at + Vector3.UP * 0.2)) as Kasermandl
	kaser.host_stun(30.0)
	await get_tree().create_timer(0.5).timeout
	print("[scenario] kasermandl in the dark: lit %s" % kaser._is_lit())
	var shot: bool = await _shoot_at(player, kaser_at + (player.global_position - kaser_at).normalized() * 1.2)
	await get_tree().create_timer(1.5).timeout
	print("[scenario] flare fired %s, burning %d, kasermandl lit %s, leucht left %d" % [shot, _game.flares.size(), kaser._is_lit(), player.ammo_count(&"leucht")])
	kaser.queue_free()
	# A flare in the Schichtmeister's face blinds him.
	player.gunner.start_reload()
	await get_tree().create_timer(flare_gun.data.weapon.reload_seconds + 0.6).timeout
	var meister: Creature = _game.spawn_creature(&"schichtmeister", Transform3D(Basis.IDENTITY, _ahead(player, 6.0) + Vector3.UP * 0.2))
	meister.host_stun(1.0)
	await get_tree().create_timer(0.3).timeout
	await _shoot_at(player, meister.global_position + Vector3.UP * 1.2)
	await get_tree().create_timer(0.8).timeout
	print("[scenario] schichtmeister after the flare: stunned %.1f s" % meister.stunned_left)
	meister.queue_free()
	# Dynamit: the blast, and the roof comes down.
	config.dynamit_roof_chance = 1.0
	await _give(&"dynamit")
	player.head.rotation.x = 0.2
	player._use_cooldown = 0.0
	player._use_active()
	await get_tree().create_timer(config.dynamit_fuse_seconds + 1.0).timeout
	print("[scenario] dynamit thrown, items left in slot 4: %s" % (player.inventory.slots[3] != null))


## A Fundort boss for the scenario `kind` ("seemuada", "schiachpercht"): she wakes, fights a
## miner who stands in her hall, then is killed and the Fundstück is free.
func _boss_fight(kind: String) -> void:
	var player: Player = _game.local_player()
	var boss: Creature = _game._boss
	for creature: Creature in _game.creatures():
		if creature != boss:
			creature.queue_free()
	if boss == null:
		print("[scenario] no boss")
		return
	var fundort: Chunk = _game.mine.chunks[_game.mine.layout.fundort]
	var centre: Marker3D = fundort.find_child("Nav_C", true, false) as Marker3D
	player.teleport(Transform3D(Basis.IDENTITY, centre.global_position + Vector3.UP * 0.1))
	player.set_meta(&"invulnerable_until", INF)
	player.lamp_on = true
	await get_tree().create_timer(0.5).timeout
	print("[scenario] boss %s, health %d, fundstueck locked %s" % [boss.data.id, boss.health, _game.fundstueck.locked])
	for i: int in 40:
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(boss):
			player.look_at(Vector3(boss.global_position.x, player.global_position.y, boss.global_position.z))
		if kind == "seemuada" and (boss as Seemuada).state == Seemuada.State.UP and i > 16:
			break
	if kind == "seemuada":
		var queen: Seemuada = boss as Seemuada
		print("[scenario] seemuada %s, shootable %s, head x%.2f, neck x%.2f" % [Seemuada.State.keys()[queen.state], queen.can_be_shot(),
				queen.weak_spot_mult(queen._head.global_position), queen.weak_spot_mult(queen.global_position + Vector3.UP * 0.6)])
	_game.request_hit(boss.get_path(), 50000, player.global_position, true)
	await get_tree().create_timer(0.8).timeout
	print("[scenario] boss dead %s, fundstueck locked %s" % [not is_instance_valid(boss), _game.fundstueck.locked])


## Raunacht elites: tougher than the plain ones, and a box of ammo when they die.
func _elites() -> void:
	for creature: Creature in _game.creatures():
		creature.queue_free()
	var player: Player = _game.local_player()
	player.teleport(Transform3D(_game.mine_cage.global_basis, _out_of_station(5.0)))
	await get_tree().create_timer(0.5).timeout
	var at: Vector3 = _out_of_station(14.0) + Vector3.UP * 0.3
	var plain: Creature = _game.spawn_creature(&"grubenhund", Transform3D(Basis.IDENTITY, at))
	var elite: Creature = _game.spawn_creature(&"grubenhund", Transform3D(Basis.IDENTITY, at + Vector3(1.0, 0.0, 0.0)), true)
	plain.host_stun(10.0)
	elite.host_stun(10.0)
	await get_tree().create_timer(0.5).timeout
	print("[scenario] elite health %d vs %d, speed x%.2f, glow %s" % [elite.health, plain.health, elite.speed_mult(), elite.find_child("RaunachtGlow", true, false) != null])
	var boxes: int = _ammo_boxes()
	_game.request_hit(elite.get_path(), 5000, player.global_position)
	await get_tree().create_timer(0.5).timeout
	print("[scenario] elite dead, ammo boxes +%d" % (_ammo_boxes() - boxes))


## Measures, after every other node has processed (just before drawing), how far a held gun is
## from the point it should sit at.
class SmoothProbe:
	extends Node
	var gun: WorldItem
	var camera: Camera3D
	var worst: float = 0.0
	var speeds: Array[float] = []
	var _last: Vector3 = Vector3.INF

	func _ready() -> void:
		process_priority = 1000

	func _process(_delta: float) -> void:
		if gun != null and is_instance_valid(gun) and gun.follow != null:
			worst = maxf(worst, gun.global_position.distance_to(gun.follow.global_position))
		if camera != null:
			var now: Vector3 = camera.global_position
			if _last != Vector3.INF:
				speeds.append(Vector2(now.x - _last.x, now.z - _last.z).length() / maxf(0.000001, _delta))
			_last = now

	func unevenness() -> float:
		var mean: float = 0.0
		for speed: float in speeds:
			mean += speed
		mean /= maxf(1.0, speeds.size())
		var variance: float = 0.0
		for speed: float in speeds:
			variance += (speed - mean) * (speed - mean)
		return sqrt(variance / maxf(1.0, speeds.size())) / maxf(mean, 0.0001) * 100.0
