extends Node
## The microphone (owner request after the M6 playtest): records from the input device picked in
## the settings into a muted bus, and hands out what was said as small voice packets – 40 ms of
## 16 kHz mono, μ-law coded (one byte a sample, about 16 KB/s while talking). Voice chat sends
## them over the game's own connection, so it works with Steam and with ENet alike.
## The mic only records while something wants it (voice chat in a session, the level meter in
## the settings), so the system's "microphone in use" light is off otherwise.

const BUS: StringName = &"MicCapture"
const RATE: int = 16000
const PACKET_SAMPLES: int = 640  # 40 ms
## The last stretch's loudest sample, 0–1, falling off slowly (for meters).
var level: float = 0.0

var _users: Dictionary = {}
var _player: AudioStreamPlayer
var _capture: AudioEffectCapture
var _pending: PackedFloat32Array = []
## Resampling position into the mixer's samples (they come at the mix rate, we want RATE).
var _resample_at: float = 0.0
var _last_sample: float = 0.0


func _ready() -> void:
	var index: int = AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, BUS)
	AudioServer.set_bus_mute(index, true)  # recorded, never played back
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 0.5
	AudioServer.add_bus_effect(index, _capture)
	_player = AudioStreamPlayer.new()
	_player.stream = AudioStreamMicrophone.new()
	_player.bus = BUS
	add_child(_player)


## `who` wants the microphone on (or no longer); it records while anyone does.
func want(who: StringName, on: bool) -> void:
	if DisplayServer.get_name() == "headless" or Array(OS.get_cmdline_user_args()).any(func(arg: String) -> bool: return arg.begins_with("--shots=")):
		return  # automated runs never open the microphone
	if on:
		_users[who] = true
	else:
		_users.erase(who)
	var recording: bool = not _users.is_empty()
	if recording and not _player.playing:
		_capture.clear_buffer()
		_pending.clear()
		_player.play()
	elif not recording and _player.playing:
		_player.stop()
		level = 0.0


func recording() -> bool:
	return _player.playing


func _process(delta: float) -> void:
	level = maxf(0.0, level - delta * 0.8)
	if not _player.playing:
		return
	var available: int = _capture.get_frames_available()
	if available <= 0:
		return
	var frames: PackedVector2Array = _capture.get_buffer(available)
	var step: float = AudioServer.get_mix_rate() / RATE
	# Mono, then down to RATE (linear interpolation between the mixer's samples).
	for i: int in frames.size():
		var sample: float = (frames[i].x + frames[i].y) * 0.5
		level = maxf(level, absf(sample))
		while _resample_at <= 1.0:
			_pending.append(lerpf(_last_sample, sample, _resample_at))
			_resample_at += step
		_resample_at -= 1.0
		_last_sample = sample
	# Never more than a second behind (nobody took the packets).
	if _pending.size() > RATE:
		_pending = _pending.slice(_pending.size() - RATE)


## The next 40 ms of voice, coded, or an empty array when not enough has been said yet.
func take_packet() -> PackedByteArray:
	if _pending.size() < PACKET_SAMPLES:
		return PackedByteArray()
	var samples: PackedFloat32Array = _pending.slice(0, PACKET_SAMPLES)
	_pending = _pending.slice(PACKET_SAMPLES)
	return encode(samples)


## Throws away what was recorded but not sent (push-to-talk released).
func discard() -> void:
	_pending.clear()


# --- μ-law (G.711): 14 bits of voice in one byte -------------------------------------------------

const _BIAS: int = 0x84
const _CLIP: int = 32635


static func encode(samples: PackedFloat32Array) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(samples.size())
	for i: int in samples.size():
		out[i] = _encode_one(clampi(int(samples[i] * 32767.0), -32768, 32767))
	return out


static func decode(bytes: PackedByteArray) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(bytes.size())
	for i: int in bytes.size():
		out[i] = _decode_one(bytes[i]) / 32768.0
	return out


static func _encode_one(value: int) -> int:
	var sign: int = 0x80 if value < 0 else 0
	var magnitude: int = mini(absi(value), _CLIP) + _BIAS
	var exponent: int = clampi(int(floor(log(float(magnitude)) / log(2.0))) - 7, 0, 7)
	var mantissa: int = (magnitude >> (exponent + 3)) & 0x0F
	return ~(sign | (exponent << 4) | mantissa) & 0xFF


static func _decode_one(code: int) -> int:
	var inverted: int = ~code & 0xFF
	var exponent: int = (inverted >> 4) & 0x07
	var magnitude: int = (((inverted & 0x0F) << 3) + _BIAS) << exponent
	magnitude -= _BIAS
	return -magnitude if inverted & 0x80 else magnitude


## Devices for the settings ("Default" first, as Godot names it).
static func input_devices() -> PackedStringArray:
	return AudioServer.get_input_device_list()


static func output_devices() -> PackedStringArray:
	return AudioServer.get_output_device_list()
