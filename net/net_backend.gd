class_name NetBackend
extends RefCounted
## Common interface of the transport backends. Only NetworkManager uses these.


func get_backend_name() -> String:
	return "none"


## False when the backend cannot run here (e.g. Steam not running).
func is_available() -> bool:
	return false


## A peer hosting a session for up to `max_clients` clients, or null on failure.
func create_host(_port: int, _max_clients: int) -> MultiplayerPeer:
	return null


## A peer connecting to `target`, or null on failure.
func create_client(_target: String, _port: int) -> MultiplayerPeer:
	return null


## Called every frame while the backend is active.
func poll() -> void:
	pass
