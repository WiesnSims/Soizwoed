class_name Hotbar
extends VBoxContainer
## The pocket bar at the bottom of the screen, like in other shooters: one square per slot
## with the item's icon, its key, and the magazine count on guns; weapons (1–3), the
## throwable (4) and the pockets (5–9) in three groups. The selected slot is lit, and its
## name shows for a moment when it changes.

const CELL: float = 64.0
const FRAME: Color = Color(0.06, 0.05, 0.04, 0.62)
const FRAME_SELECTED: Color = Color(0.16, 0.12, 0.07, 0.85)
const BORDER: Color = Color(0.5, 0.42, 0.3, 0.55)
const BORDER_SELECTED: Color = Color(0.95, 0.72, 0.38, 1.0)
const NAME_SECONDS: float = 1.6

var icons: ItemIcons

var _cells: Array[PanelContainer] = []
var _pictures: Array[TextureRect] = []
var _names: Array[Label] = []
var _counts: Array[Label] = []
var _styles: Array[StyleBoxFlat] = []
var _selected_name: Label
var _last_selected: int = -1
var _last_item: Object
var _name_left: float = 0.0


func build(kinds: PackedInt32Array) -> void:
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selected_name = _label("", 18, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_selected_name)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for i: int in kinds.size():
		if i > 0 and kinds[i] != kinds[i - 1]:
			var gap: Control = Control.new()
			gap.custom_minimum_size = Vector2(14, 0)
			row.add_child(gap)
		row.add_child(_cell(i))


func _cell(index: int) -> PanelContainer:
	var cell: PanelContainer = PanelContainer.new()
	cell.custom_minimum_size = Vector2(CELL, CELL)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = FRAME
	style.border_color = BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(3)
	cell.add_theme_stylebox_override("panel", style)
	var stack: Control = Control.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(stack)
	var picture: TextureRect = TextureRect.new()
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(picture)
	var item_name: Label = _label("", 10, HORIZONTAL_ALIGNMENT_CENTER)
	item_name.set_anchors_preset(Control.PRESET_FULL_RECT)
	item_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_name.clip_text = true
	stack.add_child(item_name)
	# The extra pockets sit on keys 0 and ß by default (rebindable).
	var key: Label = _label(str(index + 1) if index < 9 else Settings.key_label(StringName("slot_%d" % (index + 1))), 12, HORIZONTAL_ALIGNMENT_LEFT)
	key.position = Vector2(2, -2)
	key.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7, 0.8))
	stack.add_child(key)
	var count: Label = _label("", 13, HORIZONTAL_ALIGNMENT_RIGHT)
	count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count.position = Vector2(-30, -18)
	count.size = Vector2(28, 18)
	stack.add_child(count)
	_cells.append(cell)
	_pictures.append(picture)
	_names.append(item_name)
	_counts.append(count)
	_styles.append(style)
	return cell


func refresh(player: Player, delta: float) -> void:
	var inventory: Inventory = player.inventory
	for i: int in _cells.size():
		var item: WorldItem = inventory.slots[i] as WorldItem if i < inventory.slots.size() else null
		var picture: Texture2D = icons.icon(item.data) if item != null and icons != null else null
		_pictures[i].texture = picture
		_names[i].text = item.display_name() if item != null and picture == null else ""
		_counts[i].text = str(item.rounds) if item != null and item.data.weapon != null else ""
		_cells[i].visible = i < inventory.open_slots  # locked extra pockets are not shown
		var selected: bool = i == inventory.selected and not inventory.hands_busy()
		_styles[i].bg_color = FRAME_SELECTED if selected else FRAME
		_styles[i].border_color = BORDER_SELECTED if selected else BORDER
		_cells[i].modulate.a = 1.0 if selected or item != null else 0.6
	# The name of what is in hand, for a moment after switching.
	var current: Object = inventory.slots[inventory.selected]
	if inventory.selected != _last_selected or current != _last_item:
		_last_selected = inventory.selected
		_last_item = current
		_name_left = NAME_SECONDS
		_selected_name.text = (current as WorldItem).display_name() if current != null else ""
	_name_left = maxf(0.0, _name_left - delta)
	_selected_name.modulate.a = clampf(_name_left / 0.4, 0.0, 1.0)


func _label(text: String, size: int, align: HorizontalAlignment) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.78))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
