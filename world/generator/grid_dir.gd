class_name GridDir
extends RefCounted
## The four grid directions as bit flags. Grid x runs along world +X, grid y along world +Z,
## so N is world -Z. A chunk turned by `steps` quarter turns clockwise (seen from above)
## has rotation.y = -PI / 2 * steps.

const N: int = 1
const E: int = 2
const S: int = 4
const W: int = 8
const ALL: Array[int] = [N, E, S, W]


static func offset(dir: int) -> Vector2i:
	match dir:
		N:
			return Vector2i(0, -1)
		E:
			return Vector2i(1, 0)
		S:
			return Vector2i(0, 1)
		W:
			return Vector2i(-1, 0)
	assert(false, "not a single direction: %d" % dir)
	return Vector2i.ZERO


static func opposite(dir: int) -> int:
	return rotate_mask(dir, 2)


## Turns a direction mask `steps` quarter turns clockwise (N -> E -> S -> W).
static func rotate_mask(mask: int, steps: int) -> int:
	var result: int = mask & 15
	for _i: int in posmod(steps, 4):
		result = ((result << 1) | (result >> 3)) & 15
	return result


static func count(mask: int) -> int:
	var n: int = 0
	for dir: int in ALL:
		if mask & dir:
			n += 1
	return n


static func rotation_y(steps: int) -> float:
	return -PI / 2.0 * posmod(steps, 4)


static func suffix(dir: int) -> String:
	match dir:
		N:
			return "N"
		E:
			return "E"
		S:
			return "S"
		W:
			return "W"
	return ""
