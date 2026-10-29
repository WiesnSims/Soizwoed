class_name RailLine
extends Node3D
## The track of the Oberer Stollen (DESIGN.md §4: mine carts on rails): one line from the
## Förderkorb along the main path, as deep as there are chunks that allow rails. Built locally on
## every peer from the layout, following the walls' wander so it stays in the tunnel. A rail cart
## sits at a distance `s` (metres) along it.

const PIECE: float = 2.0
const GAUGE: float = 0.6
const SLEEPER_STEP: float = 0.7
const HEIGHT: float = 0.05

var points: PackedVector3Array = []
## Distance along the track at each point.
var distances: PackedFloat32Array = []


## Lays the track through `corners` (world positions on the tunnel centre lines).
func build(corners: PackedVector3Array, seed_value: int) -> void:
	points.clear()
	distances.clear()
	for i: int in corners.size() - 1:
		var from: Vector3 = corners[i]
		var to: Vector3 = corners[i + 1]
		var pieces: int = maxi(1, ceili(from.distance_to(to) / PIECE))
		for j: int in pieces:
			_add_point(from.lerp(to, float(j) / pieces), seed_value)
	_add_point(corners[corners.size() - 1], seed_value)
	_build_mesh()


func _add_point(at: Vector3, seed_value: int) -> void:
	var point: Vector3 = at + CaveMesher.wander(at, seed_value)
	point.y = at.y + HEIGHT
	distances.append(0.0 if points.is_empty() else distances[distances.size() - 1] + points[points.size() - 1].distance_to(point))
	points.append(point)


func length() -> float:
	return distances[distances.size() - 1] if not distances.is_empty() else 0.0


## Where along the track and which way it runs at distance `s`.
func transform_at(s: float) -> Transform3D:
	s = clampf(s, 0.0, length())
	var i: int = _segment(s)
	var from: Vector3 = points[i]
	var to: Vector3 = points[i + 1]
	var span: float = maxf(0.001, distances[i + 1] - distances[i])
	var at: Vector3 = from.lerp(to, (s - distances[i]) / span)
	return Transform3D(Basis.looking_at(to - from, Vector3.UP), at)


## The distance along the track closest to `where`.
func closest_s(where: Vector3) -> float:
	var best: float = 0.0
	var best_distance: float = INF
	for i: int in points.size() - 1:
		var on: Vector3 = Geometry3D.get_closest_point_to_segment(where, points[i], points[i + 1])
		var d: float = on.distance_to(where)
		if d < best_distance:
			best_distance = d
			best = distances[i] + points[i].distance_to(on)
	return best


func distance_to(where: Vector3) -> float:
	return transform_at(closest_s(where)).origin.distance_to(where)


func _segment(s: float) -> int:
	for i: int in points.size() - 1:
		if s <= distances[i + 1]:
			return i
	return maxi(0, points.size() - 2)


func _build_mesh() -> void:
	var rail: BoxMesh = BoxMesh.new()
	rail.size = Vector3(0.06, 0.1, 1.0)
	rail.material = load("res://assets/materials/rust_iron.tres") as Material
	var sleeper: BoxMesh = BoxMesh.new()
	sleeper.size = Vector3(1.0, 0.1, 0.2)
	sleeper.material = load("res://assets/materials/timber_wood.tres") as Material
	var rails: Array[Transform3D] = []
	var sleepers: Array[Transform3D] = []
	for i: int in points.size() - 1:
		var from: Vector3 = points[i]
		var to: Vector3 = points[i + 1]
		var basis: Basis = Basis.looking_at(to - from, Vector3.UP)
		var mid: Vector3 = (from + to) / 2.0
		var stretch: Basis = basis.scaled_local(Vector3(1.0, 1.0, from.distance_to(to) + 0.05))
		for side: float in [-GAUGE / 2.0, GAUGE / 2.0]:
			rails.append(Transform3D(stretch, mid + basis.x * side + Vector3.UP * 0.08))
	var s: float = SLEEPER_STEP / 2.0
	while s < length():
		var at: Transform3D = transform_at(s)
		sleepers.append(Transform3D(at.basis.rotated(Vector3.UP, randf_range(-0.05, 0.05)), at.origin - Vector3.UP * 0.01))
		s += SLEEPER_STEP
	add_child(_multimesh(rail, rails, "Rails"))
	add_child(_multimesh(sleeper, sleepers, "Sleepers"))


static func _multimesh(mesh: Mesh, transforms: Array[Transform3D], node_name: String) -> MultiMeshInstance3D:
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i: int in transforms.size():
		multi.set_instance_transform(i, transforms[i])
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multi
	return instance
