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
## Funkgerät (DESIGN.md §7): when both carry one and are too far apart to hear each other
## well, the voice also comes out of the radio, tinny but at any distance, with static while
## a creature is close to either end.

enum Hearing { NONE, POSITIONAL, FLAT, RADIO }

## Beyond this share of the voice range the radio takes over.
const RADIO_FROM_SHARE: float = 0.4

const SAMPLE_RATE: int = 24000
const BUFFER_SECONDS: float = 0.4
const DECOMPRESS_BUFFER: int = 20480
## How long after the last packet a player still counts as talking (HUD).
const TALK_HOLD_SECONDS: float = 0.3

## Dev/test: also play your own voice back to yourself ("Mikro probiern" in the pause menu).
static var echo: bool = false
## Host: short things each miner said, for the Salzweibl to play back (DESIGN.md §6), only from
## miners who allow it (setting). peer id -> Array of snippets, each an Array of Steam voice
## packets, newest last.
static var snippets: Dictionary = {}

## A pause this long ends a snippet.
const SNIPPET_GAP_SECONDS: float = 0.45

## Local player: transmitting right now (for the HUD).
var talking: bool = false

var _player: Player
var _config: BalanceConfig
var _recording: bool = false
var _loud_time: float = 0.0
var _last_sent_at: float = -100.0
var _speaker: MuffledAudio
var _speaker_flat: AudioStreamPlayer
var _speaker_radio: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _playback_flat: AudioStreamGeneratorPlayback
var _playback_radio: AudioStreamGeneratorPlayback
## Host: the snippet being recorded from this miner right now.
var _snippet: Array[PackedByteArray] = []
var _snippet_started: float = 0.0
var _snippet_last: float = 0.0


## The snippet's packets decoded into one sound, or null (no Steam, or nothing in it).
static func decode(packets: Array) -> AudioStreamWAV:
	if not ClassDB.class_exists(&"Steam"):
		return null
	var pcm: PackedByteArray = PackedByteArray()
	for packet: Variant in packets:
		var result: Dictionary = Steam.decompressVoice(packet as PackedByteArray, SAMPLE_RATE, DECOMPRESS_BUFFER)
		if int(result.get("result", -1)) == Steam.VOICE_RESULT_OK:
			pcm.append_array((result["uncompressed"] as PackedByteArray).slice(0, int(result["size"])))
	if pcm.is_empty():
		return null
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = pcm
	return wav


## A random snippet of someone other than `not_peer` (falls back to theirs), as
## {"peer": id, "packets": Array}; empty when nobody has said anything usable yet.
static func pick_snippet(not_peer: int) -> Dictionary:
	var others: Array = snippets.keys().filter(func(peer: int) -> bool: return peer != not_peer and not (snippets[peer] as Array).is_empty())
	if others.is_empty() and snippets.has(not_peer) and not (snippets[not_peer] as Array).is_empty():
		others = [not_peer]
	if others.is_empty():
		return {}
	var peer: int = others.pick_random()
	return {"peer": peer, "packets": (snippets[peer] as Array).pick_random()}


## Host: one more packet of this miner's voice. Packets with short pauses between them are one
## snippet; a finished snippet of the right length is kept.
func _capture(data: PackedByteArray) -> void:
	if not multiplayer.is_server() or not _player.voice_lure_ok:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if not _snippet.is_empty() and now - _snippet_last > SNIPPET_GAP_SECONDS:
		_finish_snippet()
	if _snippet.is_empty():
		_snippet_started = now
	if now - _snippet_started < _config.salzweibl_snippet_max_seconds:
		_snippet.append(data)
	_snippet_last = now


func _finish_snippet() -> void:
	var length: float = _snippet_last - _snippet_started
	if length >= _config.salzweibl_snippet_min_seconds:
		var kept: Array = snippets.get(_player.peer_id, [])
		kept.append(_snippet.duplicate())
		while kept.size() > _config.salzweibl_snippets_kept:
			kept.pop_front()
		snippets[_player.peer_id] = kept
	_snippet.clear()


## Who hears a voice: dead players are heard only by the dead (DESIGN.md §9); living players
## who both carry a Funkgerät hear each other over the radio when far apart.
static func hearing(speaker_alive: bool, listener_alive: bool, both_radio: bool = false,
		distance: float = 0.0, voice_range: float = INF) -> Hearing:
	if speaker_alive:
		if both_radio and listener_alive and distance > voice_range * RADIO_FROM_SHARE:
			return Hearing.RADIO
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
	_speaker_radio = AudioStreamPlayer.new()
	_speaker_radio.name = "VoiceRadio"
	_speaker_radio.bus = &"Radio"
	_speaker_radio.volume_db = _config.funk_volume_db
	_speaker_radio.stream = _generator()
	add_child(_speaker_radio)


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
	if not _snippet.is_empty() and Time.get_ticks_msec() / 1000.0 - _snippet_last > SNIPPET_GAP_SECONDS:
		_finish_snippet()


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
		_capture(data)
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
	_capture(data)
	var listener: Player = Game.instance.local_player() if Game.instance != null else null
	var listener_alive: bool = listener == null or listener.alive
	var both_radio: bool = listener != null and _player.has_tool(&"funkgeraet") and listener.has_tool(&"funkgeraet")
	var distance: float = listener.global_position.distance_to(_player.global_position) if listener != null else 0.0
	var how: Hearing = hearing(_player.alive, listener_alive, both_radio, distance, _config.voice_chat_range)
	if how == Hearing.RADIO and (_creature_near(_player) or _creature_near(listener)):
		listener.play_radio(0.3)
	_play(data, how)


## A creature close to this end of the radio puts static on the line.
func _creature_near(player: Player) -> bool:
	for creature: Creature in Game.instance.creatures():
		if creature.global_position.distance_to(player.global_position) < _config.funk_static_distance:
			return true
	return false


func _play(data: PackedByteArray, how: Hearing) -> void:
	if how == Hearing.NONE:
		return
	var pcm: Dictionary = Steam.decompressVoice(data, SAMPLE_RATE, DECOMPRESS_BUFFER)
	if int(pcm.get("result", -1)) != Steam.VOICE_RESULT_OK:
		return
	var frames: PackedVector2Array = pcm16_to_frames(pcm["uncompressed"], int(pcm["size"]))
	var playback: AudioStreamGeneratorPlayback = _positional_playback()
	if how == Hearing.FLAT:
		playback = _flat_playback()
	elif how == Hearing.RADIO:
		# Still heard in the tunnel too (faintly, muffled), as well as out of the radio.
		if playback != null and playback.can_push_buffer(frames.size()):
			playback.push_buffer(frames)
		playback = _radio_playback()
	if playback != null and playback.can_push_buffer(frames.size()):
		playback.push_buffer(frames)


func _radio_playback() -> AudioStreamGeneratorPlayback:
	if not _speaker_radio.playing:
		_speaker_radio.play()
		_playback_radio = _speaker_radio.get_stream_playback() as AudioStreamGeneratorPlayback
	return _playback_radio


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
