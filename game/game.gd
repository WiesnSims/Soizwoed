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
## Loaded at runtime into iomes (their chunks' scripts refer back to Game).
const BIOME_PATHS: PackedStringArray = [
	"res://world/chunks/oberer_stollen/oberer_stollen.tres",
	"res://world/chunks/salzsee/salzsee.tres",
	"res://world/chunks/die_tiefe/die_tiefe.tres",
]
const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")
const CAGE_SCENE: PackedScene = preload("res://world/lift/foerderkorb.tscn")
const MINE_ENVIRONMENT: Environment = preload("res://world/mine_environment.tres")
const HUB_ENVIRONMENT: Environment = preload("res://hub/hub_environment.tres")
## Loaded at runtime, not preloaded: their scenes' scripts refer back to Game.
const CATALOG_PATH: String = "res://items/item_catalog.tres"
const CREATURE_PATHS: PackedStringArray = [
	"res://enemies/bergmandl/bergmandl.tres",
	"res://enemies/tatzelwurm/tatzelwurm.tres",
	"res://enemies/kasermandl/kasermandl.tres",
	"res://enemies/schichtmeister/schichtmeister.tres",
	"res://enemies/salzweibl/salzweibl.tres",
	"res://enemies/percht/percht.tres",
]
const AMBIENCE: PackedStringArray = ["drip", "drip", "drip", "creak", "creak", "rumble"]
## Dev/smoke flag: ride down right away, play a few seconds (`--auto-shift=<s>`, default 5),
## ride up again. With `--wait-peers=<n>` the host first waits for n clients.
const AUTO_SHIFT_ARG: String = "--auto-shift"
const WAIT_PEERS_ARG: String = "--wait-peers="
## With --auto-shift: ride into mine section n (unlocked or not) and spawn one of each of its
## creatures right away (multiplayer checks of new creatures).
const SECTION_ARG: String = "--section="
## How often the host sends the transforms of moving free items to the clients.
const ITEM_SYNC_SECONDS: float = 0.05
## Floats per item in an item transform batch: position (3) + rotation quaternion (4).
const ITEM_SYNC_STRIDE: int = 7
## Dev flag: save a screenshot every SHOT_SECONDS into this folder (needs a window).
const SHOTS_ARG: String = "--shots="
const SHOT_SECONDS: float = 1.5
## Dev flag: run a scripted situation from tools/dev/dev_scenario.gd.
const SCENARIO_ARG: String = "--scenario="
const SCENARIO_SCRIPT: String = "res://tools/dev/dev_scenario.gd"

static var instance: Game
## Set for automated windowed runs (--shots): no focus, no mouse capture, no sound, so a test
## window never gets in the way of the person at the computer.
static var dev_quiet: bool = false

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
## The mine sections, in the order they unlock (DESIGN.md §4), from BIOME_PATHS.
var biomes: Array[ChunkSet] = []
## The mine section picked in the Gasthaus (index into biomes; host decides, sent to all).
var biome_index: int = 0

var _config: BalanceConfig
var _next_item: int = 0
var _next_creature: int = 0
var _ready_peers: Dictionary = {}
var _enemy_budget: float = 0.0
var _enemy_budget_left: float = 0.0
var _noise_left: float = 0.0
## The Schichtmeister was sent this shift (once per shift).
var _meister_came: bool = false
## Host: smoke clouds creatures avoid, [centre: Vector3, radius: float, until: float (s)].
var _smokes: Array[Array] = []
var _trickle_left: float = 0.0
var _ambience_left: float = 5.0
var _voice_quiet_until: float = 0.0
var _item_sync_left: float = 0.0
## Seconds since the last living player died in this shift (host).
var _all_dead_time: float = 0.0
## Dev (--section): one of each creature of the section at the start of the shift.
var _force_creatures: bool = false
## Host: food poisoning (Speckbrot), peer -> [seconds left, damage per second, fraction carried over].
var _poisoned: Dictionary = {}
## Host: seconds until each special loot item (Kuckucksuhr, Mann im Salz) acts next, and how
## long the cursed piece has been carried, by item name.
var _special_left: Dictionary = {}
var _cursed_for: Dictionary = {}
## Host: bodies of miners who died this shift, item name -> [peer id, time of death (s)].
var _corpses: Dictionary = {}

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
	VoiceChat.snippets.clear()  # nobody's voice outlives the session
	catalog = load(CATALOG_PATH) as ItemCatalog
	for path: String in BIOME_PATHS:
		biomes.append(load(path) as ChunkSet)
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
			_go_quiet()
			_take_shots(arg.trim_prefix(SHOTS_ARG))
		elif arg.begins_with(SCENARIO_ARG) and not ResourceLoader.exists(SCENARIO_SCRIPT):
			print("[game] dev scenarios are not part of this build")
		elif arg.begins_with(SCENARIO_ARG):
			var scenario: Node = (load(SCENARIO_SCRIPT) as GDScript).new()
			add_child(scenario)
			scenario.call(&"run", self, arg.trim_prefix(SCENARIO_ARG))


func _process(delta: float) -> void:
	_update_environment()
	if multiplayer.is_server() and NetworkManager.in_session():
		_host_sync_items(delta)
		_host_check_carry_together()
	if phase == Phase.SHIFT:
		shift_time_left -= delta
		_update_clocks()
		_tick_ambience(delta)
		if multiplayer.is_server():
			_host_tick_shift(delta)
			_host_tick_noise(delta)
			_host_tick_specials(delta)
			_host_tick_poison(delta)


# --- session --------------------------------------------------------------------------------------

func _on_session_started() -> void:
	menu_layer.hide()
	phase = Phase.HUB
	if NetworkManager.is_host():
		if GameState.run == null:
			GameState.start_run(NetworkManager.player_count())
			biome_index = 0
			# Solo extra (DESIGN.md §8). A host waiting for friends does not get it.
			if NetworkManager.mode == NetworkManager.Mode.SOLO and _config.solo_free_schubkarre:
				_spawn_item_at(&"schubkarre", 0, hub.free_cart_spot())
		_ready_peers[1] = true
		_spawn_player_for(1)
		_broadcast_run()
		print("[game] hub ready")
		if _has_arg(AUTO_SHIFT_ARG):
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
	# The spawner only knows where each item was first spawned: send where it is now.
	for item: WorldItem in _items():
		var place: int = 0
		var holder: Player = player_by_peer(item.holder_peer)
		if holder != null:
			place = Inventory.HANDS if holder.inventory.hands == item else holder.inventory.slots.find(item)
		item.host_send_state_to(peer, place)
	_update_player_count()
	_broadcast_run()
	print("[game] peer %d is in the Gasthaus" % peer)


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
	_update_player_count()
	_broadcast_run()


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
	# The lowest free number, so "Kumpl 2" stays "Kumpl 2" when someone else leaves.
	var number: int = 1
	var taken: Array[int] = []
	for player: Player in players():
		taken.append(player.player_number)
	while number in taken:
		number += 1
	_player_spawner.spawn([peer, hub.player_spot(number - 1), number, NetworkManager.peer_name(peer)])


func _spawn_player(spawn_data: Array) -> Node:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.peer_id = int(spawn_data[0])
	player.name = "P%d" % player.peer_id
	player.transform = spawn_data[1]
	player.player_number = int(spawn_data[2])
	player.steam_name = str(spawn_data[3])
	player.net_position = player.transform.origin
	player.net_angles = Vector2(player.rotation.y, 0.0)
	return player


