class_name ItemIcons
extends Node
## Icons for the hotbar, rendered from each item's own 3D model (so every item, now or later,
## has a fitting icon without drawing one): its meshes in a small off-screen viewport with a
## light, once per item, cached. Guns are shown from the side, everything else three-quarter.
## Without a renderer (headless) there are no icons and the HUD shows names instead.

signal icon_ready(id: StringName)

const SIZE: int = 128

var _cache: Dictionary = {}  # StringName -> Texture2D (null while rendering / unavailable)


## The icon of `data`, or null until it is rendered (icon_ready says when).
func icon(data: ItemData) -> Texture2D:
	if data == null:
		return null
	if not _cache.has(data.id):
		_cache[data.id] = null
		if DisplayServer.get_name() != "headless":
			_render(data)
	return _cache[data.id]


func _render(data: ItemData) -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var root: Node3D = Node3D.new()
	viewport.add_child(root)
	var bounds: AABB = _copy_meshes(data.scene.instantiate(), root)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.55, 0.52, 0.48)
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	root.add_child(environment)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.light_energy = 1.6
	root.add_child(key)
	key.look_at_from_position(Vector3(1.0, 2.0, 1.5), Vector3.ZERO)
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.light_energy = 0.6
	rim.light_color = Color(0.8, 0.85, 1.0)
	root.add_child(rim)
	rim.look_at_from_position(Vector3(-1.5, 0.5, -1.0), Vector3.ZERO)
	var camera: Camera3D = Camera3D.new()
	camera.fov = 30.0
	root.add_child(camera)
	var side: bool = data.weapon != null or data.slot_kind() == ItemData.SlotKind.WEAPON
	var direction: Vector3 = Vector3(1.0, 0.35, 0.12).normalized() if side else Vector3(0.7, 0.6, 0.9).normalized()
	var radius: float = maxf(0.02, bounds.size.length() / 2.0)
	var centre: Vector3 = bounds.get_center()
	camera.look_at_from_position(centre + direction * radius / sin(deg_to_rad(15.0)) * 1.05, centre)
	camera.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not is_instance_valid(viewport):
		return
	var image: Image = viewport.get_texture().get_image()
	_cache[data.id] = ImageTexture.create_from_image(image)
	viewport.queue_free()
	icon_ready.emit(data.id)


## Copies the item's meshes (not the item: no script, no physics) under `root`; their bounds.
func _copy_meshes(item: Node, root: Node3D) -> AABB:
	var bounds: AABB = AABB()
	var first: bool = true
	for node: Node in item.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		var xform: Transform3D = mesh.transform
		var parent: Node = mesh.get_parent()
		while parent != item and parent is Node3D:
			xform = (parent as Node3D).transform * xform
			parent = parent.get_parent()
		var copy: MeshInstance3D = mesh.duplicate() as MeshInstance3D
		for child: Node in copy.get_children():
			copy.remove_child(child)
			child.queue_free()
		root.add_child(copy)
		copy.transform = xform
		var box: AABB = xform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	item.free()
	return bounds
