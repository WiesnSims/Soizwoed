class_name TeamOverlay
extends Control
## The crew on the HUD (DESIGN.md §9): each teammate's name with small health and armour bars
## and the rounds of the gun in their hand; downed teammates marked through the rock with the
## seconds they have left and how far they are; and pings ("do!", middle mouse) for 5 s, on a
## spot or following a creature. Drawn in code every frame.

const LIST_AT: Vector2 = Vector2(24, 250)
const ROW: float = 40.0
const BAR: Vector2 = Vector2(130, 6)
const TEXT: Color = Color(0.96, 0.9, 0.78)
const DIM: Color = Color(0.7, 0.64, 0.55)
const HEALTH: Color = Color(0.85, 0.22, 0.17)
const ARMOUR: Color = Color(0.62, 0.66, 0.72)
const DOWNED: Color = Color(1.0, 0.36, 0.26)
const PING: Color = Color(1.0, 0.8, 0.35)
const PING_CREATURE: Color = Color(1.0, 0.42, 0.3)

## Active pings: {peer, point, target (Node3D or null), until}.
var _pings: Array[Dictionary] = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	_pings = _pings.filter(func(ping: Dictionary) -> bool: return float(ping.until) > now)
	queue_redraw()


## A teammate (or this player) marked something: `target` is followed while it exists.
func add_ping(peer: int, point: Vector3, target: Node3D, seconds: float) -> void:
	# One ping per miner: a new one replaces their old one.
	_pings = _pings.filter(func(ping: Dictionary) -> bool: return int(ping.peer) != peer)
	_pings.append({"peer": peer, "point": point, "target": target, "until": Time.get_ticks_msec() / 1000.0 + seconds})


func ping_count() -> int:
	return _pings.size()


func _draw() -> void:
	var game: Game = Game.instance
	var me: Player = game.local_player() if game != null else null
	if me == null:
		return
	var font: Font = get_theme_default_font()
	var camera: Camera3D = get_viewport().get_camera_3d()
	var row: int = 0
	for player: Player in game.players():
		if player == me:
			continue
		_draw_mate(font, player, LIST_AT + Vector2(0, ROW * row))
		row += 1
		if player.downed and player.alive and camera != null and game.phase == Game.Phase.SHIFT:
			_draw_downed(font, camera, me, player)
	if camera == null:
		return
	for ping: Dictionary in _pings:
		_draw_ping(font, camera, me, ping)


## One line of the crew list: name and state, health and armour bars, rounds in hand.
func _draw_mate(font: Font, player: Player, at: Vector2) -> void:
	var state: String = ""
	var name_color: Color = TEXT
	if not player.alive:
		state = tr("TEAM_DEAD")
		name_color = DIM
	elif player.downed:
		state = tr("TEAM_DOWNED") % ceili(player.downed_left())
		name_color = DOWNED
	elif player.pinned:
		state = tr("TEAM_PINNED")
		name_color = DOWNED
	var title: String = player.display_name() + ("  " + state if state != "" else "")
	_text(font, title, at + Vector2(0, 14), 16, name_color)
	var bar_at: Vector2 = at + Vector2(0, 20)
	draw_rect(Rect2(bar_at, BAR), Color(0, 0, 0, 0.5))
	var share: float = clampf(float(player.health) / maxf(1.0, player.max_health), 0.0, 1.0) if player.alive else 0.0
	draw_rect(Rect2(bar_at, Vector2(BAR.x * share, BAR.y)), HEALTH)
	draw_rect(Rect2(bar_at, BAR), Color(1, 1, 1, 0.14), false, 1.0)
	var cap: int = player.armour_cap()
	if cap > 0 and player.alive:
		var armour_at: Vector2 = bar_at + Vector2(0, BAR.y + 2)
		draw_rect(Rect2(armour_at, Vector2(BAR.x, 3)), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(armour_at, Vector2(BAR.x * clampf(float(player.armour) / cap, 0.0, 1.0), 3)), ARMOUR)
	# The gun in their hand: magazine / spare.
	var gun: WorldItem = player.inventory.slots[player.inventory.selected] as WorldItem if player.alive else null
	if gun != null and gun.data.weapon != null and not player.inventory.hands_busy():
		_text(font, "%d / %d" % [gun.rounds, player.ammo_count(gun.data.weapon.ammo_type)], bar_at + Vector2(BAR.x + 10, 7), 15, DIM)
	elif player.alive and player.inventory.hands_busy():
		_text(font, tr("TEAM_CARRYING"), bar_at + Vector2(BAR.x + 10, 7), 15, DIM)


