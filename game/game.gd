class_name Game
extends Node3D
## The one game scene: the Gasthaus (hub) high above, the generated mine below, players, items,
## creatures, the HUD and the main menu on top. Host-authoritative (DESIGN.md §11): peers ask
## the host with `request_*` RPCs, the host changes the world and tells every peer. Solo is a
## host with zero clients, so the very same code runs.
##
## Shift flow (host): lever in the Gasthaus -> ride down (mine built from a seed on every peer)
## -> shift timer -> Grubenpfeife + grace -> ride up (early with the mine lever) -> loot in the
## Gasthaus is sold -> results / quota check.

enum Phase { MENU, HUB, DESCENDING, SHIFT, ASCENDING, OVER }

## Everything above this height is the Gasthaus; the mine is built around y = 0.
const HUB_FLOOR_ABOVE: float = 200.0
const RIDE_SECONDS: float = 3.5
const FADE_SECONDS: float = 0.6
const CHUNKS: ChunkSet = preload("res://world/chunks/oberer_stollen/oberer_stollen.tres")
const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")
const CAGE_SCENE: PackedScene = preload("res://world/lift/foerderkorb.tscn")
const MINE_ENVIRONMENT: Environment = preload("res://world/mine_environment.tres")
const HUB_ENVIRONMENT: Environment = preload("res://hub/hub_environment.tres")
## Loaded at runtime, not preloaded: their scenes' scripts refer back to Game.
const CATALOG_PATH: String = "res://items/item_catalog.tres"
const CREATURE_PATHS: PackedStringArray = ["res://enemies/bergmandl/bergmandl.tres"]
const AMBIENCE: PackedStringArray = ["drip", "drip", "drip", "creak", "creak", "rumble"]
## Dev/smoke flag: ride down right away, play a few seconds, ride up again.
const AUTO_SHIFT_ARG: String = "--auto-shift"
## Dev flag: save a screenshot every SHOT_SECONDS into this folder (needs a window).
const SHOTS_ARG: String = "--shots="
const SHOT_SECONDS: float = 1.5
## Dev flag: run a scripted situation from tools/dev/dev_scenario.gd.
const SCENARIO_ARG: String = "--scenario="
const SCENARIO_SCRIPT: String = "res://tools/dev/dev_scenario.gd"

static var instance: Game

var phase: Phase = Phase.MENU
var whistle_blown: bool = false
var shift_length: float = 0.0
## Seconds until the whistle; negative during the grace period. Every peer counts locally.
var shift_time_left: float = 0.0
var mine: Mine
var mine_cage: Foerderkorb
## The run as last sent by the host (money, quota, ...), for HUD and notice board.
var run_info: Dictionary = {}
var catalog: ItemCatalog
var creature_types: Array[EnemyData] = []

var _config: BalanceConfig
var _next_item: int = 0
var _next_creature: int = 0
var _ready_peers: Dictionary = {}
var _enemy_budget_left: float = 0.0
var _trickle_left: float = 0.0
var _ambience_left: float = 5.0
var _voice_quiet_until: float = 0.0

@onready var hub: Gasthaus = $Hub
@onready var hub_cage: Foerderkorb = $Hub/Foerderkorb
@onready var mine_root: Node3D = $MineRoot
@onready var players_root: Node3D = $Players
@onready var items_root: Node3D = $Items
@onready var creatures_root: Node3D = $Creatures
@onready var hud: Hud = $Hud
@onready var menu_layer: CanvasLayer = $Menu
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var _player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var _item_spawner: MultiplayerSpawner = $ItemSpawner
@onready var _creature_spawner: MultiplayerSpawner = $CreatureSpawner


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	_config = Balance.config
	catalog = load(CATALOG_PATH) as ItemCatalog
	for path: String in CREATURE_PATHS:
		creature_types.append(load(path) as EnemyData)
	_player_spawner.spawn_function = _spawn_player
	_item_spawner.spawn_function = _spawn_item
	_creature_spawner.spawn_function = _spawn_creature
	NetworkManager.session_started.connect(_on_session_started)
	NetworkManager.session_ended.connect(_on_session_ended.unbind(1))
	NetworkManager.peer_left.connect(_on_peer_left)
	hud.leave_requested.connect(leave_session)
	hub.menu_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(SHOTS_ARG):
			_take_shots(arg.trim_prefix(SHOTS_ARG))
		elif arg.begins_with(SCENARIO_ARG) and not ResourceLoader.exists(SCENARIO_SCRIPT):
			print("[game] dev scenarios are not part of this build")
		elif arg.begins_with(SCENARIO_ARG):
			var scenario: Node = (load(SCENARIO_SCRIPT) as GDScript).new()
			add_child(scenario)
			scenario.call(&"run", self, arg.trim_prefix(SCENARIO_ARG))


