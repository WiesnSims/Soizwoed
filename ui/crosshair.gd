class_name Crosshair
extends Control
## A modern crosshair: a small dot and four short ticks that open up with the gun's spread
## (moving, from the hip) and close in when steady. No hit marker (owner decision): whether a
## shot hit shows on the creature, not here. Hidden while aiming down the sights.

## Gap from the centre to the ticks (px).
var gap: float = 6.0:
	set(value):
		if absf(value - gap) > 0.2:
			gap = value
			queue_redraw()
## Only the dot (no gun in hand).
var dot_only: bool = true:
	set(value):
		if value != dot_only:
			dot_only = value
			queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER)
	size = Vector2.ZERO


func _draw() -> void:
	var white: Color = Color(1, 1, 1, 0.75)
	var shadow: Color = Color(0, 0, 0, 0.55)
	draw_circle(Vector2.ZERO, 2.2, shadow)
	draw_circle(Vector2.ZERO, 1.4, white)
	if dot_only:
		return
	var tick: float = 7.0
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var from: Vector2 = direction * gap
		var to: Vector2 = direction * (gap + tick)
		draw_line(from, to, shadow, 3.5)
		draw_line(from, to, white, 1.6)