## A downed teammate, seen through the rock: a red mark, their name, seconds left, distance.
func _draw_downed(font: Font, camera: Camera3D, me: Player, player: Player) -> void:
	var where: Vector3 = player.global_position + Vector3.UP * 0.6
	var spot: Vector2 = _on_screen(camera, where)
	var blink: float = 0.55 + 0.45 * sin(Time.get_ticks_msec() / 160.0)
	var mark: Color = Color(DOWNED, blink)
	draw_circle(spot, 11.0, Color(0, 0, 0, 0.5))
	draw_rect(Rect2(spot - Vector2(2.5, 8), Vector2(5, 16)), mark)
	draw_rect(Rect2(spot - Vector2(8, 2.5), Vector2(16, 5)), mark)
	var label: String = tr("TEAM_DOWNED_MARK") % [player.display_name(), ceili(player.downed_left()), roundi(me.global_position.distance_to(player.global_position))]
	_text(font, label, spot + Vector2(-90, 30), 15, DOWNED, 180.0)


func _draw_ping(font: Font, camera: Camera3D, me: Player, ping: Dictionary) -> void:
	var target: Node3D = ping.target as Node3D if is_instance_valid(ping.target) else null
	var where: Vector3 = target.global_position + Vector3.UP * 1.0 if target != null else ping.point as Vector3
	var spot: Vector2 = _on_screen(camera, where)
	var color: Color = PING_CREATURE if target is Creature else PING
	var drop: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(-8, -14), Vector2(-7, -21), Vector2(0, -26), Vector2(7, -21), Vector2(8, -14)])
	var shadow: PackedVector2Array = []
	var shape: PackedVector2Array = []
	for point: Vector2 in drop:
		shadow.append(spot + point + Vector2(1.5, 1.5))
		shape.append(spot + point)
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.6))
	draw_colored_polygon(shape, color)
	draw_circle(spot + Vector2(0, -17), 3.0, Color(0, 0, 0, 0.5))
	var who: Player = Game.instance.player_by_peer(int(ping.peer))
	var text: String = "%s  %d m" % [who.display_name() if who != null else "", roundi(me.camera.global_position.distance_to(where))]
	_text(font, text, spot + Vector2(-90, 18), 14, color, 180.0)


## Where `point` shows on screen; points behind the camera or off screen are kept at the edge,
## so a mark always says which way to turn.
func _on_screen(camera: Camera3D, point: Vector3) -> Vector2:
	var view: Rect2 = get_viewport_rect().grow(-40.0)
	var spot: Vector2 = camera.unproject_position(point)
	if camera.is_position_behind(point):
		spot = view.size - spot  # mirrored: behind you shows at the opposite side
		spot.y = view.end.y
	return Vector2(clampf(spot.x, view.position.x, view.end.x), clampf(spot.y, view.position.y, view.end.y))


func _text(font: Font, text: String, at: Vector2, size: int, color: Color, width: float = -1.0) -> void:
	var align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER if width > 0.0 else HORIZONTAL_ALIGNMENT_LEFT
	draw_string_outline(font, at, text, align, width, size, 4, Color(0, 0, 0, 0.8))
	draw_string(font, at, text, align, width, size, color)
