@tool
class_name CaveBox
extends Node3D
## One box of open space inside a chunk (a tunnel piece or a room). The node's position is
## the centre of the box's floor. Sizes and positions must sit on CaveMesher.GRID.
## Name it with a _N/_E/_S/_W suffix to make it part of that opening.

@export var size: Vector3 = Vector3(4.0, 3.5, 4.0):
	set(value):
		size = value
		update_gizmos()


## The box in the chunk's local space (the chunk is this node's grandparent or higher;
## only translation is used, boxes are never rotated themselves).
func local_aabb(chunk: Node3D) -> AABB:
	var floor_centre: Vector3 = chunk.to_local(global_position) if is_inside_tree() else position
	return AABB(floor_centre - Vector3(size.x / 2.0, 0.0, size.z / 2.0), size)