func _process(delta: float) -> void:
	_update_environment()
	if phase == Phase.SHIFT:
		shift_time_left -= delta
		_update_clocks()
		_tick_ambience(delta)
		if multiplayer.is_server():
			_host_tick_shift(delta)


# --- session --------------------------------------------------------------------------------------

func _on_session_started() -> void:
	menu_layer.hide()
	phase = Phase.HUB
	if NetworkManager.is_host():
		if GameState.run == null:
			GameState.start_run(NetworkManager.player_count())
			if NetworkManager.player_count() == 1 and _config.solo_free_schubkarre:
				_spawn_item_at(&"schubkarre", 0, hub.free_cart_spot())
		_ready_peers[1] = true
		_spawn_player_for(1)
		_broadcast_run()
		print("[game] hub ready")
		if AUTO_SHIFT_ARG in OS.get_cmdline_user_args():
			_auto_shift()
	else:
		_client_loaded.rpc_id(1)


## A client has the game scene and wants in. Late join is only allowed in the hub (§9).
@rpc("any_peer", "call_remote", "reliable")
func _client_loaded() -> void:
	var peer: int = multiplayer.get_remote_sender_id()
	if phase != Phase.HUB:
		_refuse_join.rpc_id(peer)
		return
	_ready_peers[peer] = true
	_spawn_player_for(peer)
	_broadcast_run()


@rpc("authority", "call_remote", "reliable")
func _refuse_join() -> void:
	NetworkManager.last_end_reason = "NET_SHIFT_RUNNING"
	NetworkManager.leave()
	get_tree().reload_current_scene.call_deferred()


func _on_peer_left(peer: int) -> void:
	_ready_peers.erase(peer)
	var player: Player = player_by_peer(peer)
	if player != null:
		_drop_everything(player)
		player.queue_free()


func _on_session_ended() -> void:
	GameState.end_run()
	get_tree().reload_current_scene.call_deferred()


func leave_session() -> void:
	NetworkManager.leave()
	GameState.end_run()
	NetworkManager.last_end_reason = "NET_LEFT"
	get_tree().reload_current_scene.call_deferred()


# --- spawning -------------------------------------------------------------------------------------

func _spawn_player_for(peer: int) -> void:
	if player_by_peer(peer) != null:
		return
	var index: int = players_root.get_child_count()
	_player_spawner.spawn([peer, hub.player_spot(index)])


func _spawn_player(spawn_data: Array) -> Node:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.peer_id = int(spawn_data[0])
	player.name = "P%d" % player.peer_id
	player.transform = spawn_data[1]
	return player


func _spawn_item_at(id: StringName, value: int, xform: Transform3D) -> WorldItem:
	_next_item += 1
	return _item_spawner.spawn(["I%d" % _next_item, id, value, xform]) as WorldItem


func _spawn_item(spawn_data: Array) -> Node:
	var data: ItemData = catalog.by_id(spawn_data[1])
	var item: WorldItem = data.scene.instantiate() as WorldItem
	item.name = spawn_data[0]
	item.data = data
	item.value = spawn_data[2]
	item.transform = spawn_data[3]
	return item


