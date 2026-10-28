class_name Foerderkorb
extends Node3D
## The lift cage (Förderkorb). The same scene stands in the Gasthaus and in the mine's
## station; whatever is inside one when the lift moves arrives in the other. The open side
## faces -Z. "Inside" is a box test, so items in hands and pockets count too.

const HALF_WIDTH: float = 1.45
const HEIGHT: float = 3.0

@export var in_hub: bool = false

@onready var clock: Label3D = $Clock
@onready var motor: AudioStreamPlayer3D = $Motor
@onready var lever: Node3D = $Lever


func contains(where: Vector3) -> bool:
	var local: Vector3 = to_local(where)
	return absf(local.x) < HALF_WIDTH and absf(local.z) < HALF_WIDTH and local.y > -0.5 and local.y < HEIGHT


## Where the n-th player stands after the ride (four corners, facing the open side).
func player_spot(index: int) -> Transform3D:
	var corners: Array[Vector3] = [Vector3(-0.6, 0.1, 0.4), Vector3(0.6, 0.1, 0.4), Vector3(-0.6, 0.1, -0.5), Vector3(0.6, 0.1, -0.5)]
	var local: Transform3D = Transform3D(Basis.IDENTITY, corners[index % corners.size()])
	return global_transform * local


## Moves a transform from this cage into `other`, keeping its place relative to the cage.
func carry_to(other: Foerderkorb, xform: Transform3D) -> Transform3D:
	return other.global_transform * global_transform.affine_inverse() * xform


func set_clock(text: String) -> void:
	clock.text = text


func play_ride() -> void:
	Audio.play_at("schacht_signal_%d" % (2 if in_hub else 1), global_position + Vector3.UP * 2.5, &"SFX", 0.0, 40.0)
	motor.play()


func stop_ride() -> void:
	motor.stop()
	Audio.play_at("lift_stop", global_position, &"SFX", 0.0, 30.0)
