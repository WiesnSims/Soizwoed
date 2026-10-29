class_name Climbable
extends Area3D
## Something to climb (DESIGN.md §3): a ladder or a Seil. Standing in it, forward climbs up
## (down while looking down), back climbs down, jump lets go. Players register themselves
## while inside. On physics layer 6, so it never gets in the way of the interaction ray.

const LAYER: int = 32  # physics layer 6
const OVER_TOP: float = 0.5

## Width and depth of the climbing zone; its height is set by `setup`.
@export var footprint: Vector2 = Vector2(0.9, 0.9)
## A rotten ladder: rungs may break under someone carrying something heavy.
@export var rotten: bool = false

var height: float = 3.0


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 2
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if get_child_count() == 0:
		setup(height)


## Sizes the zone: from the floor at the node up to `new_height`, plus a little over the top so
## the climber rises above the edge before stepping off.
func setup(new_height: float) -> void:
	height = new_height
	for child: Node in get_children():
		child.queue_free()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(footprint.x, height + OVER_TOP, footprint.y)
	shape.shape = box
	shape.position = Vector3.UP * (height + OVER_TOP) / 2.0
	add_child(shape)


func top_y() -> float:
	return global_position.y + height


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player != null:
		player.enter_climbable(self)


func _on_body_exited(body: Node3D) -> void:
	var player: Player = body as Player
	if player != null:
		player.exit_climbable(self)
