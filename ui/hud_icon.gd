class_name HudIcon
extends Control
## Small vector icons for the HUD, drawn in code (no image files): a cross for health, a flame
## for the lamp, chevrons for breath, a cartridge and a shotgun shell for ammo.

enum Kind { HEALTH, LAMP, STAMINA, BULLET, SHELL }

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
