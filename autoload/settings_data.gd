class_name SettingsData
extends RefCounted
## The player's settings as plain values (audio, display, graphics, gameplay), with their
## limits and how they are saved. Pure logic, so it can be unit tested; the Settings autoload
## applies them.

enum WindowMode { WINDOWED, BORDERLESS, FULLSCREEN }
enum Quality { LOW, MEDIUM, HIGH, ULTRA }
enum AntiAliasing { OFF, FXAA, TAA, MSAA_TAA }

## Frame rate caps offered (0 = no cap).
const FPS_LIMITS: Array[int] = [0, 30, 60, 90, 120, 144, 165, 240]
const DEFAULT_FPS_LIMIT: int = 60
## With automatic resolution the 3D picture is rendered at most this many lines high and
## upscaled with FSR 2 (the UI stays sharp).
const AUTO_RENDER_HEIGHT: float = 1080.0
## Bumped when defaults change in a way old settings files should pick up (see load_from).
const VERSION: int = 3
const FOV_MIN: float = 60.0
const FOV_MAX: float = 100.0
const SENSITIVITY_MIN: float = 0.2
const SENSITIVITY_MAX: float = 3.0

# Audio (volumes 0–1, linear)
var master_volume: float = 1.0
var music_volume: float = 0.8
var effects_volume: float = 1.0
var voice_volume: float = 1.0
## "Gegner reden" (DESIGN.md §6): creature speech; their other sounds always play.
var creature_lines: bool = true
## Voice chat: open mic instead of push-to-talk (V).
var voice_open_mic: bool = false
# Display
var window_mode: WindowMode = WindowMode.WINDOWED
var vsync: bool = true
var fps_limit: int = DEFAULT_FPS_LIMIT
var fov: float = 78.0
## Multiplies the tonemap exposure: the mine is meant to be dark, but screens differ.
var brightness: float = 1.0
# Graphics
var quality: Quality = Quality.HIGH
## 3D resolution share (FSR 2 upscaling below 1), used when auto_resolution is off.
var render_scale: float = 1.0
## Render 3D at no more than 1080p on bigger screens (FSR 2 upscaling). Off: native, or the
## render_scale slider.
var auto_resolution: bool = false
var volumetric_fog: bool = true
var anti_aliasing: AntiAliasing = AntiAliasing.TAA
# Gameplay
var mouse_sensitivity: float = 1.0
var invert_y: bool = false
var head_bob: bool = true


## Brings every value into its allowed range (e.g. after loading a hand-edited file).
func clamp_all() -> void:
	master_volume = clampf(master_volume, 0.0, 1.0)
	music_volume = clampf(music_volume, 0.0, 1.0)
	effects_volume = clampf(effects_volume, 0.0, 1.0)
	voice_volume = clampf(voice_volume, 0.0, 1.0)
	window_mode = clampi(window_mode, 0, WindowMode.size() - 1) as WindowMode
	if not fps_limit in FPS_LIMITS:
		fps_limit = DEFAULT_FPS_LIMIT
	fov = clampf(fov, FOV_MIN, FOV_MAX)
	brightness = clampf(brightness, 0.5, 1.6)
	quality = clampi(quality, 0, Quality.size() - 1) as Quality
	render_scale = clampf(render_scale, 0.5, 1.0)
	anti_aliasing = clampi(anti_aliasing, 0, AntiAliasing.size() - 1) as AntiAliasing
	mouse_sensitivity = clampf(mouse_sensitivity, SENSITIVITY_MIN, SENSITIVITY_MAX)


func save_to(file: ConfigFile) -> void:
	file.set_value("audio", "master", master_volume)
	file.set_value("audio", "music", music_volume)
	file.set_value("audio", "effects", effects_volume)
	file.set_value("audio", "voice", voice_volume)
	file.set_value("audio", "creature_lines", creature_lines)
	file.set_value("voice", "open_mic", voice_open_mic)
	file.set_value("display", "window_mode", window_mode)
	file.set_value("display", "vsync", vsync)
	file.set_value("display", "fps_limit", fps_limit)
	file.set_value("display", "fov", fov)
	file.set_value("display", "brightness", brightness)
	file.set_value("graphics", "quality", quality)
	file.set_value("graphics", "render_scale", render_scale)
	file.set_value("graphics", "auto_resolution", auto_resolution)
	file.set_value("meta", "version", VERSION)
	file.set_value("graphics", "volumetric_fog", volumetric_fog)
	file.set_value("graphics", "anti_aliasing", anti_aliasing)
	file.set_value("gameplay", "mouse_sensitivity", mouse_sensitivity)
	file.set_value("gameplay", "invert_y", invert_y)
	file.set_value("gameplay", "head_bob", head_bob)


