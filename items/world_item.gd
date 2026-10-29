class_name WorldItem
extends RigidBody3D
## A loot item, tool or consumable in the world. Host-authoritative: peers ask the host (via
## Game) to take / drop / load it; the host calls one of the host_* functions, which change
## the state on every peer with one reliable RPC. Solo runs the same code locally.
## While not free the item follows a point: a player's hand, a cart slot, a creature's arms.

signal state_changed

enum State { FREE, HELD, STORED, CARTED, STOLEN }

const IMPACT_SPEED: float = 4.5
const LAYER_ITEMS: int = 4  # physics layer 3

var data: ItemData
var value: int = 0
var state: State = State.FREE
## Peer id of the holding player (HELD / STORED), 0 otherwise.
var holder_peer: int = 0
## The cart carrying this item (CARTED).
var cart: Schubkarre
var follow: Node3D

var _impact_cooldown: float = 0.0


func _ready() -> void:
	add_to_group(&"items")
	collision_layer = LAYER_ITEMS
	collision_mask = 1 | LAYER_ITEMS
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	contact_monitor = data.fragile
	max_contacts_reported = 2 if data.fragile else 0
	continuous_cd = true


func display_name() -> String:
	return tr(data.name_key)


func interaction_text(player: Player) -> String:
	if state != State.FREE and state != State.CARTED:
		return ""
	var pushing: Schubkarre = player.inventory.hands as Schubkarre
	if pushing != null and is_loot() and state == State.FREE:
		return tr("PROMPT_LOAD_CART") if pushing.can_load(self) else tr("PROMPT_CART_FULL")
	return tr("PROMPT_PICK_UP") % display_name()


func is_loot() -> bool:
	return data.kind == ItemData.Kind.LOOT


func _physics_process(delta: float) -> void:
	_impact_cooldown = maxf(0.0, _impact_cooldown - delta)
	if follow != null and is_instance_valid(follow):
		global_transform = follow.global_transform
	if data.fragile and state == State.FREE and multiplayer.is_server():
		_check_impacts()


func _check_impacts() -> void:
	if _impact_cooldown > 0.0 or get_contact_count() == 0:
		return
	if linear_velocity.length() > IMPACT_SPEED:
		_impact_cooldown = 0.5
		value = roundi(value * (1.0 - data.fragile_loss))
		Game.instance.play_sound_everywhere.rpc("glass_clink", global_position)


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


## Moves a free item (e.g. with the lift) on every peer.
func host_move(to: Transform3D) -> void:
	_apply_state.rpc(state, holder_peer, 0, NodePath(), to)


## Removes the item from the game (sold, used up, or lost in the mine).
func host_vanish() -> void:
	_vanish.rpc()


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
		State.CARTED:
			follow = get_node_or_null(follow_path) as Node3D
			cart = follow.get_parent() as Schubkarre if follow != null else null
			if cart != null:
				cart.cargo.append(self)
		State.STOLEN:
			follow = get_node_or_null(follow_path) as Node3D
		State.FREE:
			global_transform = at
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
	freeze = new_state != State.FREE
	collision_layer = LAYER_ITEMS if new_state == State.FREE or new_state == State.CARTED else 0
	if new_state != State.STORED:
		visible = true
	state_changed.emit()


@rpc("authority", "call_local", "reliable")
func _vanish() -> void:
	_leave_current_holder()
	hide()
	if multiplayer.is_server():
		queue_free()  # the spawner removes it on the clients


func _exit_tree() -> void:
	_leave_current_holder()


func _leave_current_holder() -> void:
	if holder_peer != 0 and Game.instance != null:
		var player: Player = Game.instance.player_by_peer(holder_peer)
		if player != null:
			player.inventory.remove(self)
	holder_peer = 0
	if cart != null and is_instance_valid(cart):
		cart.cargo.erase(self)
	cart = null