func _spawn_item_at(id: StringName, value: int, xform: Transform3D, item_name: String = "") -> WorldItem:
	_next_item += 1
	return _item_spawner.spawn([item_name if item_name != "" else "I%d" % _next_item, id, value, xform]) as WorldItem


func _spawn_item(spawn_data: Array) -> Node:
	var data: ItemData = catalog.by_id(spawn_data[1])
	var item: WorldItem = data.scene.instantiate() as WorldItem
	item.name = spawn_data[0]
	item.data = data
	item.value = spawn_data[2]
	item.transform = spawn_data[3]
	return item


func creature_data(id: StringName) -> EnemyData:
	for candidate: EnemyData in creature_types:
		if candidate.id == id:
			return candidate
	return null


func _spawn_creature(spawn_data: Array) -> Node:
	var data: EnemyData = creature_data(spawn_data[1])
	var creature: Creature = data.scene.instantiate() as Creature
	creature.name = spawn_data[0]
	creature.data = data
	creature.transform = spawn_data[2]
	creature.net_position = creature.transform.origin
	creature.net_yaw = creature.rotation.y
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
			if data.min_depth <= depth and data.spawns_in(mine.chunk_set.id):
				options.append(data)
				weights.append(data.spawn_weight)
		var picked: ItemData = options[rng.rand_weighted(weights)]
		var value: int = roundi(rng.randi_range(picked.value_min, picked.value_max) * (1.0 + depth * _config.loot_value_per_depth) * _biome_rule().loot_value_mult)
		var xform: Transform3D = (spot[0] as Marker3D).global_transform
		if i >= spots.size():
			xform.origin += Vector3(rng.randf_range(-0.6, 0.6), 0.2, rng.randf_range(-0.6, 0.6))
		_spawn_item_at(picked.id, value, xform)
	# Relics lie where their chunk puts them (the Mann im Salz in Die Tiefe).
	for spot: Array in mine.markers_with_depth(&"relic_spawn"):
		var marker: Marker3D = spot[0]
		var relic: ItemData = catalog.by_id(StringName(str(marker.get_meta(&"item", "mann_im_salz"))))
		var relic_value: int = roundi(rng.randi_range(relic.value_min, relic.value_max) * (1.0 + int(spot[1]) * _config.loot_value_per_depth) * _biome_rule().loot_value_mult)
		_spawn_item_at(relic.id, relic_value, marker.global_transform)
		print("[game] relic %s worth %d" % [relic.id, relic_value])
	print("[game] spawned %d loot items" % count)


func _spawn_creature_group(rule: CreatureSpawnRule) -> int:
	var spots: Array[Vector3] = []
	for spot: Array in mine.markers_with_depth(&"enemy_spawn"):
		var where: Vector3 = (spot[0] as Marker3D).global_position
		if int(spot[1]) >= _config.enemy_min_depth and _distance_to_nearest_player(where) > 15.0:
			spots.append(where)
	if spots.is_empty():
		return 0
	var at: Vector3 = spots.pick_random()
	var size: int = rule.group_size(randi_range(rule.group_min, rule.group_max), alive_count(rule.id), _enemy_budget_left)
	for i: int in size:
		var offset: Vector3 = Vector3(randf_range(-1.0, 1.0), 0.3, randf_range(-1.0, 1.0))
		spawn_creature(rule.id, Transform3D(Basis(Vector3.UP, randf() * TAU), at + offset))
		_enemy_budget_left -= rule.budget_cost
	return size


## Host: one creature of type `id` (outside the budget, e.g. the Schichtmeister).
func spawn_creature(id: StringName, xform: Transform3D) -> Creature:
	_next_creature += 1
	return _creature_spawner.spawn(["C%d" % _next_creature, id, xform]) as Creature


func alive_count(id: StringName) -> int:
	var count: int = 0
	for creature: Creature in creatures():
		count += 1 if creature.data.id == id else 0
	return count


## Spends the enemy budget until `share_spent` of it is used, picking creature types of the
## biome by weight (DESIGN.md §6, §8; rules in balance.tres).
func _spawn_creatures_up_to(share_spent: float) -> void:
	var spawned: Dictionary = {}
	for _attempt: int in 32:
		if _enemy_budget - _enemy_budget_left >= _enemy_budget * share_spent:
			break
		var options: Array[CreatureSpawnRule] = []
		var weights: PackedFloat32Array = []
		for id: StringName in mine.chunk_set.creatures:
			var rule: CreatureSpawnRule = _config.spawn_rule(id)
			if rule != null and creature_data(id) != null and rule.allowed(GameState.run.cycle, alive_count(id), _enemy_budget_left):
				options.append(rule)
				weights.append(rule.weight)
		if options.is_empty():
			break
		var picked: CreatureSpawnRule = options[_rng_weighted(weights)]
		var group: int = _spawn_creature_group(picked)
		if group == 0:
			break
		spawned[picked.id] = int(spawned.get(picked.id, 0)) + group
	for id: StringName in spawned:
		print("[game] spawned %d %s" % [spawned[id], id])


func _rng_weighted(weights: PackedFloat32Array) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	return rng.rand_weighted(weights)


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
	_update_player_count()
	_broadcast_run()
	var seed_value: int = randi()
	_all_dead_time = 0.0
	_begin_ride.rpc(true, seed_value, run.cycle, biome_index)
	await get_tree().create_timer(RIDE_SECONDS).timeout
	if phase != Phase.DESCENDING:
		return
	var index: int = 0
	for item: WorldItem in _items():
		if item.state == WorldItem.State.FREE and hub_cage.contains(item.global_position):
			item.host_move(hub_cage.carry_to(mine_cage, item.global_transform))
	for player: Player in players():
		player.revive.rpc()
		player.teleport.rpc(mine_cage.player_spot(index))
		index += 1
	_spawn_loot(seed_value)
	if mine.rails != null:
		var cart: RailCart = _spawn_item_at(&"hunt", 0, mine.rails.transform_at(0.0)) as RailCart
		cart.host_place(0.0)
	_enemy_budget = _config.enemy_budget(run.cycle, run.player_count) * _biome_rule().enemy_budget_mult
	_enemy_budget_left = _enemy_budget
	_smokes.clear()
	_special_left.clear()
	_cursed_for.clear()
	_poisoned.clear()
	_corpses.clear()
	_meister_came = false
	_spawn_creatures_up_to(_config.enemy_start_share)
	if _force_creatures:
		for id: StringName in mine.chunk_set.creatures:
			if alive_count(id) == 0:
				var spot: Array = mine.markers_with_depth(&"enemy_spawn").back()
				spawn_creature(id, Transform3D(Basis.IDENTITY, (spot[0] as Marker3D).global_position + Vector3.UP * 0.3))
				print("[game] dev: %s spawned" % id)
	_trickle_left = _config.enemy_trickle_seconds
	_start_shift.rpc(_config.shift_seconds(run.player_count))


