extends GutTest
## Voice chat rules and PCM handling (no Steam or microphone needed).


func _pcm(samples: Array[int]) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, samples[i])
	return bytes


func test_the_living_hear_the_living_in_3d() -> void:
	assert_eq(VoiceChat.hearing(true, true), VoiceChat.Hearing.POSITIONAL)


func test_the_dead_still_hear_the_living() -> void:
	assert_eq(VoiceChat.hearing(true, false), VoiceChat.Hearing.POSITIONAL)


func test_the_dead_talk_only_to_the_dead() -> void:
	assert_eq(VoiceChat.hearing(false, true), VoiceChat.Hearing.NONE)
	assert_eq(VoiceChat.hearing(false, false), VoiceChat.Hearing.FLAT)


func test_mu_law_round_trip_is_close() -> void:
	var samples: PackedFloat32Array = PackedFloat32Array([0.0, 0.01, -0.01, 0.25, -0.5, 0.9, -1.0])
	var back: PackedFloat32Array = Mic.decode(Mic.encode(samples))
	assert_eq(back.size(), samples.size())
	for i: int in samples.size():
		# μ-law keeps quiet sounds fine and loud ones within a few per cent.
		assert_almost_eq(back[i], samples[i], maxf(0.002, absf(samples[i]) * 0.07), "sample %d" % i)


func test_one_byte_per_sample() -> void:
	assert_eq(Mic.encode(PackedFloat32Array([0.1, 0.2, 0.3])).size(), 3)


func test_packet_frames_and_peak() -> void:
	var packet: PackedByteArray = Mic.encode(PackedFloat32Array([0.0, 0.5, -0.25]))
	var frames: PackedVector2Array = VoiceChat.packet_frames(packet)
	assert_eq(frames.size(), 3)
	assert_almost_eq(frames[1].x, 0.5, 0.03)
	assert_eq(frames[1].x, frames[1].y)
	assert_almost_eq(VoiceChat.peak_level(packet), 0.5, 0.03)
	assert_eq(VoiceChat.peak_level(PackedByteArray()), 0.0)


func test_snippet_decodes_to_a_sound() -> void:
	var wav: AudioStreamWAV = VoiceChat.decode([Mic.encode(PackedFloat32Array([0.1, 0.2])), Mic.encode(PackedFloat32Array([0.3]))])
	assert_eq(wav.mix_rate, Mic.RATE)
	assert_eq(wav.data.size(), 6, "16-bit samples")
	assert_null(VoiceChat.decode([]))


func test_far_apart_with_radios_comes_over_the_radio() -> void:
	assert_eq(VoiceChat.hearing(true, true, true, 25.0, 30.0), VoiceChat.Hearing.RADIO)


func test_close_by_with_radios_stays_in_3d() -> void:
	assert_eq(VoiceChat.hearing(true, true, true, 5.0, 30.0), VoiceChat.Hearing.POSITIONAL)


func test_no_radio_without_both_radios() -> void:
	assert_eq(VoiceChat.hearing(true, true, false, 200.0, 30.0), VoiceChat.Hearing.POSITIONAL)


func test_the_dead_do_not_use_the_radio() -> void:
	assert_eq(VoiceChat.hearing(false, true, true, 200.0, 30.0), VoiceChat.Hearing.NONE)
	assert_eq(VoiceChat.hearing(true, false, true, 200.0, 30.0), VoiceChat.Hearing.POSITIONAL)
