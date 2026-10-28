class_name ENetBackend
extends NetBackend
## Plain ENet: for development and for running several instances on one PC without Steam.


func get_backend_name() -> String:
	return "enet"


func is_available() -> bool:
	return true


func create_host(port: int, max_clients: int) -> MultiplayerPeer:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(port, max_clients)
	if error != OK:
		printerr("[net] ENet host on port %d failed: %s" % [port, error_string(error)])
		return null
	return peer


func create_client(target: String, port: int) -> MultiplayerPeer:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(target, port)
	if error != OK:
		printerr("[net] ENet join %s:%d failed: %s" % [target, port, error_string(error)])
		return null
	return peer
