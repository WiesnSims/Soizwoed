class_name Lake
extends Node3D
## The underground brine lake of the Salzsee (DESIGN.md §4): black, still water with its surface
## at this node, `size.y` deep. Falling in means swimming: slow, the carbide lamp goes out, you
## cannot hold anything heavy, and after a little while something down there gets hold of you
## (host: damage until you are out). The ferry is the way across; a wet path along the wall
## is the other.

@export var size: Vector3 = Vector3(12.0, 3.0, 8.0)

var _deep: Area3D
## Host: seconds each peer has been swimming.
var _time_in: Dictionary = {}
var _tick_left: float = 0.0


func _ready() -> void:
	var water: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(size.x + 1.0, size.z + 1.0)
	water.mesh = plane
	var surface: StandardMaterial3D = StandardMaterial3D.new()
	surface.albedo_color = Color(0.03, 0.06, 0.06, 0.9)
	surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surface.metallic_specular = 1.0
	surface.roughness = 0.03
	water.material_override = surface
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	_deep = Area3D.new()
	_deep.name = "Deep"
	_deep.collision_layer = Climbable.LAYER
	_deep.collision_mask = 2
	_deep.monitorable = false
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	# Deep once your feet are half a metre under the surface.
	box.size = Vector3(size.x, size.y, size.z)
	shape.shape = box
	shape.position = Vector3.DOWN * (0.5 + size.y / 2.0)
	_deep.add_child(shape)
	add_child(_deep)
	_deep.body_entered.connect(_on_body_entered)
	_deep.body_exited.connect(_on_body_exited)


func surface_y() -> float:
	return global_position.y


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player != null:
		player.enter_water(self)
		Audio.play_at("splash", player.global_position + Vector3.UP, &"SFX", 0.0, 30.0)


func _on_body_exited(body: Node3D) -> void:
	var player: Player = body as Player
	if player != null:
		player.exit_water(self)
		_time_in.erase(player.peer_id)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or Game.instance == null or Game.instance.phase != Game.Phase.SHIFT:
		return
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = 0.5
	var config: BalanceConfig = Balance.config
	for body: Node3D in _deep.get_overlapping_bodies():
		var player: Player = body as Player
		if player == null or not player.alive:
			continue
		var before: float = float(_time_in.get(player.peer_id, 0.0))
		_time_in[player.peer_id] = before + 0.5
		if before + 0.5 < config.deep_water_grace:
			continue
		if before < config.deep_water_grace:
			Game.instance.message_to(player.peer_id, "MSG_SOMETHING_IN_WATER")
		Game.instance.play_sound_everywhere.rpc("gurgle", player.global_position + Vector3.UP * 0.5)
		Game.instance.host_damage_player(player, ceili(config.deep_water_damage_per_second * 0.5))
