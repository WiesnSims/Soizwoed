class_name Stone
extends Node3D
## A stone a creature threw: every peer flies the same arc from the same start and velocity;
## only the host decides whether it hit a miner (DESIGN.md §11: enemy attacks belong to the host).

const LIFETIME: float = 3.0
const RADIUS: float = 0.12

var velocity: Vector3 = Vector3.ZERO
var damage: int = 0
## Who threw it, so it does not hit the thrower.
var thrower: Node3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _age: float = 0.0
var _done: bool = false


func _ready() -> void:
	var rock: StandardMaterial3D = StandardMaterial3D.new()
	rock.albedo_color = Color(0.45, 0.42, 0.38)
	rock.roughness = 0.95
	var mesh: MeshInstance3D = BodyParts.add(self, BodyParts.sphere(RADIUS * 0.7, 8), rock, Vector3.ZERO)
	mesh.scale = Vector3(1.0, 0.8, 1.2)
	Audio.play_at("stone_throw", global_position, &"Creatures", -4.0, 15.0)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	velocity.y -= _gravity * delta
	var from: Vector3 = global_position
	var to: Vector3 = from + velocity * delta
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1 | 2)
	if thrower != null and is_instance_valid(thrower) and thrower is CollisionObject3D:
		query.exclude = [(thrower as CollisionObject3D).get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		rotate_x(delta * 9.0)
		if _age > LIFETIME:
			queue_free()
		return
	global_position = hit.position
	_done = true
	Audio.play_at("stone_hit", global_position, &"SFX", -2.0, 20.0, randf_range(0.9, 1.1))
	var player: Player = hit.collider as Player
	if player != null and multiplayer.is_server() and Game.instance != null:
		Game.instance.host_damage_player(player, damage)
		print("[stone] hit P%d for %d" % [player.peer_id, damage])
	var tween: Tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_callback(queue_free)


## The launch velocity that lands a throw from `from` on `target` at about `speed` m/s.
static func lob(from: Vector3, target: Vector3, speed: float, gravity: float) -> Vector3:
	var flight: float = maxf(0.15, from.distance_to(target) / speed)
	return (target - from) / flight + Vector3.UP * 0.5 * gravity * flight
