class_name Ladder
extends Node3D
## A wooden ladder (DESIGN.md §3, §4). It faces -Z: you climb it from that side. A rotten one
## creaks, and gives way under someone carrying something heavy (Player._tick_rotten asks the
## host, Game breaks it on every peer). Part of its chunk, so it has the same path everywhere.

@export var height: float = 5.0
@export var rotten: bool = true

var broken: bool = false

var _climbable: Climbable
var _rungs: Array[MeshInstance3D] = []


func _ready() -> void:
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.26, 0.16) if rotten else Color(0.5, 0.36, 0.22)
	wood.roughness = 0.9
	var timber: Material = load("res://assets/materials/timber_wood.tres") as Material
	for side: float in [-0.25, 0.25]:
		var rail: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.07, height, 0.07)
		rail.mesh = box
		rail.material_override = timber
		rail.position = Vector3(side, height / 2.0, 0.0)
		add_child(rail)
	var rung_count: int = floori(height / 0.32)
	for i: int in rung_count:
		var rung: MeshInstance3D = MeshInstance3D.new()
		var bar: BoxMesh = BoxMesh.new()
		bar.size = Vector3(0.5, 0.045, 0.05)
		rung.mesh = bar
		rung.material_override = wood
		rung.position = Vector3(0.0, 0.25 + i * 0.32, 0.0)
		# Rotten: some rungs hang crooked, a few are already gone.
		if rotten and i % 5 == 3:
			rung.visible = false
		elif rotten:
			rung.rotation.z = sin(i * 2.7) * 0.12
		add_child(rung)
		_rungs.append(rung)
	_climbable = Climbable.new()
	_climbable.height = height
	_climbable.rotten = rotten
	_climbable.footprint = Vector2(0.9, 0.8)
	_climbable.position = Vector3(0.0, 0.0, -0.35)
	add_child(_climbable)


## Every peer: the rotten wood gives way; whoever is on it falls.
func break_apart() -> void:
	if broken:
		return
	broken = true
	Audio.play_at("plank_crack", global_position + Vector3.UP * height * 0.5, &"SFX", 2.0, 30.0)
	if _climbable != null:
		_climbable.queue_free()
		_climbable = null
	for i: int in _rungs.size():
		if i > 2:
			_rungs[i].visible = false
