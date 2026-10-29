extends GutTest
## Player settings: defaults, limits, saving and loading (pure SettingsData, no window needed).


func test_defaults_are_the_tuned_look_at_a_sane_cost() -> void:
	var data: SettingsData = SettingsData.new()
	assert_eq(data.quality, SettingsData.Quality.HIGH)
	assert_eq(data.anti_aliasing, SettingsData.AntiAliasing.TAA)
	assert_eq(data.fps_limit, 60)
	assert_false(data.auto_resolution, "native 3D resolution unless FSR 2 is chosen")
	assert_eq(data.fov, 78.0)
	assert_true(data.creature_lines, "Gegner reden is on by default (DESIGN.md §6)")
	var high: Dictionary = SettingsData.quality_values(SettingsData.Quality.HIGH)
	assert_eq(int(high.shadow_atlas), 4096)
	assert_true(bool(high.ssr))
	assert_false(bool(SettingsData.quality_values(SettingsData.Quality.LOW).ssr))


func test_save_and_load_round_trip() -> void:
	var data: SettingsData = SettingsData.new()
	data.master_volume = 0.3
	data.window_mode = SettingsData.WindowMode.FULLSCREEN
	data.fps_limit = 144
	data.quality = SettingsData.Quality.LOW
	data.mouse_sensitivity = 1.7
	data.invert_y = true
	data.voice_open_mic = true
	var file: ConfigFile = ConfigFile.new()
	data.save_to(file)
	var loaded: SettingsData = SettingsData.new()
	loaded.load_from(file)
	assert_almost_eq(loaded.master_volume, 0.3, 0.0001)
	assert_eq(loaded.window_mode, SettingsData.WindowMode.FULLSCREEN)
	assert_eq(loaded.fps_limit, 144)
	assert_eq(loaded.quality, SettingsData.Quality.LOW)
	assert_almost_eq(loaded.mouse_sensitivity, 1.7, 0.0001)
	assert_true(loaded.invert_y)
	assert_true(loaded.voice_open_mic)


func test_old_settings_file_keeps_defaults() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("voice", "open_mic", true)  # all an M3 settings file had
	var data: SettingsData = SettingsData.new()
	data.load_from(file)
	assert_true(data.voice_open_mic)
	assert_eq(data.master_volume, 1.0)
	assert_eq(data.quality, SettingsData.Quality.HIGH)


func test_bad_values_are_clamped() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("audio", "master", 7.0)
	file.set_value("display", "fps_limit", 77)
	file.set_value("display", "fov", 200.0)
	file.set_value("graphics", "quality", 9)
	file.set_value("gameplay", "mouse_sensitivity", -1.0)
	var data: SettingsData = SettingsData.new()
	data.load_from(file)
	assert_eq(data.master_volume, 1.0)
	assert_eq(data.fps_limit, SettingsData.DEFAULT_FPS_LIMIT)
	assert_eq(data.fov, SettingsData.FOV_MAX)
	assert_eq(data.quality, SettingsData.Quality.ULTRA)
	assert_eq(data.mouse_sensitivity, SettingsData.SENSITIVITY_MIN)


func test_volume_zero_is_silent() -> void:
	assert_eq(SettingsData.volume_db(0.0), -80.0)
	assert_almost_eq(SettingsData.volume_db(1.0), 0.0, 0.001)


func test_settings_texts_are_translated() -> void:
	for key: String in ["MENU_SETTINGS", "SETTINGS_AUDIO", "SETTINGS_DISPLAY", "SETTINGS_GRAPHICS", "SETTINGS_GAMEPLAY", "SET_CREATURE_LINES", "INVITE_TITLE"]:
		assert_ne(tr(key), key, "no text for %s" % key)


func test_old_heavy_defaults_move_to_the_new_ones() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("display", "fps_limit", 0)
	file.set_value("graphics", "anti_aliasing", SettingsData.AntiAliasing.MSAA_TAA)
	var data: SettingsData = SettingsData.new()
	data.load_from(file)
	assert_eq(data.fps_limit, SettingsData.DEFAULT_FPS_LIMIT)
	assert_eq(data.anti_aliasing, SettingsData.AntiAliasing.TAA)


func test_new_files_keep_an_unlimited_frame_rate() -> void:
	var data: SettingsData = SettingsData.new()
	data.fps_limit = 0
	var file: ConfigFile = ConfigFile.new()
	data.save_to(file)
	var loaded: SettingsData = SettingsData.new()
	loaded.load_from(file)
	assert_eq(loaded.fps_limit, 0)


func test_auto_resolution_renders_at_most_1080p() -> void:
	var data: SettingsData = SettingsData.new()
	assert_eq(data.effective_render_scale(2160), 1.0, "native by default")
	data.auto_resolution = true
	assert_eq(data.effective_render_scale(1080), 1.0)
	assert_eq(data.effective_render_scale(720), 1.0)
	assert_almost_eq(data.effective_render_scale(1440), 0.75, 0.001)
	assert_almost_eq(data.effective_render_scale(2160), 0.5, 0.001)
	data.auto_resolution = false
	data.render_scale = 0.8
	assert_almost_eq(data.effective_render_scale(2160), 0.8, 0.001)


func test_fsr_default_of_version_2_goes_back_to_native() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("meta", "version", 2)
	file.set_value("graphics", "auto_resolution", true)
	var data: SettingsData = SettingsData.new()
	data.load_from(file)
	assert_false(data.auto_resolution)