func _host_tick_shift(delta: float) -> void:
	if not whistle_blown and shift_time_left <= 0.0:
		_blow_whistle.rpc()
	elif whistle_blown and shift_time_left <= -_config.whistle_grace_seconds:
		_ascend()
		return
	if whistle_blown and shift_time_left <= -_config.schichtmeister_delay and alive_count(&"schichtmeister") == 0 and not _meister_came:
		_send_schichtmeister()
	if not whistle_blown and _enemy_budget_left > 0.0:
		_trickle_left -= delta
		if _trickle_left <= 0.0:
			_trickle_left = _config.enemy_trickle_seconds
			_spawn_creatures_up_to(1.0)
	var anyone_alive: bool = false
	for player: Player in players():
		anyone_alive = anyone_alive or player.alive
	# Everybody dead: a few seconds to take it in, then the lift goes up without them.
	_all_dead_time = 0.0 if anyone_alive else _all_dead_time + delta
	if _all_dead_time >= _config.all_dead_delay:
		_ascend()


## Whoever is still down after the whistle gets a visit (DESIGN.md §6): he comes out of the dark
## behind the straggler nearest the lift, from the side away from the cage.
func _send_schichtmeister() -> void:
	var straggler: Player = null
	for player: Player in players():
		if player.alive and player.global_position.y < HUB_FLOOR_ABOVE and not mine_cage.contains(player.global_position):
			if straggler == null or player.global_position.distance_to(mine_cage.global_position) < straggler.global_position.distance_to(mine_cage.global_position):
				straggler = player
	if straggler == null:
		return
	_meister_came = true
	var best: Vector3 = straggler.global_position
	var best_score: float = -INF
	for id: int in mine.nav.get_point_ids():
		var point: Vector3 = mine.nav.get_point_position(id)
		var from_straggler: float = point.distance_to(straggler.global_position)
		if from_straggler < 15.0 or from_straggler > 40.0:
			continue
		var score: float = point.distance_to(mine_cage.global_position) - absf(from_straggler - 25.0)
		if score > best_score:
			best_score = score
			best = point
	spawn_creature(&"schichtmeister", Transform3D(Basis.IDENTITY, best + Vector3.UP * 0.3))
	print("[game] Schichtmeister comes for P%d" % straggler.peer_id)


func _ascend() -> void:
	var riders: Array[Player] = []
	for player: Player in players():
		if player.alive and mine_cage.contains(player.global_position):
			riders.append(player)
	_begin_ride.rpc(false, 0, 0, 0)
	await get_tree().create_timer(RIDE_SECONDS).timeout
	var results: Dictionary = {"sold": [], "total": 0, "left_behind": [], "dead": []}
	var rider_peers: Array[int] = []
	for player: Player in riders:
		rider_peers.append(player.peer_id)
	# What rides up is decided by who holds it, not by where it is: a client's position
	# update may still be on its way.
	var going_up: Array[WorldItem] = []
	for item: WorldItem in _items():
		if item.global_position.y > HUB_FLOOR_ABOVE and item.state == WorldItem.State.FREE:
			continue
		var held_by_rider: bool = item.holder_peer in rider_peers or item.helper_peer in rider_peers
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
			if not player.alive:
				(results.dead as Array).append(player.peer_id)
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


func _go_quiet() -> void:
	dev_quiet = true
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	# Parked in the corner of the screen, small: still renders, never in the way.
	var screen: Rect2i = DisplayServer.screen_get_usable_rect()
	DisplayServer.window_set_size(Vector2i(640, 360))
	DisplayServer.window_set_position(screen.end - Vector2i(660, 400))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _take_shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var index: int = 0
	while is_inside_tree():
		await get_tree().create_timer(SHOT_SECONDS).timeout
		get_viewport().get_texture().get_image().save_png(dir.path_join("shot_%03d.png" % index))
		index += 1


func _auto_shift() -> void:
	var wait_peers: int = _arg_value(WAIT_PEERS_ARG).to_int()
	var seconds: float = 5.0
	if _arg_value(AUTO_SHIFT_ARG + "=") != "":
		seconds = _arg_value(AUTO_SHIFT_ARG + "=").to_float()
	while _ready_peers.size() < wait_peers + 1:
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	if _arg_value(SECTION_ARG) != "":
		biome_index = clampi(_arg_value(SECTION_ARG).to_int(), 0, biomes.size() - 1)
		_force_creatures = true
	request_lift()
	while phase != Phase.SHIFT:
		await get_tree().process_frame
	await get_tree().create_timer(seconds).timeout
	var player: Player = local_player()
	player.teleport(mine_cage.player_spot(0))
	await get_tree().create_timer(0.5).timeout
	request_lift()


## Everything the player carries falls to the floor. Something carried together stays with
## the other carrier.
func _drop_everything(player: Player) -> void:
	for item: Object in player.inventory.all_items():
		var world_item: WorldItem = item as WorldItem
		if world_item == null:
			continue
		if world_item.helper_peer == player.peer_id:
			world_item.host_set_helper(0)
		elif world_item.helper_peer != 0:
			world_item.host_take(world_item.helper_peer, Inventory.HANDS)
		else:
			world_item.host_release(Transform3D(Basis.IDENTITY, player.global_position + Vector3.UP), Vector3.ZERO)


func _has_arg(prefix: String) -> bool:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return true
	return false


## The value of a `--name=value` command line argument ("" when not given).
func _arg_value(prefix: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return ""


# --- shift flow (every peer) ----------------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _begin_ride(down: bool, seed_value: int, cycle: int, biome: int) -> void:
	phase = Phase.DESCENDING if down else Phase.ASCENDING
	if multiplayer.is_server():
		NetworkManager.set_joinable(false)
	hud.close_panels()
	var cage: Foerderkorb = hub_cage if down else mine_cage
	cage.play_ride()
	hud.fade_out(FADE_SECONDS)
	_set_local_input(false)
	await get_tree().create_timer(FADE_SECONDS).timeout
	if down:
		_build_mine(seed_value, cycle, biome)


func _build_mine(seed_value: int, cycle: int, biome: int) -> void:
	_free_mine()
	var started: int = Time.get_ticks_msec()
	mine = Mine.new()
	mine.name = "Mine"
	mine_root.add_child(mine)
	biome_index = clampi(biome, 0, biomes.size() - 1)
	mine.build(seed_value, MineParams.from_balance(_config, cycle), biomes[biome_index])
	mine.add_hazards(cycle, _biome_rule())
	Audio.set_echo(mine.chunk_set.echo)
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
	if local_player() != null:
		local_player().recharge_battery()
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
	if multiplayer.is_server():
		NetworkManager.set_joinable(phase == Phase.HUB)
	_free_mine()
	Audio.set_echo(0.0)
	hub_cage.stop_ride()
	_set_local_input(true)
	hud.fade_in(FADE_SECONDS)
	var me: int = multiplayer.get_unique_id()
	hud.show_results(results, me in (results.left_behind as Array), me in (results.dead as Array))
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

## Scaling follows the players in the game (DESIGN.md §8). It is fixed for a shift when the
## lift goes down; in the Gasthaus it follows joins and leaves.
func _update_player_count() -> void:
	if GameState.run != null and (phase == Phase.HUB or phase == Phase.MENU):
		GameState.run.player_count = maxi(1, players().size())


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
		"players": run.player_count,
		"section": biome_index,
	}
	for peer: int in _ready_peers:
		if peer == multiplayer.get_unique_id():
			_apply_run_info(info)
		else:
			_apply_run_info.rpc_id(peer, info)