## Missing keys keep their defaults, so old settings files still load.
func load_from(file: ConfigFile) -> void:
	master_volume = float(file.get_value("audio", "master", master_volume))
	music_volume = float(file.get_value("audio", "music", music_volume))
	effects_volume = float(file.get_value("audio", "effects", effects_volume))
	voice_volume = float(file.get_value("audio", "voice", voice_volume))
	creature_lines = bool(file.get_value("audio", "creature_lines", creature_lines))
	voice_open_mic = bool(file.get_value("voice", "open_mic", voice_open_mic))
	window_mode = int(file.get_value("display", "window_mode", window_mode)) as WindowMode
	vsync = bool(file.get_value("display", "vsync", vsync))
	fps_limit = int(file.get_value("display", "fps_limit", fps_limit))
	fov = float(file.get_value("display", "fov", fov))
	brightness = float(file.get_value("display", "brightness", brightness))
	quality = int(file.get_value("graphics", "quality", quality)) as Quality
	render_scale = float(file.get_value("graphics", "render_scale", render_scale))
	auto_resolution = bool(file.get_value("graphics", "auto_resolution", auto_resolution))
	volumetric_fog = bool(file.get_value("graphics", "volumetric_fog", volumetric_fog))
	anti_aliasing = int(file.get_value("graphics", "anti_aliasing", anti_aliasing)) as AntiAliasing
	mouse_sensitivity = float(file.get_value("gameplay", "mouse_sensitivity", mouse_sensitivity))
	invert_y = bool(file.get_value("gameplay", "invert_y", invert_y))
	head_bob = bool(file.get_value("gameplay", "head_bob", head_bob))
	# Files from before version 2 saved the old, heavy defaults (uncapped frame rate, MSAA on top
	# of TAA) whether or not the player chose them: move those to the new defaults.
	var version: int = int(file.get_value("meta", "version", 1))
	# Version 2 had FSR 2 on by default; the owner wants native resolution unless chosen.
	if version == 2:
		auto_resolution = false
	if version < 2:
		if fps_limit == 0:
			fps_limit = DEFAULT_FPS_LIMIT
		if anti_aliasing == AntiAliasing.MSAA_TAA:
			anti_aliasing = AntiAliasing.TAA
	clamp_all()


## How much of the window's resolution the 3D picture is rendered at (1 = native).
func effective_render_scale(window_height: int) -> float:
	if not auto_resolution:
		return render_scale
	return clampf(AUTO_RENDER_HEIGHT / maxf(1.0, window_height), 0.5, 1.0)


## Renderer values of a quality preset. HIGH is the look the game was tuned with (minus the
## costs nobody could see: an 8K shadow atlas, full-detail reflections).
static func quality_values(preset: Quality) -> Dictionary:
	match preset:
		Quality.LOW:
			return {"shadow_atlas": 2048, "soft_shadows": 1, "ssao": false, "ssao_quality": 0, "ssil": false, "ssil_quality": 0, "fog_size": 64, "fog_depth": 48, "ssr": false, "ssr_steps": 0, "shadow_distance": 14.0}
		Quality.MEDIUM:
			return {"shadow_atlas": 4096, "soft_shadows": 2, "ssao": true, "ssao_quality": 1, "ssil": false, "ssil_quality": 0, "fog_size": 80, "fog_depth": 64, "ssr": false, "ssr_steps": 0, "shadow_distance": 18.0}
		Quality.ULTRA:
			return {"shadow_atlas": 8192, "soft_shadows": 4, "ssao": true, "ssao_quality": 3, "ssil": true, "ssil_quality": 2, "fog_size": 128, "fog_depth": 96, "ssr": true, "ssr_steps": 48, "shadow_distance": 40.0}
		_:
			return {"shadow_atlas": 4096, "soft_shadows": 2, "ssao": true, "ssao_quality": 2, "ssil": true, "ssil_quality": 1, "fog_size": 96, "fog_depth": 64, "ssr": true, "ssr_steps": 24, "shadow_distance": 24.0}


## Linear volume 0–1 as bus decibels (silent at 0).
static func volume_db(linear: float) -> float:
	return -80.0 if linear <= 0.001 else linear_to_db(linear)
