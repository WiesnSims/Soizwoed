class_name VoiceChat
extends Node
## Proximity voice chat over Steam (DESIGN.md §9, §11). One per player, added when the session
## carries voice (NetworkManager.voice_enabled()). Voice code may call Steam directly.
##
## Local player: records while V is held (or always with open mic; Steam's voice detection
## only sends while you speak), sends the compressed packets unreliably to everyone. A loud
## voice counts as a shout and scares Bergmandl.
## Other players: decompress and play the packets on a 3D speaker at the speaker's head,
## louder up close and muffled through rock (MuffledAudio), with a little cave reverb on the
## Voice bus. Dead players can only talk to each other: the living do not hear them, the dead
## hear each other without position (they are spectating).

enum Hearing { NONE, POSITIONAL, FLAT }

const SAMPLE_RATE: int = 24000
const BUFFER_SECONDS: float = 0.4
const DECOMPRESS_BUFFER: int = 20480
## How long after the last packet a player still counts as talking (HUD).
const TALK_HOLD_SECONDS: float = 0.3

## Dev/test: also play your own voice back to yourself ("Mikro probiern" in the pause menu).
static var echo: bool = false

## Local player: transmitting right now (for the HUD).
var talking: bool = false

var _player: Player
var _config: BalanceConfig
var _recording: bool = false
var _loud_time: float = 0.0
var _last_sent_at: float = -100.0
var _speaker: MuffledAudio
var _speaker_flat: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _playback_flat: AudioStreamGeneratorPlayback


## Who hears a voice: dead players are heard only by the dead (DESIGN.md §9).
static func hearing(speaker_alive: bool, listener_alive: bool) -> Hearing:
	if speaker_alive:
		return Hearing.POSITIONAL
	return Hearing.NONE if listener_alive else Hearing.FLAT


## 16-bit little-endian mono PCM as stereo frames for an AudioStreamGenerator.
static func pcm16_to_frames(pcm: PackedByteArray, byte_count: int = -1) -> PackedVector2Array:
	var count: int = (pcm.size() if byte_count < 0 else mini(byte_count, pcm.size())) / 2
	var frames: PackedVector2Array = PackedVector2Array()
	frames.resize(count)
	for i: int in count:
		var sample: float = pcm.decode_s16(i * 2) / 32768.0
		frames[i] = Vector2(sample, sample)
	return frames


## Loudest sample of 16-bit PCM, 0–1.
static func peak_level(pcm: PackedByteArray, byte_count: int = -1) -> float:
	var count: int = (pcm.size() if byte_count < 0 else mini(byte_count, pcm.size())) / 2
	var peak: int = 0
	for i: int in count:
		peak = maxi(peak, absi(pcm.decode_s16(i * 2)))
	return peak / 32768.0


func _ready() -> void:
	_player = get_parent() as Player
	_config = Balance.config
	_speaker = MuffledAudio.new()
	_speaker.name = "VoiceSpeaker"
	_speaker.bus = &"Voice"
	_speaker.max_distance = _config.voice_chat_range
	_speaker.unit_size = 4.0
	_speaker.volume_db = _config.voice_chat_volume_db
	_speaker.stream = _generator()
	_player.head.add_child(_speaker)
	_speaker_flat = AudioStreamPlayer.new()
	_speaker_flat.name = "VoiceFlat"
	_speaker_flat.bus = &"Voice"
	_speaker_flat.stream = _generator()
	add_child(_speaker_flat)


func _exit_tree() -> void:
	if _recording:
		Steam.stopVoiceRecording()
		_recording = false


func _generator() -> AudioStreamGenerator:
	var generator: AudioStreamGenerator = AudioStreamGenerator.new()
	generator.mix_rate = SAMPLE_RATE
	generator.buffer_length = BUFFER_SECONDS
	return generator


func _process(delta: float) -> void:
	if _player.is_local():
		_process_local(delta)


func _process_local(delta: float) -> void:
	var want: bool = Audio.voice_open_mic or (Input.is_action_pressed(&"voice_talk") and not Game.dev_quiet)
	if want != _recording:
		_recording = want
		if want:
			Steam.startVoiceRecording()
		else:
			Steam.stopVoiceRecording()
	# Keep reading after a stop: Steam delivers the rest of what was said.
	var voice: Dictionary = Steam.getVoice(0)
	var now: float = Time.get_ticks_msec() / 1000.0
	if int(voice.get("result", -1)) == Steam.VOICE_RESULT_OK and int(voice.get("written", 0)) > 0:
		var data: PackedByteArray = voice["buffer"]
		data = data.slice(0, int(voice["written"]))
		_voice_packet.rpc(data)
		_last_sent_at = now
		_check_loudness(data, delta)
		if echo:
			_play(data, Hearing.FLAT)
	else:
		_loud_time = 0.0
	talking = now - _last_sent_at < TALK_HOLD_SECONDS


## Shouting into the mic works like the shout key (DESIGN.md §9: shouting scares Bergmandl).
func _check_loudness(data: PackedByteArray, delta: float) -> void:
	var pcm: Dictionary = Steam.decompressVoice(data, SAMPLE_RATE, DECOMPRESS_BUFFER)
	if int(pcm.get("result", -1)) != Steam.VOICE_RESULT_OK:
		return
	if peak_level(pcm["uncompressed"], int(pcm["size"])) >= _config.voice_shout_level:
		_loud_time += maxf(delta, 0.05)
		if _loud_time >= _config.voice_shout_seconds:
			_loud_time = 0.0
			_player.voice_shout()
	else:
		_loud_time = 0.0


@rpc("any_peer", "call_remote", "unreliable")
func _voice_packet(data: PackedByteArray) -> void:
	if multiplayer.get_remote_sender_id() != _player.peer_id:
		return
	var listener: Player = Game.instance.local_player() if Game.instance != null else null
	var listener_alive: bool = listener == null or listener.alive
	_play(data, hearing(_player.alive, listener_alive))


func _play(data: PackedByteArray, how: Hearing) -> void:
	if how == Hearing.NONE:
		return
	var pcm: Dictionary = Steam.decompressVoice(data, SAMPLE_RATE, DECOMPRESS_BUFFER)
	if int(pcm.get("result", -1)) != Steam.VOICE_RESULT_OK:
		return
	var frames: PackedVector2Array = pcm16_to_frames(pcm["uncompressed"], int(pcm["size"]))
	var playback: AudioStreamGeneratorPlayback = _flat_playback() if how == Hearing.FLAT else _positional_playback()
	if playback != null and playback.can_push_buffer(frames.size()):
		playback.push_buffer(frames)


func _positional_playback() -> AudioStreamGeneratorPlayback:
	if not _speaker.playing:
		_speaker.play()
		_playback = _speaker.get_stream_playback() as AudioStreamGeneratorPlayback
	return _playback


func _flat_playback() -> AudioStreamGeneratorPlayback:
	if not _speaker_flat.playing:
		_speaker_flat.play()
		_playback_flat = _speaker_flat.get_stream_playback() as AudioStreamGeneratorPlayback
	return _playback_flat
