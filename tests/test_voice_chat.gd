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


func test_pcm_to_frames() -> void:
	var frames: PackedVector2Array = VoiceChat.pcm16_to_frames(_pcm([0, 16384, -32768]))
	assert_eq(frames.size(), 3)
	assert_almost_eq(frames[1].x, 0.5, 0.0001)
	assert_almost_eq(frames[1].y, 0.5, 0.0001)
	assert_almost_eq(frames[2].x, -1.0, 0.0001)


func test_pcm_byte_count_limits_frames() -> void:
	assert_eq(VoiceChat.pcm16_to_frames(_pcm([1, 2, 3, 4]), 4).size(), 2)


func test_peak_level() -> void:
	assert_almost_eq(VoiceChat.peak_level(_pcm([100, -16384, 2000])), 0.5, 0.0001)
	assert_eq(VoiceChat.peak_level(PackedByteArray()), 0.0)
	assert_almost_eq(VoiceChat.peak_level(_pcm([100, -16384]), 2), 100.0 / 32768.0, 0.0001)
