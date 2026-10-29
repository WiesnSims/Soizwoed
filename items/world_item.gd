class_name WorldItem
extends RigidBody3D
## A loot item, tool or consumable in the world. Host-authoritative: peers ask the host (via
## Game) to take / drop / load it; the host calls one of the host_* functions, which change
## the state on every peer with one reliable RPC. Solo runs the same code locally.
## While not free the item follows a point: a player's hand, a cart slot, a creature's arms.
## Free items are simulated on the host only; clients keep them kinematic and smoothly follow
## the transforms the host sends (Game batches them, see Game._host_sync_items).
## A heavy item can be carried by two players: `holder_peer` holds it, `helper_peer` has the
## other end (DESIGN.md §3).

signal state_changed

enum State { FREE, HELD, STORED, CARTED, STOLEN }

const IMPACT_SPEED: float = 4.5
## How quickly an item in hand catches up with the hand (higher = stiffer). Following happens
## every rendered frame, so it never lags the camera by a physics step.
const HAND_SHARPNESS: float = 28.0
const LAYER_ITEMS: int = 4  # physics layer 3
## Held heavy items sit on the interactables layer, so another player can grab the other end.
const LAYER_INTERACT: int = 16  # physics layer 5

var data: ItemData
var value: int = 0
var state: State = State.FREE
## Peer id of the holding player (HELD / STORED), 0 otherwise.
var holder_peer: int = 0
## Peer id of the second player carrying a heavy item together, 0 otherwise.
var helper_peer: int = 0
## The Schubkarre or rail cart carrying this item (CARTED).
var cart: CargoItem
var follow: Node3D

var _impact_cooldown: float = 0.0
## Clients: the host's transforms of this item while it is free.
var _net: NetInterpolator = NetInterpolator.new()
## Host: what was last sent to the clients (see Game._host_sync_items).
var sent_transform: Transform3D
var sent_reliably: bool = true


func _ready() -> void:
	add_to_group(&"items")
	collision_layer = LAYER_ITEMS
	collision_mask = 1 | LAYER_ITEMS
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	contact_monitor = data.fragile
	max_contacts_reported = 2 if data.fragile else 0
	continuous_cd = true
	_net.snap_distance = 6.0
	sent_transform = global_transform
	if not multiplayer.is_server():
		freeze = true


func display_name() -> String:
	return tr(data.name_key)


func interaction_text(player: Player) -> String:
	if can_help_carry(player):
		return tr("PROMPT_CARRY_TOGETHER") % display_name()
	if state != State.FREE and state != State.CARTED:
		return ""
	var pushing: Schubkarre = player.inventory.hands as Schubkarre
	if pushing != null and is_loot() and state == State.FREE:
		return tr("PROMPT_LOAD_CART") if pushing.can_load(self) else tr("PROMPT_CART_FULL")
	return tr("PROMPT_PICK_UP") % display_name()


func is_loot() -> bool:
	return data.kind == ItemData.Kind.LOOT


## Whether `player` can take the other end of this heavy item another player holds.
func can_help_carry(player: Player) -> bool:
	return state == State.HELD and helper_peer == 0 and holder_peer != player.peer_id \
			and data.weight_class == ItemData.WeightClass.HEAVY and not self is Schubkarre \
			and player.alive and player.inventory.hands == null


func _process(delta: float) -> void:
	if state == State.FREE:
		if not multiplayer.is_server() and _net.sample(Time.get_ticks_msec() / 1000.0):
			global_transform = Transform3D(Basis(_net.rotation), _net.position)
		return
	if follow == null or not is_instance_valid(follow):
		return
	var target: Transform3D = follow.global_transform
	if state == State.HELD and helper_peer != 0:
		var helper: Player = Game.instance.player_by_peer(helper_peer)
		if helper != null:
			target.origin = target.origin.lerp(helper.hold_point.global_position, 0.5)
	if state == State.HELD or state == State.STORED:
		var weight: float = 1.0 - exp(-HAND_SHARPNESS * delta)
		if global_position.distance_to(target.origin) > 2.0:
			weight = 1.0  # teleported: no swoosh across the world
		global_transform = global_transform.interpolate_with(target, weight)
	else:
		global_transform = target


func _physics_process(delta: float) -> void:
	_impact_cooldown = maxf(0.0, _impact_cooldown - delta)
	if data.fragile and state == State.FREE and multiplayer.is_server():
		_check_impacts()


func _check_impacts() -> void:
	if _impact_cooldown > 0.0 or get_contact_count() == 0:
		return
	if linear_velocity.length() > IMPACT_SPEED:
		_impact_cooldown = 0.5
		value = roundi(value * (1.0 - data.fragile_loss))
		Game.instance.play_sound_everywhere.rpc("glass_clink", global_position)


## Clients: the host's latest transform of this free item.
func net_push(xform: Transform3D) -> void:
	if state == State.FREE:
		_net.push(Time.get_ticks_msec() / 1000.0, xform.origin, xform.basis.get_rotation_quaternion())


# --- host side -------------------------------------------------------------------------------------

