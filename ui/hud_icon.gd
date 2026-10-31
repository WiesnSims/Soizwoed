class_name HudIcon
extends Control
## Small vector icons for the HUD, drawn in code (no image files): a cross for health, a flame
## for the lamp, chevrons for breath, a cartridge, a shotgun shell, a rifle round and a flare
## for ammo; for the shop's
## shelves a pistol, a cartridge, a bomb, a bottle and a pick; a coin for money; a shield for
## armour and the upgrades shelf; an Ehrenzeichen, a pouch and a hat for the Knappenbrief; a
## marker drop for pings.

enum Kind { HEALTH, LAMP, STAMINA, BULLET, SHELL, GUN, BOMB, BOTTLE, PICK, COIN, ARMOUR, RIFLE, FLARE, MEDAL, POCKET, HAT, PING }

@export var kind: Kind = Kind.HEALTH
@export var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()


func _init(icon_kind: Kind = Kind.HEALTH, icon_color: Color = Color.WHITE, side: float = 22.0) -> void:
	kind = icon_kind
	color = icon_color
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s: Vector2 = size
	var shadow: Color = Color(0, 0, 0, 0.6)
	match kind:
		Kind.HEALTH:
			var bar: float = s.x * 0.3
			for offset: Vector2 in [Vector2(1.5, 1.5), Vector2.ZERO]:
				var tint: Color = shadow if offset != Vector2.ZERO else color
				draw_rect(Rect2(Vector2((s.x - bar) / 2.0, s.y * 0.1) + offset, Vector2(bar, s.y * 0.8)), tint)
				draw_rect(Rect2(Vector2(s.x * 0.1, (s.y - bar) / 2.0) + offset, Vector2(s.x * 0.8, bar)), tint)
		Kind.LAMP:
			var flame: PackedVector2Array = []
			for i: int in 24:
				var a: float = TAU * i / 24.0
				var r: float = s.x * 0.28
				# A drop: round at the bottom, pointed at the top.
				var stretch: float = 1.0 + maxf(0.0, -sin(a)) * 1.3
				flame.append(Vector2(s.x / 2.0 + cos(a) * r * (1.0 - maxf(0.0, -sin(a)) * 0.55), s.y * 0.66 + sin(a) * r * stretch))
			draw_colored_polygon(flame, color)
			draw_circle(Vector2(s.x / 2.0, s.y * 0.7), s.x * 0.1, Color(1, 1, 1, 0.8))
		Kind.STAMINA:
			for i: int in 3:
				var x: float = s.x * (0.15 + i * 0.25)
				draw_polyline(PackedVector2Array([Vector2(x, s.y * 0.2), Vector2(x + s.x * 0.22, s.y * 0.5), Vector2(x, s.y * 0.8)]), color, maxf(2.0, s.x * 0.1))
		Kind.BULLET:
			var w: float = s.x * 0.36
			var x0: float = (s.x - w) / 2.0
			draw_rect(Rect2(Vector2(x0, s.y * 0.42), Vector2(w, s.y * 0.5)), Color(0.85, 0.65, 0.3))
			draw_colored_polygon(PackedVector2Array([Vector2(x0, s.y * 0.42), Vector2(x0 + w, s.y * 0.42), Vector2(x0 + w * 0.8, s.y * 0.18),
					Vector2(s.x / 2.0, s.y * 0.06), Vector2(x0 + w * 0.2, s.y * 0.18)]), Color(0.75, 0.5, 0.3))
		Kind.SHELL:
			var w2: float = s.x * 0.44
			var x1: float = (s.x - w2) / 2.0
			draw_rect(Rect2(Vector2(x1, s.y * 0.08), Vector2(w2, s.y * 0.66)), Color(0.7, 0.12, 0.1))
			draw_rect(Rect2(Vector2(x1 - 1.0, s.y * 0.72), Vector2(w2 + 2.0, s.y * 0.2)), Color(0.85, 0.65, 0.3))
		Kind.GUN:
			# A pistol from the side, muzzle left.
			var gun: PackedVector2Array = PackedVector2Array([Vector2(0.06, 0.28), Vector2(0.92, 0.28), Vector2(0.92, 0.46), Vector2(0.8, 0.46),
					Vector2(0.9, 0.86), Vector2(0.66, 0.9), Vector2(0.58, 0.56), Vector2(0.46, 0.56), Vector2(0.4, 0.68), Vector2(0.32, 0.68),
					Vector2(0.34, 0.46), Vector2(0.06, 0.46)])
			_polygon(gun, s, shadow, color)
		Kind.BOMB:
			for offset: Vector2 in [Vector2(1.5, 1.5), Vector2.ZERO]:
				draw_circle(Vector2(s.x * 0.44, s.y * 0.6) + offset, s.x * 0.32, shadow if offset != Vector2.ZERO else color)
			draw_line(Vector2(s.x * 0.62, s.y * 0.34), Vector2(s.x * 0.78, s.y * 0.16), color, maxf(2.0, s.x * 0.07))
			draw_circle(Vector2(s.x * 0.82, s.y * 0.12), s.x * 0.08, Color(1.0, 0.75, 0.3))
		Kind.BOTTLE:
			var bottle: PackedVector2Array = PackedVector2Array([Vector2(0.42, 0.06), Vector2(0.58, 0.06), Vector2(0.58, 0.32), Vector2(0.72, 0.44),
					Vector2(0.72, 0.94), Vector2(0.28, 0.94), Vector2(0.28, 0.44), Vector2(0.42, 0.32)])
			_polygon(bottle, s, shadow, color)
		Kind.PICK:
			var width: float = maxf(2.0, s.x * 0.1)
			for offset: Vector2 in [Vector2(1.5, 1.5), Vector2.ZERO]:
				var tint: Color = shadow if offset != Vector2.ZERO else color
				draw_line(Vector2(s.x * 0.18, s.y * 0.9) + offset, Vector2(s.x * 0.64, s.y * 0.3) + offset, tint, width)
				draw_polyline(PackedVector2Array([Vector2(s.x * 0.22, s.y * 0.22), Vector2(s.x * 0.48, s.y * 0.12), Vector2(s.x * 0.66, s.y * 0.2),
						Vector2(s.x * 0.84, s.y * 0.38), Vector2(s.x * 0.92, s.y * 0.66)]), tint, width * 0.9)
		Kind.COIN:
			draw_circle(s / 2.0 + Vector2(1.5, 1.5), s.x * 0.42, shadow)
			draw_circle(s / 2.0, s.x * 0.42, Color(0.86, 0.66, 0.3))
			draw_arc(s / 2.0, s.x * 0.3, 0.0, TAU, 24, Color(0.6, 0.42, 0.15), maxf(1.0, s.x * 0.06))
		Kind.RIFLE:
			# A long, slim rifle round with a bottleneck.
			var w3: float = s.x * 0.26
			var x3: float = (s.x - w3) / 2.0
			draw_rect(Rect2(Vector2(x3, s.y * 0.36), Vector2(w3, s.y * 0.58)), Color(0.85, 0.65, 0.3))
			draw_colored_polygon(PackedVector2Array([Vector2(x3, s.y * 0.36), Vector2(x3 + w3, s.y * 0.36), Vector2(x3 + w3 * 0.72, s.y * 0.26),
					Vector2(x3 + w3 * 0.66, s.y * 0.14), Vector2(s.x / 2.0, s.y * 0.02), Vector2(x3 + w3 * 0.34, s.y * 0.14), Vector2(x3 + w3 * 0.28, s.y * 0.26)]), Color(0.72, 0.45, 0.28))
		Kind.FLARE:
			var w4: float = s.x * 0.5
			var x4: float = (s.x - w4) / 2.0
			draw_rect(Rect2(Vector2(x4, s.y * 0.26), Vector2(w4, s.y * 0.6)), Color(0.75, 0.75, 0.72))
			draw_rect(Rect2(Vector2(x4, s.y * 0.1), Vector2(w4, s.y * 0.18)), Color(0.85, 0.12, 0.08))
			draw_rect(Rect2(Vector2(x4 - 1.0, s.y * 0.84), Vector2(w4 + 2.0, s.y * 0.1)), Color(0.55, 0.55, 0.52))
		Kind.ARMOUR:
			var shield: PackedVector2Array = PackedVector2Array([Vector2(0.5, 0.06), Vector2(0.88, 0.2), Vector2(0.84, 0.56), Vector2(0.5, 0.94),
					Vector2(0.16, 0.56), Vector2(0.12, 0.2)])
			_polygon(shield, s, shadow, color)
			draw_line(Vector2(s.x * 0.5, s.y * 0.2), Vector2(s.x * 0.5, s.y * 0.78), Color(0, 0, 0, 0.35), maxf(1.0, s.x * 0.06))
		Kind.MEDAL:
			# An Ehrenzeichen: red-white-red ribbon above a gold star with hammer and pick.
			_polygon(PackedVector2Array([Vector2(0.3, 0.02), Vector2(0.7, 0.02), Vector2(0.62, 0.36), Vector2(0.38, 0.36)]), s, shadow, Color(0.8, 0.14, 0.12))
			draw_rect(Rect2(Vector2(s.x * 0.44, s.y * 0.02), Vector2(s.x * 0.12, s.y * 0.34)), Color(0.95, 0.93, 0.9))
			var star: PackedVector2Array = []
			for i: int in 16:
				var a: float = TAU * i / 16.0 - PI / 2.0
				var r: float = 0.3 if i % 2 == 0 else 0.17
				star.append(Vector2(0.5, 0.64) + Vector2(cos(a), sin(a)) * r)
			_polygon(star, s, shadow, Color(0.9, 0.7, 0.28))
			draw_circle(Vector2(s.x * 0.5, s.y * 0.64), s.x * 0.09, Color(0.55, 0.38, 0.12))
		Kind.POCKET:
			# A leather pouch with a flap.
			_polygon(PackedVector2Array([Vector2(0.14, 0.3), Vector2(0.86, 0.3), Vector2(0.82, 0.9), Vector2(0.18, 0.9)]), s, shadow, color)
			draw_colored_polygon(PackedVector2Array([Vector2(s.x * 0.12, s.y * 0.26), Vector2(s.x * 0.88, s.y * 0.26), Vector2(s.x * 0.5, s.y * 0.56)]), color.darkened(0.35))
			draw_circle(Vector2(s.x * 0.5, s.y * 0.5), s.x * 0.05, Color(0.85, 0.7, 0.3))
		Kind.HAT:
			_polygon(PackedVector2Array([Vector2(0.06, 0.72), Vector2(0.94, 0.72), Vector2(0.86, 0.82), Vector2(0.14, 0.82)]), s, shadow, color)
			_polygon(PackedVector2Array([Vector2(0.26, 0.72), Vector2(0.32, 0.3), Vector2(0.5, 0.22), Vector2(0.68, 0.3), Vector2(0.74, 0.72)]), s, shadow, color)
			draw_line(Vector2(s.x * 0.62, s.y * 0.34), Vector2(s.x * 0.86, s.y * 0.04), Color(0.82, 0.8, 0.74), maxf(1.0, s.x * 0.07))
		Kind.PING:
			# A marker drop pointing down at the spot.
			_polygon(PackedVector2Array([Vector2(0.5, 0.96), Vector2(0.2, 0.46), Vector2(0.24, 0.22), Vector2(0.5, 0.06), Vector2(0.76, 0.22), Vector2(0.8, 0.46)]), s, shadow, color)
			draw_circle(Vector2(s.x * 0.5, s.y * 0.36), s.x * 0.12, Color(0, 0, 0, 0.45))


## The icon of an ammo type's counter.
static func ammo_kind(ammo_type: StringName) -> Kind:
	match ammo_type:
		&"schrot":
			return Kind.SHELL
		&"gewehr":
			return Kind.RIFLE
		&"leucht":
			return Kind.FLARE
	return Kind.BULLET


## A shape given in 0..1 of the icon, with a drop shadow.
func _polygon(points: PackedVector2Array, s: Vector2, shadow: Color, tint: Color) -> void:
	var scaled: PackedVector2Array = []
	for point: Vector2 in points:
		scaled.append(point * s)
	var moved: PackedVector2Array = []
	for point: Vector2 in scaled:
		moved.append(point + Vector2(1.5, 1.5))
	draw_colored_polygon(moved, shadow)
	draw_colored_polygon(scaled, tint)
