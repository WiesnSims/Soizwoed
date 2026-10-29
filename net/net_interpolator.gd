class_name NetInterpolator
extends RefCounted
## Smooths motion that arrives over the network (DESIGN.md §11: ~20 Hz with interpolation).
## Keeps the last few snapshots and shows the state `delay` seconds in the past, blending
## between the two snapshots around that moment. A jump further than `snap_distance` is a
## teleport: the buffer starts over instead of sliding across the world. Pure logic, no nodes.

const MAX_SNAPSHOTS: int = 8

var delay: float = 0.1
var snap_distance: float = 4.0
## Result of the last sample().
var position: Vector3 = Vector3.ZERO
var rotation: Quaternion = Quaternion.IDENTITY
## A free extra value blended along (the head pitch of a player).
var aux: float = 0.0
var velocity: Vector3 = Vector3.ZERO

var _times: PackedFloat64Array = []
var _positions: PackedVector3Array = []
var _rotations: Array[Quaternion] = []
var _aux: PackedFloat32Array = []


func push(time: float, at: Vector3, turn: Quaternion, extra: float = 0.0) -> void:
	if not _times.is_empty():
		if at.distance_to(_positions[-1]) > snap_distance:
			clear()
		elif time <= _times[-1]:
			return  # out of order (unreliable packets)
	_times.append(time)
	_positions.append(at)
	_rotations.append(turn.normalized())
	_aux.append(extra)
	if _times.size() > MAX_SNAPSHOTS:
		_times.remove_at(0)
		_positions.remove_at(0)
		_rotations.remove_at(0)
		_aux.remove_at(0)


func clear() -> void:
	_times.clear()
	_positions.clear()
	_rotations.clear()
	_aux.clear()
	velocity = Vector3.ZERO


func is_empty() -> bool:
	return _times.is_empty()


## Updates position / rotation / aux / velocity for the moment `now` (same clock as push).
## Returns false when there is nothing to show yet.
func sample(now: float) -> bool:
	var count: int = _times.size()
	if count == 0:
		return false
	var at: float = now - delay
	if count == 1 or at <= _times[0]:
		_set_from(0, 0, 0.0)
		velocity = Vector3.ZERO
		return true
	for i: int in range(1, count):
		if at <= _times[i]:
			var span: float = _times[i] - _times[i - 1]
			_set_from(i - 1, i, (at - _times[i - 1]) / span)
			velocity = (_positions[i] - _positions[i - 1]) / span
			return true
	# Newer than the newest snapshot: hold still at the last one.
	_set_from(count - 1, count - 1, 0.0)
	velocity = Vector3.ZERO
	return true


func _set_from(a: int, b: int, weight: float) -> void:
	position = _positions[a].lerp(_positions[b], weight)
	rotation = _rotations[a].slerp(_rotations[b], weight)
	aux = lerpf(_aux[a], _aux[b], weight)
