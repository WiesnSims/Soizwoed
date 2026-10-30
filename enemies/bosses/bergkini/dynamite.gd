class_name Dynamite
extends Node3D
## A lit stick of dynamite (Da Bergkini throws them, DESIGN.md §6). Every peer flies the same arc
## from the same start and velocity, it bounces off the rock and lies there hissing; when the
## fuse is down the host's copy goes off (Game.host_explosion) and every copy is gone.

const RADIUS: float = 0.06
const MAX_BOUNCES: int = 3

var velocity: Vector3 = Vector3.ZERO
var fuse: float = 2.0
var damage: int = 0
## Who threw it, so it does not stick to the thrower.
var thrower: Node3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _bounces: int = 0
var _resting: bool = false
var _spark: OmniLight3D
var _hiss: AudioStreamPlayer3D


func _ready() -> void:
	var paper: StandardMaterial3D = BodyParts.rough(Color(0.62, 0.1, 0.07), 0.8, 0.6)
	BodyParts.add(self, BodyParts.cylinder(0.025, 0.025, 0.2, 8), paper, Vector3.ZERO, Vector3(90.0, 0.0, 0.0))
	BodyParts.add(self, BodyParts.cylinder(0.003, 0.003, 0.05, 4), BodyParts.rough(Color(0.2, 0.18, 0.15), 1.0, 0.2), Vector3(0.0, 0.0, -0.12), Vector3(90.0, 0.0, 0.0))
	_spark = OmniLight3D.new()
	_spark.light_color = Color(1.0, 0.7, 0.3)
	_spark.light_energy = 1.2
	_spark.omni_range = 3.0
	_spark.position = Vector3(0.0, 0.0, -0.15)
	add_child(_spark)
	_hiss = AudioStreamPlayer3D.new()
	_hiss.bus = &"SFX"
	_hiss.max_distance = 20.0
	_hiss.unit_size = 3.0
	add_child(_hiss)
	Audio.play_on(_hiss, "boeller_fuse")
	Audio.play_at("stone_throw", global_position, &"Creatures", -2.0, 18.0, 0.8)


func _process(_delta: float) -> void:
	# The fuse sparks.
	_spark.light_energy = randf_range(0.6, 1.8)


func _physics_process(delta: float) -> void:
	fuse -= delta
	if fuse <= 0.0:
		if multiplayer.is_server() and Game.instance != null:
			Game.instance.host_explosion(global_position, Balance.config.dynamite_radius, damage)
		queue_free()
		return
	if _resting:
		return
	velocity.y -= _gravity * delta
	var from: Vector3 = global_position
	var to: Vector3 = from + velocity * delta
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	if thrower != null and is_instance_valid(thrower) and thrower is CollisionObject3D:
		query.exclude = [(thrower as CollisionObject3D).get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		rotate_x(delta * 11.0)
		return
	var normal: Vector3 = hit.normal
	global_position = (hit.position as Vector3) + normal * RADIUS
	velocity = velocity.bounce(normal) * 0.35
	_bounces += 1
	Audio.play_at("stone_hit", global_position, &"SFX", -8.0, 12.0, 1.3)
	if normal.y > 0.7 or velocity.length() < 1.2 or _bounces >= MAX_BOUNCES:
		_resting = true
		rotation = Vector3(0.0, rotation.y, 0.0)
