class_name CaveMesher
extends RefCounted
## Turns a chunk's open-space boxes into a rough, hand-hewn rock surface seen from inside.
## Every face is cut into GRID-sized quads; faces that touch another box or lie on the cell
## border (where the neighbour chunk continues) are left out. Every vertex is then pushed by
## world-space 3D noise, so the same point gets the same push in every chunk: neighbouring
## chunks meet without seams. Floors get only a gentle push so they stay walkable.

const GRID: float = 0.25
## How far walls and ceilings bulge (metres).
const WALL_AMPLITUDE: float = 0.32
## Slow sideways wander of whole tunnel walls (metres), so corridors are not ruler-straight.
const WANDER_AMPLITUDE: float = 0.6
## How much of the push a floor vertex gets vertically.
const FLOOR_VERTICAL: float = 0.18
## Metres of rock per texture repeat.
const UV_METRES: float = 3.0

enum Part { WALL, FLOOR }

static var _noise_cache: Dictionary = {}  # seed -> Array[FastNoiseLite]


class Result:
	var mesh: ArrayMesh
	var collision_faces: PackedVector3Array


static func build(boxes: Array[AABB], chunk_transform: Transform3D, half_cell: float, seed_value: int) -> Result:
	var noise: Array[FastNoiseLite] = _make_noise(seed_value)
	var builders: Dictionary = {Part.WALL: _SurfaceData.new(), Part.FLOOR: _SurfaceData.new()}
	for box: AABB in boxes:
		for axis: int in 3:
			for side: int in [-1, 1]:
				_add_face(box, axis, side, boxes, half_cell, chunk_transform, noise, builders)
	var mesh: ArrayMesh = ArrayMesh.new()
	var faces: PackedVector3Array = []
	for part: int in [Part.WALL, Part.FLOOR]:
		var data: _SurfaceData = builders[part]
		if data.indices.is_empty():
			continue
		data.finish_normals()
		var tool: SurfaceTool = SurfaceTool.new()
		tool.create_from_arrays(data.arrays(), Mesh.PRIMITIVE_TRIANGLES)
		tool.generate_tangents()
		tool.commit(mesh)
		mesh.surface_set_name(mesh.get_surface_count() - 1, "floor" if part == Part.FLOOR else "wall")
		for index: int in data.indices:
			faces.append(data.vertices[index])
	var result: Result = Result.new()
	result.mesh = mesh
	result.collision_faces = faces
	return result


## Accumulates one surface; vertices are shared by grid position so normals come out smooth.
class _SurfaceData:
	var vertices: PackedVector3Array = []
	var uvs: PackedVector2Array = []
	var normals: PackedVector3Array = []
	var indices: PackedInt32Array = []
	var _index_of: Dictionary = {}  # Vector3i grid key + face axis -> index
	var _normal_sum: Dictionary = {}  # Vector3i grid key -> Vector3

	func vertex(key: Vector3i, axis: int, position: Vector3, uv: Vector2) -> int:
		var id: Vector4i = Vector4i(key.x, key.y, key.z, axis)
		if _index_of.has(id):
			return _index_of[id]
		var index: int = vertices.size()
		vertices.append(position)
		uvs.append(uv)
		normals.append(Vector3.ZERO)
		_index_of[id] = index
		return index

	func add_normal(key: Vector3i, normal: Vector3) -> void:
		_normal_sum[key] = _normal_sum.get(key, Vector3.ZERO) + normal

	func finish_normals() -> void:
		for id: Vector4i in _index_of:
			var sum: Vector3 = _normal_sum.get(Vector3i(id.x, id.y, id.z), Vector3.UP)
			normals[_index_of[id]] = sum.normalized()

	func arrays() -> Array:
		var result: Array = []
		result.resize(Mesh.ARRAY_MAX)
		result[Mesh.ARRAY_VERTEX] = vertices
		result[Mesh.ARRAY_NORMAL] = normals
		result[Mesh.ARRAY_TEX_UV] = uvs
		result[Mesh.ARRAY_INDEX] = indices
		return result


## The slow sideways wander at a world point. Props and markers move by this so they stay
## against the walls they were placed at.
static func wander(world: Vector3, seed_value: int) -> Vector3:
	var noise: Array[FastNoiseLite] = _make_noise(seed_value)
	return Vector3(noise[3].get_noise_3dv(world), 0.0, noise[4].get_noise_3dv(world)) * WANDER_AMPLITUDE * 1.4


