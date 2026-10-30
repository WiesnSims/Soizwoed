extends Node
## Owns the player's settings (SettingsData): loads them from user://settings.cfg at start,
## applies them to the audio buses, the window, the renderer and the environments, and saves
## them whenever they change. The player reads mouse, FOV and head bob from `data`.
## Automated runs (headless, or --shots windows) never get their window changed.

signal changed

const PATH: String = "user://settings.cfg"
const ENVIRONMENTS: Array[String] = ["res://world/mine_environment.tres", "res://hub/hub_environment.tres"]

var data: SettingsData = SettingsData.new()
## Lamps and lanterns farther than this from the camera stop casting shadows (quality preset).
var shadow_distance: float = 24.0

## The environments' tuned exposure and SSAO/SSIL switches, before any settings.
var _base: Dictionary = {}  # Environment -> Dictionary
## The keys from project.godot, before any rebinding: action -> Array[InputEvent].
var _default_events: Dictionary = {}


func _ready() -> void:
	for action: StringName in SettingsData.REBINDABLE:
		_default_events[action] = InputMap.action_get_events(action)
	var file: ConfigFile = ConfigFile.new()
	if file.load(PATH) == OK:
		data.load_from(file)
	for path: String in ENVIRONMENTS:
		var env: Environment = load(path) as Environment
		_base[env] = {"exposure": env.tonemap_exposure, "ssao": env.ssao_enabled, "ssil": env.ssil_enabled, "fog": env.volumetric_fog_enabled, "ssr": env.ssr_enabled}
	apply()
	# Automatic resolution follows the window (fullscreen, resizing).
	get_tree().root.size_changed.connect(_apply_graphics)


## Applies the current values and saves them.
func apply() -> void:
	data.clamp_all()
	_apply_audio()
	_apply_language()
	_apply_keys()
	if _may_touch_window():
		_apply_display()
	_apply_graphics()
	save()
	changed.emit()


func save() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.load(PATH)  # keeps sections other code may have written
	data.save_to(file)
	file.save(PATH)


func reset_to_defaults() -> void:
	data = SettingsData.new()
	apply()


func reset_keys() -> void:
	data.key_bindings = {}
	apply()


## The language picked, or the system's (German for German systems, English otherwise).
func locale() -> String:
	if data.language != "":
		return data.language
	return "de" if OS.get_locale_language() == "de" else "en"


func _apply_language() -> void:
	if TranslationServer.get_locale() != locale():
		TranslationServer.set_locale(locale())


func _apply_keys() -> void:
	for action: StringName in SettingsData.REBINDABLE:
		InputMap.action_erase_events(action)
		if data.key_bindings.has(String(action)):
			InputMap.action_add_event(action, SettingsData.event_for(int(data.key_bindings[String(action)])))
		else:
			for event: InputEvent in _default_events.get(action, []):
				InputMap.action_add_event(action, event)


## The code (SettingsData.event_code) of the first key on every rebindable action right now.
func current_codes() -> Dictionary:
	var codes: Dictionary = {}
	for action: StringName in SettingsData.REBINDABLE:
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		codes[action] = SettingsData.event_code(events[0]) if not events.is_empty() else 0
	return codes


## How the key of `action` is called on this keyboard ("E", "Linksklick", ...).
func key_label(action: StringName) -> String:
	var events: Array[InputEvent] = InputMap.action_get_events(action) if InputMap.has_action(action) else []
	return code_label(SettingsData.event_code(events[0])) if not events.is_empty() else tr("KEY_NONE")


func code_label(code: int) -> String:
	if code < 0:
		return tr("KEY_MOUSE_%d" % -code) if -code <= 5 else "M%d" % -code
	if code == 0:
		return tr("KEY_NONE")
	# The key's name on this keyboard's layout (a headless run has no keyboard to ask).
	var on_layout: Key = KEY_NONE if DisplayServer.get_name() == "headless" else DisplayServer.keyboard_get_keycode_from_physical(code as Key)
	return OS.get_keycode_string(on_layout if on_layout != KEY_NONE else code as Key)