@rpc("authority", "call_remote", "reliable")
func _apply_run_info(info: Dictionary) -> void:
	run_info = info
	biome_index = clampi(int(info.get("section", biome_index)), 0, biomes.size() - 1)
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
	if item.state != WorldItem.State.FREE and item.state != WorldItem.State.CARTED or item is RailCart:
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
	var sender: int = _sender()
	if item == null:
		return
	if item.helper_peer == sender:
		item.host_set_helper(0)  # lets go of their end
		return
	if item.holder_peer != sender:
		return
	if item.helper_peer != 0:
		item.host_take(item.helper_peer, Inventory.HANDS)  # the other one carries on alone
		return
	item.host_release(at, toss)
	if item.data.weight_class == ItemData.WeightClass.HEAVY and not item is Schubkarre:
		play_sound_everywhere.rpc("drop_thud", at.origin)
		host_noise(at.origin, _config.noise_heavy_drop)


## Takes the other end of a heavy item another player carries (DESIGN.md §3).
@rpc("any_peer", "call_local", "reliable")
func request_help_carry(item_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var item: WorldItem = get_node_or_null(item_path) as WorldItem
	var player: Player = player_by_peer(_sender())
	if item != null and player != null:
		host_help_carry(item, player)


func host_help_carry(item: WorldItem, player: Player) -> void:
	if not item.can_help_carry(player):
		return
	if player.global_position.distance_to(item.global_position) > _config.interact_distance + 1.5:
		return
	item.host_set_helper(player.peer_id)
	play_sound_everywhere.rpc("pickup", item.global_position)


## Carrying together only works close together: the helper loses their grip further apart.
func _host_check_carry_together() -> void:
	for player: Player in players():
		var item: WorldItem = player.inventory.hands as WorldItem
		if item == null or item.helper_peer == 0 or item.holder_peer != player.peer_id:
			continue
		var helper: Player = player_by_peer(item.helper_peer)
		if helper == null or helper.global_position.distance_to(player.global_position) > _config.carry_together_max_distance:
			if helper != null:
				_show_message_key.rpc_id(helper.peer_id, "MSG_LOST_GRIP")
			item.host_set_helper(0)


@rpc("any_peer", "call_local", "reliable")
func request_load_cart(cart_path: NodePath, item_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var cart: CargoItem = get_node_or_null(cart_path) as CargoItem
	var item: WorldItem = get_node_or_null(item_path) as WorldItem
	if cart == null or item == null or item == cart or not item.is_loot() or item.state == WorldItem.State.CARTED:
		return
	if item.state == WorldItem.State.STOLEN:
		return
	if not cart.can_load(item):
		_show_message_key.rpc_id(_sender(), "PROMPT_HUNT_FULL" if cart is RailCart else "PROMPT_CART_FULL")
		return
	item.host_cart(cart.free_slot(item))
	play_sound_everywhere.rpc("drop_thud" if item.data.weight_class == ItemData.WeightClass.HEAVY else "pickup", item.global_position)


@rpc("any_peer", "call_local", "reliable")
func request_consume(item_path: NodePath, peer: int) -> void:
	if not multiplayer.is_server():
		return
	var item: WorldItem = get_node_or_null(item_path) as WorldItem
	var player: Player = player_by_peer(peer)
	if item == null or player == null or item.holder_peer != peer:
		return
	match item.data.use:
		ItemData.Use.DRINK:
			host_heal_player(player, _config.obstler_heal)
			play_sound_everywhere.rpc("drink", item.global_position)
		ItemData.Use.EAT:
			host_heal_player(player, _config.leberkaese_heal)  # the chewing was heard already
		ItemData.Use.EAT_OLD:
			host_heal_player(player, _config.speckbrot_heal)
			if randf() < _config.speckbrot_poison_chance:
				_poisoned[player.peer_id] = [_config.speckbrot_poison_seconds, _config.speckbrot_poison_damage / _config.speckbrot_poison_seconds, 0.0]
				if player.peer_id == multiplayer.get_unique_id():
					_poison_felt()
				else:
					_poison_felt.rpc_id(player.peer_id)
				print("[game] P%d got food poisoning" % player.peer_id)
		_:
			play_sound_everywhere.rpc("karbid_open", item.global_position)
	item.host_vanish()


## The Alte Jausenbox opened (click with it in the pocket): sometimes a Speckbrot is still inside.
@rpc("any_peer", "call_local", "reliable")
func request_open(item_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var item: WorldItem = get_node_or_null(item_path) as WorldItem
	var player: Player = player_by_peer(_sender())
	if item == null or player == null or item.holder_peer != player.peer_id or item.data.use != ItemData.Use.OPEN:
		return
	play_sound_everywhere.rpc("karbid_open", item.global_position, -4.0, 12.0)
	if item.opened:
		message_to(player.peer_id, "MSG_BOX_EMPTY")
		return
	item.host_set_opened()
	if randf() >= _config.speckbrot_chance:
		message_to(player.peer_id, "MSG_BOX_NOTHING")
		return
	message_to(player.peer_id, "MSG_BOX_SPECKBROT")
	var at: Vector3 = player.global_position + Vector3.UP * 1.2 - player.global_basis.z * 0.5
	var bread: WorldItem = _spawn_item_at(&"speckbrot", 0, Transform3D(Basis.IDENTITY, at))
	# Into a free pocket once every peer has it; otherwise it stays on the floor.
	await get_tree().create_timer(0.3).timeout
	var place: int = player.inventory.place_for(ItemData.WeightClass.LIGHT) if is_instance_valid(player) else Inventory.NONE
	if is_instance_valid(bread) and place != Inventory.NONE and bread.state == WorldItem.State.FREE:
		bread.host_take(player.peer_id, place)


## The Wunderheilerin-Salbe on a dead miner's body: back on their feet, if it is not too late
## (DESIGN.md §3). The body goes, the miner stands where it lay.
@rpc("any_peer", "call_local", "reliable")
func request_revive(salve_path: NodePath, corpse_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var salve: WorldItem = get_node_or_null(salve_path) as WorldItem
	var corpse: WorldItem = get_node_or_null(corpse_path) as WorldItem
	var healer: Player = player_by_peer(_sender())
	if salve == null or corpse == null or healer == null or not healer.alive or salve.holder_peer != healer.peer_id or salve.data.use != ItemData.Use.REVIVE:
		return
	if not _corpses.has(String(corpse.name)) or healer.global_position.distance_to(corpse.global_position) > _config.interact_distance + 1.5:
		return
	var record: Array = _corpses[String(corpse.name)]
	var dead: Player = player_by_peer(int(record[0]))
	if dead == null or dead.alive:
		return
	if Time.get_ticks_msec() / 1000.0 - float(record[1]) > _config.revive_window_seconds:
		message_to(healer.peer_id, "MSG_REVIVE_TOO_LATE")
		return
	var stand: Transform3D = Transform3D(Basis(Vector3.UP, corpse.global_rotation.y), corpse.global_position + Vector3.UP * 0.2)
	_corpses.erase(String(corpse.name))
	corpse.host_vanish()
	salve.host_vanish()
	dead.revive.rpc()
	dead.teleport.rpc(stand)
	dead.set_health.rpc(_config.revive_health)
	play_sound_everywhere.rpc("drink", stand.origin)
	_player_message.rpc("MSG_REVIVED", dead.player_number, dead.peer_id)
	print("[game] P%d revived by P%d" % [dead.peer_id, healer.peer_id])


## The Gamsbart-Hut on or off the head (it stays in its pocket slot).
@rpc("any_peer", "call_local", "reliable")
func request_wear(item_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var item: WorldItem = get_node_or_null(item_path) as WorldItem
	if item != null and item.holder_peer == _sender() and item.state == WorldItem.State.STORED and item.data.use == ItemData.Use.WEAR:
		item.host_set_worn(not item.worn)


@rpc("authority", "call_remote", "reliable")
func _poison_felt() -> void:
	show_message(tr("MSG_POISONED"), 4.0)
	var player: Player = local_player()
	if player != null:
		player.feel_sick(_config.speckbrot_poison_seconds)


## Food poisoning costs health bit by bit, but never the last point (host).
func _host_tick_poison(delta: float) -> void:
	for peer: int in _poisoned.keys():
		var player: Player = player_by_peer(peer)
		var state: Array = _poisoned[peer]
		state[0] = float(state[0]) - delta
		state[2] = float(state[2]) + float(state[1]) * delta
		var due: int = floori(float(state[2]))
		state[2] = float(state[2]) - due
		if player != null and player.alive and due > 0 and player.health > 1:
			host_damage_player(player, mini(due, player.health - 1))
		if player == null or not player.alive or float(state[0]) <= 0.0:
			_poisoned.erase(peer)


## Loot that does something by itself (host): the Kuckucksuhr cuckoos now and then, loud
## enough to draw what listens; the Stück vom Mann im Salz calls the creatures while someone
## carries it, from further away the longer they do (DESIGN.md §5).
func _host_tick_specials(delta: float) -> void:
	for item: WorldItem in _items():
		if item.data.special == ItemData.Special.NONE or item.global_position.y > HUB_FLOOR_ABOVE:
			continue
		var key: String = item.name
		if not _special_left.has(key):
			_special_left[key] = randf_range(_config.cuckoo_interval_min, _config.cuckoo_interval_max) * 0.5
		_special_left[key] = float(_special_left[key]) - delta
		match item.data.special:
			ItemData.Special.CUCKOO:
				if float(_special_left[key]) <= 0.0:
					_special_left[key] = randf_range(_config.cuckoo_interval_min, _config.cuckoo_interval_max)
					_cuckoo.rpc(item.get_path())
					host_noise(item.global_position, _config.noise_cuckoo)
			ItemData.Special.CURSED:
				var carried: bool = item.state == WorldItem.State.HELD or item.state == WorldItem.State.CARTED
				_cursed_for[key] = float(_cursed_for.get(key, 0.0)) + delta if carried else 0.0
				if carried and float(_special_left[key]) <= 0.0:
					_special_left[key] = _config.curse_pulse_seconds
					host_noise(item.global_position, curse_reach(float(_cursed_for[key])))
					_curse_whisper.rpc(item.get_path())


## How far creatures sense the Mann im Salz after it was carried `seconds`.
func curse_reach(seconds: float) -> float:
	return minf(_config.curse_reach_max, _config.curse_reach_start + seconds * _config.curse_reach_per_second)


@rpc("authority", "call_local", "reliable")
func _cuckoo(item_path: NodePath) -> void:
	var item: Node3D = get_node_or_null(item_path) as Node3D
	if item != null:
		Audio.play_at("cuckoo", item.global_position + Vector3.UP * 0.3, &"SFX", 2.0, 45.0)
		print("[game] %s cuckoos" % item.name)


## A whisper only whoever carries the cursed piece (or stands right by) hears.
@rpc("authority", "call_local", "reliable")
func _curse_whisper(item_path: NodePath) -> void:
	var item: Node3D = get_node_or_null(item_path) as Node3D
	if item != null and randf() < 0.6:
		Audio.play_at("curse_whisper", item.global_position, &"Creatures", -4.0, 6.0, randf_range(0.9, 1.05))


func host_heal_player(player: Player, amount: int) -> void:
	if player.alive and amount > 0:
		player.set_health.rpc(mini(_config.player_max_health, player.health + amount))


## Lit and thrown: a Böller or a Rauchbombe (Throwable) leaves the hand.
@rpc("any_peer", "call_local", "reliable")
func request_throw(item_path: NodePath, at: Transform3D, toss: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var item: Throwable = get_node_or_null(item_path) as Throwable
	if item != null and not item.lit and item.holder_peer == _sender():
		item.host_throw(at, toss.limit_length(_config.throw_tool_speed + _config.sprint_speed))


## The Alphorn (DESIGN.md §7): stuns every creature in a cone in front, and the whole mine
## hears it.
@rpc("any_peer", "call_local", "reliable")
func request_alphorn(from: Vector3, forward: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var player: Player = player_by_peer(_sender())
	if player == null or not player.alive:
		return
	play_sound_everywhere.rpc("alphorn", from, 6.0, 120.0)
	host_noise(from, _config.noise_alphorn)
	var stunned: int = 0
	for creature: Creature in creatures():
		if in_cone(from, forward, creature.global_position + Vector3.UP * 0.8, _config.alphorn_range, _config.alphorn_cone_degrees) \
				and clear_line(from, creature.global_position + Vector3.UP * 0.8):
			creature.host_stun(_config.alphorn_stun_seconds)
			creature.host_shouted_at(from)
			stunned += 1
	print("[game] Alphorn by P%d stunned %d" % [player.peer_id, stunned])


## Whether `point` lies within `reach` m of `from` and within a cone of `degrees` around `forward`.
static func in_cone(from: Vector3, forward: Vector3, point: Vector3, reach: float, degrees: float) -> bool:
	var to: Vector3 = point - from
	if to.length() > reach:
		return false
	if to.length() < 0.5:
		return true
	return to.normalized().dot(forward.normalized()) >= cos(deg_to_rad(degrees / 2.0))


## No rock between the two points.
func clear_line(from: Vector3, to: Vector3) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## A Böller going off (host): heard far through the mine, scares Bergmandl, hurts whatever is
## right next to it, and sets off firedamp.
func host_bang(where: Vector3) -> void:
	_flash.rpc(where, "boeller_bang", Color(1.0, 0.8, 0.5), 6.0)
	host_noise(where, _config.noise_boeller)
	host_blast(where, _config.boeller_radius, _config.boeller_damage)
	for creature: Creature in creatures():
		if creature.global_position.distance_to(where) <= _config.boeller_scare_radius:
			creature.host_shouted_at(where)


## Damage around a blast: full at the centre, nothing at `radius` (host). Rock shields.
func host_blast(where: Vector3, radius: float, damage: int) -> void:
	for player: Player in players():
		var chest: Vector3 = player.global_position + Vector3.UP
		if clear_line(where + Vector3.UP * 0.2, chest):
			host_damage_player(player, _config.explosion_damage(chest.distance_to(where), radius, damage))
	for creature: Creature in creatures():
		var body: Vector3 = creature.global_position + Vector3.UP * 0.5
		var hurt: int = _config.explosion_damage(body.distance_to(where), radius, damage)
		if hurt > 0:
			creature.host_hit(hurt, where)
	host_flame(where, radius)


## An open flame or a blast at `where` reaching `radius` m (host): firedamp there goes up.
func host_flame(where: Vector3, radius: float) -> void:
	if mine != null and mine.hazards != null:
		mine.hazards.host_flame(where, radius)


## A rotten ladder gave way under someone with a heavy load (they ask; their movement is theirs).
@rpc("any_peer", "call_local", "reliable")
func request_break_ladder(ladder_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var ladder: Ladder = get_node_or_null(ladder_path) as Ladder
	var player: Player = player_by_peer(_sender())
	if ladder != null and ladder.rotten and not ladder.broken and player != null and player.global_position.distance_to(ladder.global_position) < ladder.height + 2.0:
		_break_ladder.rpc(ladder_path)
		print("[hazards] %s gave way under P%d" % [ladder.name, player.peer_id])


@rpc("authority", "call_local", "reliable")
func _break_ladder(ladder_path: NodePath) -> void:
	var ladder: Ladder = get_node_or_null(ladder_path) as Ladder
	if ladder != null:
		ladder.break_apart()


## The "Bierzelt" bomb bursts: a stinking cloud creatures keep out of (host).
func host_smoke(where: Vector3) -> void:
	add_smoke(where, _config.rauchbombe_radius, _config.rauchbombe_seconds)
	_show_smoke.rpc(where)
	print("[game] Bierzelt cloud at %s" % where.snapped(Vector3.ONE * 0.1))


@rpc("authority", "call_local", "reliable")
func _show_smoke(where: Vector3) -> void:
	Audio.play_at("smoke_puff", where, &"SFX", 0.0, 30.0)
	var cloud: SmokeCloud = SmokeCloud.new()
	cloud.radius = _config.rauchbombe_radius
	cloud.seconds = _config.rauchbombe_seconds
	(mine if mine != null else mine_root).add_child(cloud)
	cloud.global_position = where


## A bang with a flash of light, on every peer.
@rpc("authority", "call_local", "reliable")
func _flash(where: Vector3, sound: String, color: Color, energy: float) -> void:
	Audio.play_at(sound, where, &"SFX", 4.0, 60.0)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 9.0
	mine_root.add_child(light)
	light.global_position = where + Vector3.UP * 0.4
	var tween: Tween = light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.35)
	tween.tween_callback(light.queue_free)


## A pick hit on a salt wall or rubble (only the Spitzhacke breaks rock).
@rpc("any_peer", "call_local", "reliable")
func request_break(rock_path: NodePath, damage: int) -> void:
	if not multiplayer.is_server():
		return
	var rock: Breakable = get_node_or_null(rock_path) as Breakable
	var player: Player = player_by_peer(_sender())
	if rock == null or player == null or not player.alive or rock.health <= 0:
		return
	var tool: WorldItem = player.inventory.slots[player.inventory.selected] as WorldItem
	if tool == null or not tool.data.breaks_rock or player.global_position.distance_to(rock.global_position) > rock.size.x:
		return
	rock.host_hit(clampi(damage, 0, 100))


## Host: a wall or pile just broke. A salt wall leaves a crystal or two in its rubble.
func host_broke(rock: Breakable) -> void:
	print("[game] %s broken" % rock.name)
	if rock.kind != Breakable.Kind.SALT_WALL:
		return
	for i: int in randi_range(1, 2):
		var at: Vector3 = rock.global_position + rock.global_basis.z * randf_range(-0.6, 0.6) + Vector3(randf_range(-1.0, 1.0), 0.6, 0.0)
		_spawn_item_at(&"salzkristall", randi_range(8, 18), Transform3D(Basis.IDENTITY, at))


## E on a rail cart: start or stop pushing it.
@rpc("any_peer", "call_local", "reliable")
func request_push_rail(cart_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var cart: RailCart = get_node_or_null(cart_path) as RailCart
	var player: Player = player_by_peer(_sender())
	if cart == null or player == null or not player.alive or player.inventory.hands_busy():
		return
	if cart.pusher_peer == player.peer_id:
		cart.host_set_pusher(0)
	elif cart.pusher_peer == 0 and player.global_position.distance_to(cart.global_position) < _config.interact_distance + 1.0:
		cart.host_set_pusher(player.peer_id)


## The Grubenhund-Pfeiferl: the nearest rail cart rolls over to whoever blew it.
@rpc("any_peer", "call_local", "reliable")
func request_call_cart(where: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var player: Player = player_by_peer(_sender())
	if player == null or not player.alive:
		return
	play_sound_everywhere.rpc("pfeiferl", where + Vector3.UP * 1.5, 2.0, 50.0)
	var nearest: RailCart = null
	for item: WorldItem in _items():
		var cart: RailCart = item as RailCart
		if cart != null and (nearest == null or cart.global_position.distance_to(where) < nearest.global_position.distance_to(where)):
			nearest = cart
	if nearest == null or mine == null or mine.rails == null:
		_show_message_key.rpc_id(player.peer_id, "MSG_NO_RAILS")
		return
	if mine.rails.distance_to(where) > mine.chunk_set.cell_size:
		_show_message_key.rpc_id(player.peer_id, "MSG_RAILS_FAR")
	nearest.host_call(where)
	print("[game] Hunt called by P%d" % player.peer_id)


## The Seil: thrown down the edge at `point` (looking along `flat`), where there is a drop.
@rpc("any_peer", "call_local", "reliable")
func request_rope(item_path: NodePath, point: Vector3, flat: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var item: WorldItem = get_node_or_null(item_path) as WorldItem
	var player: Player = player_by_peer(_sender())
	if item == null or player == null or item.holder_peer != player.peer_id or mine == null:
		return
	if point.distance_to(player.global_position) > _config.interact_distance + 1.5:
		return
	var edge: Array[Vector3] = _find_drop(point, flat.normalized())
	if edge.is_empty():
		_show_message_key.rpc_id(player.peer_id, "MSG_ROPE_NO_EDGE")
		return
	item.host_vanish()
	_next_item += 1
	_place_rope.rpc("Rope%d" % _next_item, edge[0], edge[1])
	play_sound_everywhere.rpc("rope", edge[0])


## Walks from `point` along `flat` in small steps until the floor drops away by more than a
## man's height: [top of the rope, bottom], or [] when there is no edge within reach.
func _find_drop(point: Vector3, flat: Vector3) -> Array[Vector3]:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var depth: float = _config.seil_length + 1.5
	for i: int in 14:
		var probe: Vector3 = point + flat * (0.2 * i) + Vector3.UP * 0.4
		if not clear_line(point + Vector3.UP * 0.4, probe):
			return []  # a wall before any edge
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(probe, probe + Vector3.DOWN * depth, 1)
		var hit: Dictionary = space.intersect_ray(query)
		var floor_y: float = (hit.position as Vector3).y if not hit.is_empty() else probe.y - depth
		if point.y - floor_y > 1.8:
			# A bulge of the wall just under the edge is not the bottom: look a little further out.
			for extra: int in range(1, 4):
				var further: Vector3 = probe + flat * (0.2 * extra)
				var deeper: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(further, further + Vector3.DOWN * depth, 1))
				floor_y = minf(floor_y, (deeper.position as Vector3).y if not deeper.is_empty() else further.y - depth)
			var top: Vector3 = Vector3(probe.x, point.y, probe.z) + flat * 0.1
			return [top, Vector3(top.x, maxf(floor_y, top.y - _config.seil_length), top.z)]
	return []


@rpc("authority", "call_local", "reliable")
func _place_rope(rope_name: String, top: Vector3, bottom: Vector3) -> void:
	if mine == null:
		return
	var rope: Rope = Rope.new()
	rope.name = rope_name
	mine.add_child(rope)
	rope.setup(top, bottom)


## Hold E on a rope's hook: the Seil comes back up into your pocket.
@rpc("any_peer", "call_local", "reliable")
func request_take_rope(rope_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var rope: Rope = get_node_or_null(rope_path) as Rope
	var player: Player = player_by_peer(_sender())
	if rope == null or player == null or not player.alive or player.inventory.place_for(ItemData.WeightClass.LIGHT) == Inventory.NONE:
		return
	if player.global_position.distance_to(rope.top) > _config.interact_distance + 1.5:
		return
	var top: Vector3 = rope.top
	_remove_rope.rpc(rope.get_path())
	play_sound_everywhere.rpc("rope", top)
	var item: WorldItem = _spawn_item_at(&"seil", 0, Transform3D(Basis.IDENTITY, top + Vector3.UP * 0.3))
	# Into the pocket once every peer has the new item.
	await get_tree().create_timer(0.3).timeout
	var place: int = player.inventory.place_for(ItemData.WeightClass.LIGHT) if is_instance_valid(player) else Inventory.NONE
	if is_instance_valid(item) and place != Inventory.NONE and item.state == WorldItem.State.FREE:
		item.host_take(player.peer_id, place)


@rpc("authority", "call_local", "reliable")
func _remove_rope(rope_path: NodePath) -> void:
	var rope: Node = get_node_or_null(rope_path)
	if rope != null:
		rope.queue_free()


## The bell at a Salzsee landing: the ferry crosses over. The bell carries far.
@rpc("any_peer", "call_local", "reliable")
func request_ferry(ferry_path: NodePath, bell_at: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var ferry: Ferry = get_node_or_null(ferry_path) as Ferry
	var player: Player = player_by_peer(_sender())
	if ferry == null or player == null or not player.alive or player.global_position.distance_to(bell_at) > _config.interact_distance + 2.0:
		return
	play_sound_everywhere.rpc("ferry_bell", bell_at, 4.0, 70.0)
	host_noise(bell_at, _config.noise_bell)
	if ferry.host_ring():
		print("[game] ferry crossing")


## A message for one player (host), by translation key.
func message_to(peer: int, key: String) -> void:
	if peer == multiplayer.get_unique_id():
		_show_message_key(key)
	else:
		_show_message_key.rpc_id(peer, key)


## Picked a mine section on the Grubnplan in the Gasthaus (only unlocked ones, only in the hub).
@rpc("any_peer", "call_local", "reliable")
func request_section(index: int) -> void:
	if not multiplayer.is_server() or phase != Phase.HUB or index < 0 or index >= biomes.size():
		return
	if not section_unlocked(index, GameState.run.cycle):
		return
	biome_index = index
	_broadcast_run()
	print("[game] section %s picked" % biomes[index].id)


## Whether mine section `index` can be picked in quota cycle `cycle` (BiomeRule.unlock_cycle).
func section_unlocked(index: int, cycle: int) -> bool:
	var rule: BiomeRule = _config.biome_rule(biomes[index].id)
	return rule == null or cycle >= rule.unlock_cycle


## The Funkgerät's call button: a crackle on every other Funkgerät in the crew.
@rpc("any_peer", "call_local", "reliable")
func request_radio_call() -> void:
	if not multiplayer.is_server():
		return
	var caller: Player = player_by_peer(_sender())
	if caller != null and caller.alive and caller.has_tool(&"funkgeraet"):
		_radio_call.rpc(caller.peer_id)


@rpc("authority", "call_local", "reliable")
func _radio_call(caller_peer: int) -> void:
	var me: Player = local_player()
	var caller: Player = player_by_peer(caller_peer)
	if me == null or caller == null or not me.has_tool(&"funkgeraet"):
		return
	me.play_radio(0.9)
	if me != caller:
		show_message(tr("MSG_RADIO_CALL") % caller.display_name())


## The owner's character landed hard (movement is client-side, health is the host's).
@rpc("any_peer", "call_local", "reliable")
func request_fall_damage(amount: int) -> void:
	if not multiplayer.is_server():
		return
	var player: Player = player_by_peer(_sender())
	if player != null:
		host_damage_player(player, clampi(amount, 0, _config.player_max_health))


## Every source of damage to players goes through here (host).
func host_damage_player(player: Player, amount: int) -> void:
	if not player.alive or phase != Phase.SHIFT or amount <= 0:
		return
	var health: int = maxi(0, player.health - amount)
	player.set_health.rpc(health)
	if health == 0:
		_kill_player(player)


func _kill_player(player: Player) -> void:
	_drop_everything(player)
	# The body stays down there as heavy loot: carried to the lift, it pays Sterbegeld (§3).
	var at: Transform3D = Transform3D(Basis(Vector3.UP, player.rotation.y), player.global_position + Vector3.UP * 0.3)
	var corpse: WorldItem = _spawn_item_at(&"leiche", _config.sterbegeld, at)
	_corpses[String(corpse.name)] = [player.peer_id, Time.get_ticks_msec() / 1000.0]
	player.die.rpc()
	_player_message.rpc("MSG_PLAYER_DIED", player.player_number, player.peer_id)
	print("[game] P%d died, corpse spawned" % player.peer_id)


@rpc("any_peer", "call_local", "reliable")
func request_hit(creature_path: NodePath, damage: int, from: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var creature: Creature = get_node_or_null(creature_path) as Creature
	if creature != null:
		creature.host_hit(damage, from)


## "Plärren": a loud shout. Scares Bergmandl nearby (DESIGN.md §6, DECISIONS "Plärren key").
## A shout into the voice chat comes with `with_sound` false: the real voice is heard already.
@rpc("any_peer", "call_local", "reliable")
func request_shout(peer: int, where: Vector3, with_sound: bool = true) -> void:
	if not multiplayer.is_server():
		return
	if with_sound:
		_play_shout.rpc(peer)
	# Loud voices draw the Tatzelwurm (DESIGN.md §9).
	host_noise(where, _config.noise_shout)
	for creature: Creature in creatures():
		if creature.global_position.distance_to(where) <= _config.shout_radius:
			creature.host_shouted_at(where)


## An emote (DESIGN.md §9). The Jodler is heard far through the mine and draws creatures.
@rpc("any_peer", "call_local", "reliable")
func request_emote(kind: int) -> void:
	if not multiplayer.is_server():
		return
	var player: Player = player_by_peer(_sender())
	if player == null or not player.alive or kind < 0 or kind >= Player.Emote.size():
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now < float(player.get_meta(&"emote_until", 0.0)):
		return
	var yodel: bool = kind == Player.Emote.JODLER
	player.set_meta(&"emote_until", now + (_config.jodler_cooldown if yodel else 1.5))
	_play_emote.rpc(player.peer_id, kind)
	if yodel:
		host_noise(player.global_position, _config.noise_jodler)
		print("[game] P%d yodels" % player.peer_id)


@rpc("authority", "call_local", "reliable")
func _play_emote(peer: int, kind: int) -> void:
	var player: Player = player_by_peer(peer)
	if player != null:
		player.play_emote(kind as Player.Emote)


@rpc("authority", "call_local", "reliable")
func _play_shout(peer: int) -> void:
	var player: Player = player_by_peer(peer)
	if player != null:
		player.play_shout()


@rpc("any_peer", "call_local", "reliable")
func play_sound_everywhere(sound: String, where: Vector3, volume_db: float = 0.0, max_distance: float = 30.0) -> void:
	Audio.play_at(sound, where, &"SFX", volume_db, max_distance)


@rpc("authority", "call_local", "reliable")
func _show_message_key(key: String) -> void:
	show_message(tr(key))


## A message about a player ("Kumpl 2 is hin!"), not shown to that player themselves.
@rpc("authority", "call_local", "reliable")
func _player_message(key: String, number: int, about_peer: int) -> void:
	if about_peer == multiplayer.get_unique_id():
		show_message(tr("MSG_YOU_REVIVED") if key == "MSG_REVIVED" else tr("MSG_YOU_DIED"), 5.0)
		return
	var about: Player = player_by_peer(about_peer)
	show_message(tr(key) % (about.display_name() if about != null else tr("PLAYER_NAME") % number), 4.0)


# --- free item physics (host simulates, clients follow) -----------------------------------------

## Sends the transforms of free items that moved since the last send. Moving items go out
## unreliably about 20 times a second; once an item comes to rest its final transform goes
## out reliably, so every client ends up with exactly where it lies.
func _host_sync_items(delta: float) -> void:
	_item_sync_left -= delta
	if _item_sync_left > 0.0:
		return
	_item_sync_left = ITEM_SYNC_SECONDS
	if multiplayer.get_peers().is_empty():
		return
	var moving_names: PackedStringArray = []
	var moving: PackedFloat32Array = []
	var resting_names: PackedStringArray = []
	var resting: PackedFloat32Array = []
	for item: WorldItem in _items():
		if item.state != WorldItem.State.FREE:
			continue
		var xform: Transform3D = item.global_transform
		var moved: bool = not xform.is_equal_approx(item.sent_transform)
		if item.sleeping and (moved or not item.sent_reliably):
			_pack_item(item, resting_names, resting)
			item.sent_reliably = true
		elif not item.sleeping and moved:
			_pack_item(item, moving_names, moving)
			item.sent_reliably = false
	if not moving_names.is_empty():
		_item_transforms.rpc(moving_names, moving)
	if not resting_names.is_empty():
		_item_transforms_resting.rpc(resting_names, resting)


func _pack_item(item: WorldItem, names: PackedStringArray, values: PackedFloat32Array) -> void:
	var xform: Transform3D = item.global_transform
	var turn: Quaternion = xform.basis.get_rotation_quaternion()
	item.sent_transform = xform
	names.append(item.name)
	values.append_array([xform.origin.x, xform.origin.y, xform.origin.z, turn.x, turn.y, turn.z, turn.w])


@rpc("authority", "call_remote", "unreliable_ordered")
func _item_transforms(names: PackedStringArray, values: PackedFloat32Array) -> void:
	_apply_item_transforms(names, values)


@rpc("authority", "call_remote", "reliable")
func _item_transforms_resting(names: PackedStringArray, values: PackedFloat32Array) -> void:
	_apply_item_transforms(names, values)


func _apply_item_transforms(names: PackedStringArray, values: PackedFloat32Array) -> void:
	if values.size() != names.size() * ITEM_SYNC_STRIDE:
		return
	for i: int in names.size():
		var item: WorldItem = items_root.get_node_or_null(NodePath(names[i])) as WorldItem
		if item == null:
			continue
		var o: int = i * ITEM_SYNC_STRIDE
		var turn: Quaternion = Quaternion(values[o + 3], values[o + 4], values[o + 5], values[o + 6])
		item.net_push(Transform3D(Basis(turn), Vector3(values[o], values[o + 1], values[o + 2])))


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


# --- noise and smoke (host) -----------------------------------------------------------------------

## A noise or vibration at `where` that carries `reach` metres: every creature in reach hears
## it (the Tatzelwurm hunts by it, DESIGN.md §6).
func host_noise(where: Vector3, reach: float) -> void:
	if not multiplayer.is_server() or phase != Phase.SHIFT or reach <= 0.0:
		return
	for creature: Creature in creatures():
		if creature.global_position.distance_to(where) <= reach:
			creature.host_heard(where, reach)


## How far a player's movement carries right now: sprinting is loud, walking a little,
## crouching (sneaking) not at all; a rattling Schubkarre is loud too.
func movement_noise(player: Player) -> float:
	if not player.alive or player.global_position.y > HUB_FLOOR_ABOVE or not player.is_on_floor_now():
		return 0.0
	var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	if speed < 0.5 or player.crouching:
		return 0.0
	var reach: float = _config.noise_sprint if speed > _config.walk_speed * 1.2 else _config.noise_walk
	if player.inventory.hands is Schubkarre:
		reach = maxf(reach, _config.noise_schubkarre)
	return reach


func _host_tick_noise(delta: float) -> void:
	_noise_left -= delta
	if _noise_left > 0.0:
		return
	_noise_left = _config.noise_step_seconds
	for player: Player in players():
		host_noise(player.global_position, movement_noise(player))
	for item: WorldItem in _items():
		if item is RailCart and (item as RailCart).moving:
			host_noise(item.global_position, _config.noise_rail_cart)
	var now: float = Time.get_ticks_msec() / 1000.0
	_smokes = _smokes.filter(func(smoke: Array) -> bool: return float(smoke[2]) > now)


func add_smoke(centre: Vector3, radius: float, seconds: float) -> void:
	_smokes.append([centre, radius, Time.get_ticks_msec() / 1000.0 + seconds])


func in_smoke(point: Vector3) -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	for smoke: Array in _smokes:
		if float(smoke[2]) > now and (smoke[0] as Vector3).distance_to(point) < float(smoke[1]):
			return true
	return false


## A point just outside the smoke cloud around `point`, straight away from its centre.
func smoke_exit(point: Vector3) -> Vector3:
	for smoke: Array in _smokes:
		var centre: Vector3 = smoke[0]
		if centre.distance_to(point) < float(smoke[1]):
			var away: Vector3 = point - centre
			away.y = 0.0
			if away.length() < 0.1:
				away = Vector3.FORWARD
			return centre + away.normalized() * (float(smoke[1]) + 1.0)
	return point


func _biome_rule() -> BiomeRule:
	var rule: BiomeRule = _config.biome_rule(biomes[clampi(biome_index, 0, biomes.size() - 1)].id)
	return rule if rule != null else BiomeRule.new()


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
	var sounds: PackedStringArray = mine.chunk_set.ambience if mine != null and not mine.chunk_set.ambience.is_empty() else AMBIENCE
	var sound: String = sounds[randi() % sounds.size()]
	var offset: Vector3 = Vector3(randf_range(-1.0, 1.0), randf_range(0.5, 1.0), randf_range(-1.0, 1.0)).normalized() * randf_range(5.0, 18.0)
	var volume: float = -4.0 if sound == "rumble" or sound == "deep_groan" else -10.0
	Audio.play_at(sound, player.global_position + offset, &"Ambience", volume, 40.0, randf_range(0.85, 1.1))