func _spawn_creature(spawn_data: Array) -> Node:
	var data: EnemyData = null
	for candidate: EnemyData in creature_types:
		if candidate.id == spawn_data[1]:
			data = candidate
	var creature: Creature = data.scene.instantiate() as Creature
	creature.name = spawn_data[0]
	creature.data = data
	creature.transform = spawn_data[2]
	return creature


func _spawn_loot(seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x5a1f
	var spots: Array[Array] = mine.markers_with_depth(&"loot_spawn")
	for i: int in range(spots.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Array = spots[i]
		spots[i] = spots[j]
		spots[j] = swap
	var run: RunState = GameState.run
	var count: int = _config.loot_count(run.cycle, run.player_count)
	var loot: Array[ItemData] = catalog.loot()
	for i: int in count:
		var spot: Array = spots[i % spots.size()]
		var depth: int = spot[1]
		var options: Array[ItemData] = []
		var weights: PackedFloat32Array = []
		for data: ItemData in loot:
			if data.min_depth <= depth:
				options.append(data)
				weights.append(data.spawn_weight)
		var picked: ItemData = options[rng.rand_weighted(weights)]
		var value: int = roundi(rng.randi_range(picked.value_min, picked.value_max) * (1.0 + depth * _config.loot_value_per_depth))
		var xform: Transform3D = (spot[0] as Marker3D).global_transform
		if i >= spots.size():
			xform.origin += Vector3(rng.randf_range(-0.6, 0.6), 0.2, rng.randf_range(-0.6, 0.6))
		_spawn_item_at(picked.id, value, xform)
	print("[game] spawned %d loot items" % count)


func _spawn_creature_group(data: EnemyData) -> int:
	var spots: Array[Vector3] = []
	for spot: Array in mine.markers_with_depth(&"enemy_spawn"):
		var where: Vector3 = (spot[0] as Marker3D).global_position
		if int(spot[1]) >= _config.enemy_min_depth and _distance_to_nearest_player(where) > 15.0:
			spots.append(where)
	if spots.is_empty():
		return 0
	var at: Vector3 = spots.pick_random()
	var size: int = mini(randi_range(_config.bergmandl_group_min, _config.bergmandl_group_max), floori(_enemy_budget_left / data.budget_cost))
	for i: int in size:
		_next_creature += 1
		var offset: Vector3 = Vector3(randf_range(-1.0, 1.0), 0.3, randf_range(-1.0, 1.0))
		_creature_spawner.spawn(["C%d" % _next_creature, data.id, Transform3D(Basis(Vector3.UP, randf() * TAU), at + offset)])
		_enemy_budget_left -= data.budget_cost
	return size


func _spawn_creatures_up_to(share_spent: float) -> void:
	var data: EnemyData = creature_types[0]
	var budget: float = _config.enemy_budget(GameState.run.cycle, GameState.run.player_count)
	var spawned: int = 0
	while _enemy_budget_left >= data.budget_cost and budget - _enemy_budget_left < budget * share_spent:
		var group: int = _spawn_creature_group(data)
		if group == 0:
			break
		spawned += group
	if spawned > 0:
		print("[game] spawned %d %s" % [spawned, data.id])


# --- shift flow (host) ----------------------------------------------------------------------------

## Pulled a lift lever: down from the Gasthaus, or up (early) from the mine.
@rpc("any_peer", "call_local", "reliable")
func request_lift() -> void:
	if not multiplayer.is_server():
		return
	if phase == Phase.HUB:
		_descend()
	elif phase == Phase.SHIFT:
		_ascend()


func _descend() -> void:
	var run: RunState = GameState.run
	var seed_value: int = randi()
	_begin_ride.rpc(true, seed_value, run.cycle)
	await get_tree().create_timer(RIDE_SECONDS).timeout
	if phase != Phase.DESCENDING:
		return
	var index: int = 0
	for item: WorldItem in _items():
		if item.state == WorldItem.State.FREE and hub_cage.contains(item.global_position):
			item.host_move(hub_cage.carry_to(mine_cage, item.global_transform))
	for player: Player in players():
		player.teleport.rpc(mine_cage.player_spot(index))
		player.revive.rpc()
		index += 1
	_spawn_loot(seed_value)
	_enemy_budget_left = _config.enemy_budget(run.cycle, run.player_count)
	_spawn_creatures_up_to(_config.enemy_start_share)
	_trickle_left = _config.enemy_trickle_seconds
	_start_shift.rpc(_config.shift_seconds(run.player_count))


func _host_tick_shift(delta: float) -> void:
	if not whistle_blown and shift_time_left <= 0.0:
		_blow_whistle.rpc()
	elif whistle_blown and shift_time_left <= -_config.whistle_grace_seconds:
		_ascend()
		return
	if not whistle_blown and _enemy_budget_left > 0.0:
		_trickle_left -= delta
		if _trickle_left <= 0.0:
			_trickle_left = _config.enemy_trickle_seconds
			_spawn_creatures_up_to(1.0)
	var anyone_down: bool = false
	for player: Player in players():
		anyone_down = anyone_down or player.alive
	if not anyone_down:
		_ascend()


func _ascend() -> void:
	var riders: Array[Player] = []
	for player: Player in players():
		if player.alive and mine_cage.contains(player.global_position):
			riders.append(player)
	_begin_ride.rpc(false, 0, 0)
	await get_tree().create_timer(RIDE_SECONDS).timeout
	var results: Dictionary = {"sold": [], "total": 0, "left_behind": []}
	var rider_peers: Array[int] = []
	for player: Player in riders:
		rider_peers.append(player.peer_id)
	# What rides up is decided by who holds it, not by where it is: a client's position
	# update may still be on its way.
	var going_up: Array[WorldItem] = []
	for item: WorldItem in _items():
		if item.global_position.y > HUB_FLOOR_ABOVE and item.state == WorldItem.State.FREE:
			continue
		var held_by_rider: bool = item.holder_peer in rider_peers
		var free_in_cage: bool = item.state == WorldItem.State.FREE and mine_cage.contains(item.global_position)
		var carted_up: bool = item.state == WorldItem.State.CARTED and item.cart != null and (item.cart.holder_peer in rider_peers or mine_cage.contains(item.cart.global_position))
		if held_by_rider or free_in_cage or carted_up:
			going_up.append(item)
			if free_in_cage:
				item.host_move(mine_cage.carry_to(hub_cage, item.global_transform))
	var index: int = 0
	for player: Player in players():
		if player in riders:
			player.teleport.rpc(mine_cage.carry_to(hub_cage, player.global_transform))
		else:
			_drop_everything(player)
			(results.left_behind as Array).append(player.peer_id)
			player.teleport.rpc(hub.player_spot(index))
		player.revive.rpc()
		index += 1
	for item: WorldItem in _items():
		if item in going_up:
			if item.is_loot():
				(results.sold as Array).append([item.data.name_key, item.value])
				results.total = int(results.total) + item.value
				item.host_vanish()
		elif item.global_position.y < HUB_FLOOR_ABOVE:
			item.host_vanish()
	for creature: Node in creatures_root.get_children():
		creature.queue_free()
	var run: RunState = GameState.run
	var quota: int = run.current_quota()
	GameState.finish_shift(int(results.total))
	results.cycle_ended = run.shifts_done_in_cycle == 0 or run.fired
	results.fired = run.fired
	results.quota = quota
	results.money = run.money
	results.score = run.score()
	_end_shift.rpc(results)
	_broadcast_run()


func _take_shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var index: int = 0
	while is_inside_tree():
		await get_tree().create_timer(SHOT_SECONDS).timeout
		get_viewport().get_texture().get_image().save_png(dir.path_join("shot_%03d.png" % index))
		index += 1


func _auto_shift() -> void:
	await get_tree().create_timer(1.0).timeout
	request_lift()
	while phase != Phase.SHIFT:
		await get_tree().process_frame
	await get_tree().create_timer(5.0).timeout
	var player: Player = local_player()
	player.teleport(mine_cage.player_spot(0))
	await get_tree().create_timer(0.5).timeout
	request_lift()


func _drop_everything(player: Player) -> void:
	for item: Object in player.inventory.all_items():
		var world_item: WorldItem = item as WorldItem
		if world_item != null:
			world_item.host_release(Transform3D(Basis.IDENTITY, player.global_position + Vector3.UP), Vector3.ZERO)


# --- shift flow (every peer) ----------------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _begin_ride(down: bool, seed_value: int, cycle: int) -> void:
	phase = Phase.DESCENDING if down else Phase.ASCENDING
	hud.close_panels()
	var cage: Foerderkorb = hub_cage if down else mine_cage
	cage.play_ride()
	hud.fade_out(FADE_SECONDS)
	_set_local_input(false)
	await get_tree().create_timer(FADE_SECONDS).timeout
	if down:
		_build_mine(seed_value, cycle)


func _build_mine(seed_value: int, cycle: int) -> void:
	_free_mine()
	var started: int = Time.get_ticks_msec()
	mine = Mine.new()
	mine.name = "Mine"
	mine_root.add_child(mine)
	mine.build(seed_value, MineParams.from_balance(_config, cycle), CHUNKS)
	var anchor: Marker3D = mine.station.find_child("LiftAnchor", true, false) as Marker3D
	mine_cage = CAGE_SCENE.instantiate() as Foerderkorb
	mine_cage.name = "MineCage"
	mine.add_child(mine_cage)
	mine_cage.global_transform = anchor.global_transform
	print("[game] mine built (seed %d, %d chunks) in %d ms" % [seed_value, mine.chunks.size(), Time.get_ticks_msec() - started])


func _free_mine() -> void:
	Bergmandl.stash.clear()
	if mine != null:
		mine.queue_free()
	mine = null
	mine_cage = null


@rpc("authority", "call_local", "reliable")
func _start_shift(seconds: float) -> void:
	phase = Phase.SHIFT
	whistle_blown = false
	shift_length = seconds
	shift_time_left = seconds
	mine_cage.stop_ride()
	hub_cage.motor.stop()
	_update_clocks()
	_set_local_input(true)
	hud.fade_in(FADE_SECONDS)
	hud.show_message(tr("MSG_SHIFT_START"), 4.0)
	print("[game] shift started (%.0f s)" % seconds)


@rpc("authority", "call_local", "reliable")
func _blow_whistle() -> void:
	whistle_blown = true
	var player: Player = local_player()
	var where: Vector3 = mine_cage.global_position + Vector3.UP * 3.0
	if player != null:
		# Heard everywhere in the mine, from the direction of the lift.
		where = player.global_position + (where - player.global_position).limit_length(12.0)
	Audio.play_at("grubenpfeife", where, &"SFX", 6.0, 60.0)
	hud.show_message(tr("MSG_WHISTLE") % roundi(_config.whistle_grace_seconds), 6.0)
	print("[game] whistle")


@rpc("authority", "call_local", "reliable")
func _end_shift(results: Dictionary) -> void:
	phase = Phase.OVER if results.fired else Phase.HUB
	_free_mine()
	hub_cage.stop_ride()
	_set_local_input(true)
	hud.fade_in(FADE_SECONDS)
	hud.show_results(results, multiplayer.get_unique_id() in (results.left_behind as Array))
	print("[game] shift ended, sold %d" % int(results.total))


func _set_local_input(enabled: bool) -> void:
	var player: Player = local_player()
	if player != null:
		player.input_enabled = enabled and not hud.modal_open()


## Time on the in-world clocks (cage boards and pocket watch), e.g. "11:45".
func clock_text() -> String:
	if phase != Phase.SHIFT or shift_length <= 0.0:
		return "%02d:00" % int(_config.shift_start_hour)
	var hours_per_second: float = (_config.shift_end_hour - _config.shift_start_hour) / shift_length
	var hour: float = _config.shift_start_hour + (shift_length - shift_time_left) * hours_per_second
	return "%02d:%02d" % [int(hour) % 24, int(fmod(hour, 1.0) * 60.0)]


func _update_clocks() -> void:
	var text: String = clock_text()
	hub_cage.set_clock(text)
	if mine_cage != null:
		mine_cage.set_clock(text)


# --- run state ------------------------------------------------------------------------------------

func _broadcast_run() -> void:
	var run: RunState = GameState.run
	if run == null:
		return
	var info: Dictionary = {
		"money": run.money,
		"quota": run.current_quota(),
		"cycle": run.cycle,
		"shifts_left": run.shifts_left_in_cycle(),
		"fired": run.fired,
	}
	for peer: int in _ready_peers:
		if peer == multiplayer.get_unique_id():
			_apply_run_info(info)
		else:
			_apply_run_info.rpc_id(peer, info)


@rpc("authority", "call_remote", "reliable")
func _apply_run_info(info: Dictionary) -> void:
	run_info = info
	hub.update_board(info)
	hud.update_run(info)


## Bought in the Gasthaus shop: money from the run, the item appears on the counter.
@rpc("any_peer", "call_local", "reliable")
func request_buy(id: StringName) -> void:
	if not multiplayer.is_server() or phase != Phase.HUB:
		return
	var data: ItemData = catalog.by_id(id)
	var sender: int = _sender()
	if data == null or data.price <= 0 or not GameState.run.spend(data.price):
		_show_message_key.rpc_id(sender, "MSG_TOO_POOR")
		return
	_spawn_item_at(id, 0, hub.counter_spot())
	play_sound_everywhere.rpc("sell", hub.counter_spot().origin)
	_broadcast_run()


# --- requests from players (host) -----------------------------------------------------------------

@rpc("any_peer", "call_local", "reliable")
func request_take(item_path: NodePath, peer: int) -> void:
	if not multiplayer.is_server():
		return
	var item: WorldItem = get_node_or_null(item_path) as WorldItem
	var player: Player = player_by_peer(peer)
	if item == null or player == null or not player.alive:
		return
	if item.state != WorldItem.State.FREE and item.state != WorldItem.State.CARTED:
		return
	var place: int = player.inventory.place_for(item.data.weight_class)
	if place == Inventory.NONE:
		return
	item.host_take(peer, place)
	play_sound_everywhere.rpc("pickup", item.global_position)


@rpc("any_peer", "call_local", "reliable")
func request_drop(item_path: NodePath, at: Transform3D, toss: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var item: WorldItem = get_node_or_null(item_path) as WorldItem
	if item == null or item.holder_peer != _sender():
		return
	item.host_release(at, toss)
	if item.data.weight_class == ItemData.WeightClass.HEAVY and not item is Schubkarre:
		play_sound_everywhere.rpc("drop_thud", at.origin)


@rpc("any_peer", "call_local", "reliable")
func request_load_cart(cart_path: NodePath, item_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var cart: Schubkarre = get_node_or_null(cart_path) as Schubkarre
	var item: WorldItem = get_node_or_null(item_path) as WorldItem
	if cart == null or item == null or item == cart or not item.is_loot() or item.state == WorldItem.State.CARTED:
		return
	if item.state == WorldItem.State.STOLEN:
		return
	if not cart.can_load(item):
		_show_message_key.rpc_id(_sender(), "PROMPT_CART_FULL")
		return
	item.host_cart(cart.free_slot(item))
	play_sound_everywhere.rpc("drop_thud" if item.data.weight_class == ItemData.WeightClass.HEAVY else "pickup", item.global_position)


@rpc("any_peer", "call_local", "reliable")
func request_consume(item_path: NodePath, peer: int) -> void:
	if not multiplayer.is_server():
		return
	var item: WorldItem = get_node_or_null(item_path) as WorldItem
	if item != null and item.holder_peer == peer:
		play_sound_everywhere.rpc("karbid_open", item.global_position)
		item.host_vanish()


@rpc("any_peer", "call_local", "reliable")
func request_hit(creature_path: NodePath, damage: int, from: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var creature: Creature = get_node_or_null(creature_path) as Creature
	if creature != null:
		creature.host_hit(damage, from)


## "Plärren": a loud shout. Scares Bergmandl nearby (DESIGN.md §6, DECISIONS "Plärren key").
@rpc("any_peer", "call_local", "reliable")
func request_shout(peer: int, where: Vector3) -> void:
	if not multiplayer.is_server():
		return
	_play_shout.rpc(peer)
	for creature: Creature in creatures():
		if creature.global_position.distance_to(where) <= _config.shout_radius:
			creature.host_shouted_at(where)


@rpc("authority", "call_local", "reliable")
func _play_shout(peer: int) -> void:
	var player: Player = player_by_peer(peer)
	if player != null:
		player.play_shout()


@rpc("any_peer", "call_local", "reliable")
func play_sound_everywhere(sound: String, where: Vector3) -> void:
	Audio.play_at(sound, where)


@rpc("authority", "call_local", "reliable")
func _show_message_key(key: String) -> void:
	show_message(tr(key))


func show_message(text: String, seconds: float = 2.5) -> void:
	hud.show_message(text, seconds)


## The sender of the RPC being handled (the host itself for local calls).
func _sender() -> int:
	var sender: int = multiplayer.get_remote_sender_id()
	return sender if sender != 0 else multiplayer.get_unique_id()


# --- creature voices (host) -----------------------------------------------------------------------

## Whether any creature may speak now (global gap between lines, DESIGN.md §6); claims the
## slot when it returns true.
func claim_voice_slot() -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now < _voice_quiet_until:
		return false
	_voice_quiet_until = now + _config.voice_global_gap
	return true


# --- lookups --------------------------------------------------------------------------------------

func player_by_peer(peer: int) -> Player:
	return players_root.get_node_or_null("P%d" % peer) as Player


func local_player() -> Player:
	return player_by_peer(multiplayer.get_unique_id())


func players() -> Array[Player]:
	var result: Array[Player] = []
	for child: Node in players_root.get_children():
		var player: Player = child as Player
		if player != null and not player.is_queued_for_deletion():
			result.append(player)
	return result


func creatures() -> Array[Creature]:
	var result: Array[Creature] = []
	for child: Node in creatures_root.get_children():
		var creature: Creature = child as Creature
		if creature != null and not creature.is_queued_for_deletion():
			result.append(creature)
	return result


func _items() -> Array[WorldItem]:
	var result: Array[WorldItem] = []
	for child: Node in items_root.get_children():
		var item: WorldItem = child as WorldItem
		if item != null and not item.is_queued_for_deletion():
			result.append(item)
	return result


func _distance_to_nearest_player(where: Vector3) -> float:
	var best: float = INF
	for player: Player in players():
		best = minf(best, player.global_position.distance_to(where))
	return best


## Whether `where` is inside the lift cage of the mine (loot there is safe from Bergmandl).
func in_mine_cage(where: Vector3) -> bool:
	return mine_cage != null and mine_cage.contains(where)


# --- presentation (local) -------------------------------------------------------------------------

func _update_environment() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var wanted: Environment = HUB_ENVIRONMENT if camera.global_position.y > HUB_FLOOR_ABOVE else MINE_ENVIRONMENT
	if world_env.environment != wanted:
		world_env.environment = wanted


## Drips, creaks and distant rumbles around the local player while down in the mine.
func _tick_ambience(delta: float) -> void:
	_ambience_left -= delta
	if _ambience_left > 0.0:
		return
	_ambience_left = randf_range(3.0, 10.0)
	var player: Player = local_player()
	if player == null or player.global_position.y > HUB_FLOOR_ABOVE:
		return
	var sound: String = AMBIENCE[randi() % AMBIENCE.size()]
	var offset: Vector3 = Vector3(randf_range(-1.0, 1.0), randf_range(0.5, 1.0), randf_range(-1.0, 1.0)).normalized() * randf_range(5.0, 18.0)
	var volume: float = -4.0 if sound == "rumble" else -10.0
	Audio.play_at(sound, player.global_position + offset, &"Ambience", volume, 40.0, randf_range(0.85, 1.1))
