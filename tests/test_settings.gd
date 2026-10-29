extends GutTest
## Player settings: defaults, limits, saving and loading (pure SettingsData, no window needed).


func test_defaults_keep_the_tuned_look() -> void:
	var data: SettingsData = SettingsData.new()
	assert_eq(data.quality, SettingsData.Quality.HIGH)
	assert_eq(data.anti_aliasing, SettingsData.AntiAliasing.MSAA_TAA)
	assert_eq(data.fov, 78.0)
	assert_true(data.creature_lines, "Gegner reden is on by default (DESIGN.md §6)")
	var high: Dictionary = SettingsData.quality_values(SettingsData.Quality.HIGH)
	assert_eq(int(high.shadow_atlas), 8192, "HIGH matches project.godot")
	assert_eq(int(high.fog_size), 128)


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
	assert_eq(data.fps_limit, 0)
	assert_eq(data.fov, SettingsData.FOV_MAX)
	assert_eq(data.quality, SettingsData.Quality.ULTRA)
	assert_eq(data.mouse_sensitivity, SettingsData.SENSITIVITY_MIN)


func test_volume_zero_is_silent() -> void:
	assert_eq(SettingsData.volume_db(0.0), -80.0)
	assert_almost_eq(SettingsData.volume_db(1.0), 0.0, 0.001)


func test_settings_texts_are_translated() -> void:
	for key: String in ["MENU_SETTINGS", "SETTINGS_AUDIO", "SETTINGS_DISPLAY", "SETTINGS_GRAPHICS", "SETTINGS_GAMEPLAY", "SET_CREATURE_LINES", "INVITE_TITLE"]:
		assert_ne(tr(key), key, "no text for %s" % key)
