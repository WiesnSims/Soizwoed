class_name MuffledAudio
extends AudioStreamPlayer3D
## A 3D sound that gets muffled when rock is between it and the listener (DESIGN.md §6:
## creature voices are muffled through walls). Checked a few times a second while playing.

const OPEN_CUTOFF_HZ: float = 9000.0
const BLOCKED_CUTOFF_HZ: float = 900.0
const CHECK_SECONDS: float = 0.2

var _check_left: float = 0.0


func _process(delta: float) -> void:
	if not playing:
		return
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = CHECK_SECONDS
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position, camera.global_position, 1)
	var blocked: bool = not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	attenuation_filter_cutoff_hz = BLOCKED_CUTOFF_HZ if blocked else OPEN_CUTOFF_HZ