func _may_touch_window() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			return false
	return true


func _apply_audio() -> void:
	_set_bus(&"Master", data.master_volume)
	_set_bus(&"Music", data.music_volume)
	for bus_name: StringName in [&"SFX", &"Creatures", &"Ambience"]:
		_set_bus(bus_name, data.effects_volume)
	_set_bus(&"Voice", data.voice_volume)
	Audio.creature_lines_enabled = data.creature_lines
	Audio.voice_open_mic = data.voice_open_mic
	# A device that is gone (unplugged headset) falls back to the default.
	var output: String = data.output_device if data.output_device in AudioServer.get_output_device_list() else "Default"
	if AudioServer.output_device != output:
		AudioServer.output_device = output
	var input: String = data.input_device if data.input_device in AudioServer.get_input_device_list() else "Default"
	if AudioServer.input_device != input:
		AudioServer.input_device = input


func _set_bus(bus_name: StringName, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, SettingsData.volume_db(linear))


func _apply_display() -> void:
	var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED
	match data.window_mode:
		SettingsData.WindowMode.BORDERLESS:
			mode = DisplayServer.WINDOW_MODE_FULLSCREEN
		SettingsData.WindowMode.FULLSCREEN:
			mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if data.vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = data.fps_limit


func _apply_graphics() -> void:
	var values: Dictionary = SettingsData.quality_values(data.quality)
	var root: Viewport = get_tree().root
	root.positional_shadow_atlas_size = int(values.shadow_atlas)
	RenderingServer.positional_soft_shadow_filter_set_quality(int(values.soft_shadows) as RenderingServer.ShadowQuality)
	RenderingServer.environment_set_ssao_quality(int(values.ssao_quality) as RenderingServer.EnvironmentSSAOQuality, true, 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_ssil_quality(int(values.ssil_quality) as RenderingServer.EnvironmentSSILQuality, true, 0.5, 4, 50.0, 300.0)
	RenderingServer.environment_set_volumetric_fog_volume_size(int(values.fog_size), int(values.fog_depth))
	for env: Environment in _base:
		var base: Dictionary = _base[env]
		env.tonemap_exposure = float(base.exposure) * data.brightness
		env.ssao_enabled = bool(base.ssao) and bool(values.ssao)
		env.ssil_enabled = bool(base.ssil) and bool(values.ssil)
		env.volumetric_fog_enabled = bool(base.fog) and data.volumetric_fog
		env.ssr_enabled = bool(base.ssr) and bool(values.ssr)
		env.ssr_max_steps = maxi(1, int(values.ssr_steps))
	shadow_distance = float(values.shadow_distance)
	var scale: float = data.effective_render_scale(root.size.y)
	root.scaling_3d_scale = scale
	if scale < 0.99:
		# FSR 2 upscales with its own temporal anti-aliasing: nothing else on top.
		root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		_set_aa(root, Viewport.MSAA_DISABLED, Viewport.SCREEN_SPACE_AA_DISABLED, false)
		return
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	match data.anti_aliasing:
		SettingsData.AntiAliasing.OFF:
			_set_aa(root, Viewport.MSAA_DISABLED, Viewport.SCREEN_SPACE_AA_DISABLED, false)
		SettingsData.AntiAliasing.FXAA:
			_set_aa(root, Viewport.MSAA_DISABLED, Viewport.SCREEN_SPACE_AA_FXAA, false)
		SettingsData.AntiAliasing.TAA:
			_set_aa(root, Viewport.MSAA_DISABLED, Viewport.SCREEN_SPACE_AA_DISABLED, true)
		_:
			_set_aa(root, Viewport.MSAA_2X, Viewport.SCREEN_SPACE_AA_FXAA, true)


func _set_aa(root: Viewport, msaa: Viewport.MSAA, screen_space: Viewport.ScreenSpaceAA, taa: bool) -> void:
	root.msaa_3d = msaa
	root.screen_space_aa = screen_space
	root.use_taa = taa
