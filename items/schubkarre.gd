class_name Schubkarre
extends CargoItem
## The wheelbarrow: pushed with both hands, carries one heavy or up to three smaller loot
## items at near-normal speed (DESIGN.md §7). Loot gets in by looking at it while pushing,
## by looking at the parked barrow and pressing E (hands) or G (anything), or simply by
## landing in the bed. Loud on gravel.

## The bed in the barrow's own space: loot that comes to rest here is loaded.
const BED: AABB = AABB(Vector3(-0.45, 0.2, -0.55), Vector3(0.9, 0.8, 1.1))

@onready var rattle: AudioStreamPlayer3D = $Rattle


func capacity() -> int:
	return Balance.config.schubkarre_capacity_medium


func heavy_units() -> int:
	return Balance.config.schubkarre_capacity_medium


func bed() -> AABB:
	return BED


func interaction_text(player: Player) -> String:
	if state != State.FREE:
		return ""
	var loading: String = load_prompt(player)
	if loading != "":
		return loading
	var pocket: WorldItem = player.inventory.slots[player.inventory.selected] as WorldItem
	if player.inventory.hands == null and pocket != null and pocket.is_loot() and can_load(pocket):
		return tr("PROMPT_PUSH_CART") + "   " + tr("PROMPT_CART_DROP_IN") % pocket.display_name()
	return tr("PROMPT_PUSH_CART")


## A heavy item takes the middle.
func free_slot(item: WorldItem) -> Node3D:
	if units(item) > 1:
		return slots[1]
	return super(item)


func _physics_process(delta: float) -> void:
	super(delta)
	var moving: bool = state == State.HELD and follow != null
	if moving:
		var player: Player = Game.instance.player_by_peer(holder_peer)
		moving = player != null and Vector2(player.velocity.x, player.velocity.z).length() > 0.5
	if moving and not rattle.playing:
		rattle.play()
	elif not moving and rattle.playing:
		rattle.stop()
