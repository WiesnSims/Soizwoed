extends Node
## Owns the player's settings (SettingsData): loads them from user://settings.cfg at start,
## applies them to the audio buses, the window, the renderer and the environments, and saves
## them whenever they change. The player reads mouse, FOV and head bob from `data`.
## Automated runs (headless, or --shots windows) never get their window changed.

signal changed

const PATH: String = "user://settings.cfg"
const ENVIRONMENTS: Array[String] = ["res://world/mine_environment.tres", "res://hub/hub_environment.tres"]

var data: SettingsData = SettingsData.new()

## The environments' tuned exposure and SSAO/SSIL switches, before any settings.
var _base: Dictionary = {}  # Environment -> Dictionary


func _ready() -> void:
	var file: ConfigFile = ConfigFile.new()
	if file.load(PATH) == OK:
		data.load_from(file)
	for path: String in ENVIRONMENTS:
		var env: Environment = load(path) as Environment
		_base[env] = {"exposure": env.tonemap_exposure, "ssao": env.ssao_enabled, "ssil": env.ssil_enabled, "fog": env.volumetric_fog_enabled}
	apply()


## Applies the current values and saves them.
func apply() -> void:
	data.clamp_all()
	_apply_audio()
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
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if data.render_scale < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = data.render_scale
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