func host_take(peer: int, place: int) -> void:
	var new_state: State = State.HELD if place == Inventory.HANDS else State.STORED
	_apply_state.rpc(new_state, peer, place, NodePath(), global_transform)


func host_cart(slot: Node3D) -> void:
	_apply_state.rpc(State.CARTED, 0, 0, slot.get_path(), global_transform)


func host_steal(carry_point: Node3D) -> void:
	_apply_state.rpc(State.STOLEN, 0, 0, carry_point.get_path(), global_transform)


## Throws the item free from `at` with `velocity` (a drop is a soft throw).
func host_release(at: Transform3D, velocity: Vector3) -> void:
	_apply_state.rpc(State.FREE, 0, 0, NodePath(), at)
	linear_velocity = velocity
	angular_velocity = Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
	sent_transform = at
	sent_reliably = true


## Moves a free item (e.g. with the lift) on every peer.
func host_move(to: Transform3D) -> void:
	_apply_state.rpc(state, holder_peer, 0, NodePath(), to)
	sent_transform = to
	sent_reliably = true


## Gives the other end of this held heavy item to `peer` (0: the helper lets go).
func host_set_helper(peer: int) -> void:
	_apply_helper.rpc(peer)


## Removes the item from the game (sold, used up, or lost in the mine).
func host_vanish() -> void:
	_vanish.rpc()


## Sends this item's whole state to a peer that just joined (`place` from the holder's
## inventory). The spawner only knows where the item was first spawned.
func host_send_state_to(peer: int, place: int) -> void:
	var follow_path: NodePath = follow.get_path() if follow != null and (state == State.CARTED or state == State.STOLEN) else NodePath()
	_apply_state.rpc_id(peer, state, holder_peer, place, follow_path, global_transform)
	if helper_peer != 0:
		_apply_helper.rpc_id(peer, helper_peer)


# --- every peer ------------------------------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _apply_state(new_state: State, peer: int, place: int, follow_path: NodePath, at: Transform3D) -> void:
	_leave_current_holder()
	state = new_state
	holder_peer = peer
	follow = null
	match new_state:
		State.HELD, State.STORED:
			var player: Player = Game.instance.player_by_peer(peer)
			if player != null:
				follow = player.follow_point_for(self, place)
				player.inventory.put(self, data.weight_class, place)
				player.ray.add_exception(self)
		State.CARTED:
			follow = get_node_or_null(follow_path) as Node3D
			cart = follow.get_parent() as CargoItem if follow != null else null
			if cart != null:
				cart.cargo.append(self)
		State.STOLEN:
			follow = get_node_or_null(follow_path) as Node3D
		State.FREE:
			global_transform = at
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
			_net.clear()
			_net.push(Time.get_ticks_msec() / 1000.0, at.origin, at.basis.get_rotation_quaternion())
	freeze = new_state != State.FREE or not multiplayer.is_server()
	collision_layer = _layer_for(new_state)
	if new_state != State.STORED:
		visible = true
	state_changed.emit()


@rpc("authority", "call_local", "reliable")
func _apply_helper(peer: int) -> void:
	_leave_helper()
	var holder: Player = Game.instance.player_by_peer(holder_peer)
	var helper: Player = Game.instance.player_by_peer(peer)
	if peer == 0 or state != State.HELD or helper == null:
		if holder != null:
			holder.inventory.shared_carry = false
		state_changed.emit()
		return
	helper_peer = peer
	helper.inventory.put(self, data.weight_class, Inventory.HANDS)
	helper.inventory.shared_carry = true
	helper.ray.add_exception(self)
	if holder != null:
		holder.inventory.shared_carry = true
	state_changed.emit()


func _layer_for(for_state: State) -> int:
	if for_state == State.FREE or for_state == State.CARTED:
		return LAYER_ITEMS
	if for_state == State.HELD and data.weight_class == ItemData.WeightClass.HEAVY and not self is Schubkarre:
		return LAYER_INTERACT
	return 0


@rpc("authority", "call_local", "reliable")
func _vanish() -> void:
	_leave_current_holder()
	hide()
	if multiplayer.is_server():
		queue_free()  # the spawner removes it on the clients


func _exit_tree() -> void:
	_leave_current_holder()


func _leave_current_holder() -> void:
	_leave_helper()
	if holder_peer != 0 and Game.instance != null:
		var player: Player = Game.instance.player_by_peer(holder_peer)
		if player != null:
			player.inventory.remove(self)
			player.ray.remove_exception(self)
	holder_peer = 0
	if cart != null and is_instance_valid(cart):
		cart.cargo.erase(self)
	cart = null


func _leave_helper() -> void:
	if helper_peer != 0 and Game.instance != null:
		var helper: Player = Game.instance.player_by_peer(helper_peer)
		if helper != null:
			helper.inventory.remove(self)
			helper.ray.remove_exception(self)
		var holder: Player = Game.instance.player_by_peer(holder_peer)
		if holder != null:
			holder.inventory.shared_carry = false
	helper_peer = 0