static func _make_noise(seed_value: int) -> Array[FastNoiseLite]:
	if _noise_cache.has(seed_value):
		return _noise_cache[seed_value]
	var result: Array[FastNoiseLite] = []
	# 0-2: rough detail per axis; 3-4: slow wander along x and z.
	for i: int in 5:
		var noise: FastNoiseLite = FastNoiseLite.new()
		noise.seed = seed_value + i * 7919
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		if i < 3:
			noise.frequency = 0.32
			noise.fractal_type = FastNoiseLite.FRACTAL_FBM
			noise.fractal_octaves = 4
			noise.fractal_gain = 0.45
		else:
			noise.frequency = 0.07
			noise.fractal_type = FastNoiseLite.FRACTAL_NONE
		result.append(noise)
	_noise_cache[seed_value] = result
	return result


static func _add_face(box: AABB, axis: int, side: int, boxes: Array[AABB], half_cell: float,
		chunk_transform: Transform3D, noise: Array[FastNoiseLite], builders: Dictionary) -> void:
	var plane: float = box.position[axis] + (box.size[axis] if side > 0 else 0.0)
	# The open end of a tunnel at the cell border: the neighbour carries on from here.
	if axis != 1 and is_equal_approx(absf(plane), half_cell):
		return
	var u_axis: int = (axis + 1) % 3
	var v_axis: int = (axis + 2) % 3
	var outward: Vector3 = Vector3.ZERO
	outward[axis] = side
	var inward: Vector3 = -outward
	var part: int = Part.FLOOR if axis == 1 and side < 0 else Part.WALL
	var data: _SurfaceData = builders[part]
	var steps_u: int = roundi(box.size[u_axis] / GRID)
	var steps_v: int = roundi(box.size[v_axis] / GRID)
	var world_inward: Vector3 = (chunk_transform.basis * inward).normalized()
	for i: int in steps_u:
		for j: int in steps_v:
			var centre: Vector3 = Vector3.ZERO
			centre[axis] = plane
			centre[u_axis] = box.position[u_axis] + (i + 0.5) * GRID
			centre[v_axis] = box.position[v_axis] + (j + 0.5) * GRID
			if _inside_any(centre + outward * (GRID * 0.5), boxes):
				continue
			var corners: Array[int] = []
			var keys: Array[Vector3i] = []
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var local: Vector3 = Vector3.ZERO
				local[axis] = plane
				local[u_axis] = box.position[u_axis] + (i + corner.x) * GRID
				local[v_axis] = box.position[v_axis] + (j + corner.y) * GRID
				var key: Vector3i = Vector3i((local / GRID).round())
				var world: Vector3 = chunk_transform * local
				var pushed_world: Vector3 = world + _push(world, local.y, noise)
				var uv: Vector2 = _uv(world, world_inward)
				corners.append(data.vertex(key, axis, chunk_transform.affine_inverse() * pushed_world, uv))
				keys.append(key)
			_add_quad(data, corners, keys, inward)


static func _push(world: Vector3, local_height: float, noise: Array[FastNoiseLite]) -> Vector3:
	var push: Vector3 = Vector3(noise[0].get_noise_3dv(world), noise[1].get_noise_3dv(world), noise[2].get_noise_3dv(world))
	push *= WALL_AMPLITUDE * 1.6
	push += Vector3(noise[3].get_noise_3dv(world), 0.0, noise[4].get_noise_3dv(world)) * WANDER_AMPLITUDE * 1.4
	if local_height <= GRID * 0.5:
		push.y *= FLOOR_VERTICAL
		push.y = absf(push.y) * 0.5 + push.y * 0.5  # floors bump up more than they dip
	return push


static func _uv(world: Vector3, normal: Vector3) -> Vector2:
	var n: Vector3 = normal.abs()
	if n.y >= n.x and n.y >= n.z:
		return Vector2(world.x, world.z) / UV_METRES
	if n.x >= n.z:
		return Vector2(world.z * signf(normal.x), -world.y) / UV_METRES
	return Vector2(-world.x * signf(normal.z), -world.y) / UV_METRES


static func _add_quad(data: _SurfaceData, corners: Array[int], keys: Array[Vector3i], inward: Vector3) -> void:
	for tri: Array in [[0, 1, 2], [0, 2, 3]]:
		var a: int = corners[tri[0]]
		var b: int = corners[tri[1]]
		var c: int = corners[tri[2]]
		# Godot's front faces are the ones whose Plane(a, b, c) normal faces the viewer.
		var normal: Vector3 = Plane(data.vertices[a], data.vertices[b], data.vertices[c]).normal
		if normal.dot(inward) < 0.0:
			var swap: int = b
			b = c
			c = swap
			normal = -normal
		data.indices.append_array([a, b, c])
		# Normals from the pushed triangles, so the bumps catch the light.
		for corner: int in tri:
			data.add_normal(keys[corner], normal)


static func _inside_any(point: Vector3, boxes: Array[AABB]) -> bool:
	for box: AABB in boxes:
		var end: Vector3 = box.end
		if point.x >= box.position.x and point.x <= end.x \
				and point.y >= box.position.y and point.y <= end.y \
				and point.z >= box.position.z and point.z <= end.z:
			return true
	return false
