class_name SettingsPanel
extends Control
## The settings page (main menu and Esc menu): tabs for sound, display, graphics and gameplay.
## Every change is applied and saved right away (Settings autoload). Built in code; all texts
## go through tr(). Covers the whole screen and keeps its panel in the middle, whatever the
## window size or mode.

signal closed

const TEXT_COLOR: Color = Color(0.96, 0.9, 0.78)
const DIM_COLOR: Color = Color(0.7, 0.64, 0.55)
const ACCENT: Color = Color(0.86, 0.62, 0.3)

var _tabs: TabContainer
var _panel: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_panel = PanelContainer.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.06, 0.04, 0.94)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", box)
	_panel.custom_minimum_size = Vector2(640, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	centre.add_child(_panel)
	hide()


func open() -> void:
	_rebuild()
	show()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	# In the main menu nobody else closes it on Esc (the HUD does it during a session).
	if visible and event.is_action_pressed(&"pause") and (Game.instance == null or Game.instance.local_player() == null):
		get_viewport().set_input_as_handled()
		close()


func _rebuild() -> void:
	var current_tab: int = _tabs.current_tab if _tabs != null else 0
	for child: Node in _panel.get_children():
		_panel.remove_child(child)
		child.queue_free()
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_panel.add_child(column)
	var title: Label = _label(tr("SETTINGS_TITLE"), 30)
	title.add_theme_color_override("font_color", ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(0, 330)
	column.add_child(_tabs)
	_build_audio(_tab("SETTINGS_AUDIO"))
	_build_display(_tab("SETTINGS_DISPLAY"))
	_build_graphics(_tab("SETTINGS_GRAPHICS"))
	_build_gameplay(_tab("SETTINGS_GAMEPLAY"))
	_tabs.current_tab = clampi(current_tab, 0, _tabs.get_tab_count() - 1)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	buttons.add_child(_button(tr("SET_DEFAULTS"), func() -> void:
		Settings.reset_to_defaults()
		_rebuild()))
	buttons.add_child(_button(tr("PANEL_CLOSE"), close))


func _tab(title_key: String) -> GridContainer:
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 10)
	margin.add_child(grid)
	_tabs.add_child(margin)
	_tabs.set_tab_title(_tabs.get_tab_count() - 1, tr(title_key))
	return grid


# --- tabs -------------------------------------------------------------------------------------------

func _build_audio(grid: GridContainer) -> void:
	var data: SettingsData = Settings.data
	_slider(grid, "SET_MASTER", data.master_volume, 0.0, 1.0, 0.05, true, func(v: float) -> void: data.master_volume = v)
	_slider(grid, "SET_MUSIC", data.music_volume, 0.0, 1.0, 0.05, true, func(v: float) -> void: data.music_volume = v)
	_slider(grid, "SET_EFFECTS", data.effects_volume, 0.0, 1.0, 0.05, true, func(v: float) -> void: data.effects_volume = v)
	_slider(grid, "SET_VOICE", data.voice_volume, 0.0, 1.0, 0.05, true, func(v: float) -> void: data.voice_volume = v)
	_check(grid, "SET_CREATURE_LINES", data.creature_lines, func(on: bool) -> void: data.creature_lines = on)
	_check(grid, "SET_OPEN_MIC", data.voice_open_mic, func(on: bool) -> void: data.voice_open_mic = on)
	_check(grid, "SET_VOICE_LURE", data.voice_lure, func(on: bool) -> void: data.voice_lure = on)


func _build_display(grid: GridContainer) -> void:
	var data: SettingsData = Settings.data
	_option(grid, "SET_WINDOW_MODE", ["SET_WINDOWED", "SET_BORDERLESS", "SET_FULLSCREEN"], data.window_mode,
			func(i: int) -> void: data.window_mode = i as SettingsData.WindowMode)
	_check(grid, "SET_VSYNC", data.vsync, func(on: bool) -> void: data.vsync = on)
	var fps_names: Array[String] = []
	for limit: int in SettingsData.FPS_LIMITS:
		fps_names.append(tr("SET_FPS_UNLIMITED") if limit == 0 else str(limit))
	_option(grid, "SET_FPS", fps_names, SettingsData.FPS_LIMITS.find(data.fps_limit),
			func(i: int) -> void: data.fps_limit = SettingsData.FPS_LIMITS[i])
	_slider(grid, "SET_FOV", data.fov, SettingsData.FOV_MIN, SettingsData.FOV_MAX, 1.0, false, func(v: float) -> void: data.fov = v)
	_slider(grid, "SET_BRIGHTNESS", data.brightness, 0.5, 1.6, 0.05, true, func(v: float) -> void: data.brightness = v)


func _build_graphics(grid: GridContainer) -> void:
	var data: SettingsData = Settings.data
	_option(grid, "SET_QUALITY", ["SET_Q_LOW", "SET_Q_MEDIUM", "SET_Q_HIGH", "SET_Q_ULTRA"], data.quality,
			func(i: int) -> void: data.quality = i as SettingsData.Quality)
	_check(grid, "SET_AUTO_RESOLUTION", data.auto_resolution, func(on: bool) -> void:
		data.auto_resolution = on
		_rebuild.call_deferred())
	if not data.auto_resolution:
		_slider(grid, "SET_RENDER_SCALE", data.render_scale, 0.5, 1.0, 0.05, true, func(v: float) -> void: data.render_scale = v)
	_check(grid, "SET_FOG", data.volumetric_fog, func(on: bool) -> void: data.volumetric_fog = on)
	_option(grid, "SET_AA", ["SET_AA_OFF", "SET_AA_FXAA", "SET_AA_TAA", "SET_AA_MSAA"], data.anti_aliasing,
			func(i: int) -> void: data.anti_aliasing = i as SettingsData.AntiAliasing)


func _build_gameplay(grid: GridContainer) -> void:
	var data: SettingsData = Settings.data
	_slider(grid, "SET_SENSITIVITY", data.mouse_sensitivity, SettingsData.SENSITIVITY_MIN, SettingsData.SENSITIVITY_MAX, 0.05, false,
			func(v: float) -> void: data.mouse_sensitivity = v)
	_check(grid, "SET_INVERT_Y", data.invert_y, func(on: bool) -> void: data.invert_y = on)
	_check(grid, "SET_HEAD_BOB", data.head_bob, func(on: bool) -> void: data.head_bob = on)


# --- rows -------------------------------------------------------------------------------------------

func _slider(grid: GridContainer, key: String, value: float, min_value: float, max_value: float, step: float,
		percent: bool, setter: Callable) -> void:
	grid.add_child(_label(tr(key), 17))
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var slider: HSlider = HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(220, 24)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var shown: Label = _label(_slider_text(value, percent), 16)
	shown.custom_minimum_size = Vector2(56, 0)
	shown.add_theme_color_override("font_color", DIM_COLOR)
	slider.value_changed.connect(func(v: float) -> void:
		shown.text = _slider_text(v, percent)
		setter.call(v)
		Settings.apply())
	row.add_child(slider)
	row.add_child(shown)
	grid.add_child(row)


func _slider_text(value: float, percent: bool) -> String:
	return "%d %%" % roundi(value * 100.0) if percent else ("%.2f" % value if value < 10.0 else "%d" % roundi(value))


func _check(grid: GridContainer, key: String, value: bool, setter: Callable) -> void:
	grid.add_child(_label(tr(key), 17))
	var check: CheckBox = CheckBox.new()
	check.button_pressed = value
	check.toggled.connect(func(on: bool) -> void:
		setter.call(on)
		Settings.apply())
	grid.add_child(check)


func _option(grid: GridContainer, key: String, item_keys: Array, selected: int, setter: Callable) -> void:
	grid.add_child(_label(tr(key), 17))
	var option: OptionButton = OptionButton.new()
	for item_key: Variant in item_keys:
		option.add_item(tr(str(item_key)))
	option.select(maxi(0, selected))
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.item_selected.connect(func(i: int) -> void:
		setter.call(i)
		Settings.apply())
	grid.add_child(option)


func _button(text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(160, 40)
	button.pressed.connect(action)
	return button


func _label(text: String, size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label
