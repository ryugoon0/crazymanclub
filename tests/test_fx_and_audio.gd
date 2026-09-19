class_name TestFxAndAudio
extends GdUnitTestSuite


func test_hit_stop_restores_time_scale_after_frames() -> void:
	var h: HitStop = auto_free(HitStop.new())
	h._ready()
	h.request(3)
	assert_float(Engine.time_scale).is_less(1.0)
	h.request(1)  # overlaps by max, not sum
	h._process(0.0)
	h._process(0.0)
	assert_float(Engine.time_scale).is_less(1.0)
	h._process(0.0)
	assert_float(Engine.time_scale).is_equal_approx(1.0, 0.0001)


func test_hit_stop_disabled_is_noop() -> void:
	var h: HitStop = auto_free(HitStop.new())
	h._ready()
	h.enabled = false
	h.request(5)
	assert_float(Engine.time_scale).is_equal_approx(1.0, 0.0001)


func test_debris_lives_and_dies() -> void:
	var d: DebrisSystem = auto_free(DebrisSystem.new())
	d.capacity = 32
	d._ready()
	d.burst(Vector3(1, 0, 1), Vector3(1, 0, 0), Color.GREEN, 6)
	d.step(1.0 / 60.0)
	assert_int(d.live_count()).is_equal(6)
	for _k: int in range(120):
		d.step(1.0 / 60.0)
	assert_int(d.live_count()).is_equal(0)


func test_debris_never_below_ground() -> void:
	var d: DebrisSystem = auto_free(DebrisSystem.new())
	d.capacity = 16
	d._ready()
	d.burst(Vector3.ZERO, Vector3(1, 0, 0), Color.GREEN, 8)
	for _k: int in range(60):
		d.step(1.0 / 60.0)
		for i: int in range(8):
			assert_float(d._pos[i].y).is_greater_equal(d.chunk_size * 0.5 - 0.0001)


func test_audio_pool_caps_same_sound() -> void:
	var a: AudioPool = auto_free(AudioPool.new())
	a.voices = 8
	a.per_sound_cap = 3
	a.min_interval = 0.0
	a._ready()
	var gen := AudioStreamGenerator.new()
	a.register(&"x", gen)
	var started := 0
	for _k: int in range(6):
		if a.play(&"x"):
			started += 1
	assert_int(started).is_equal(3)
	assert_int(a.dropped).is_equal(3)


func test_audio_pool_steals_lower_priority_when_full() -> void:
	var a: AudioPool = auto_free(AudioPool.new())
	a.voices = 2
	a.per_sound_cap = 8
	a.min_interval = 0.0
	a._ready()
	a.register(&"low", AudioStreamGenerator.new())
	a.register(&"high", AudioStreamGenerator.new())
	assert_bool(a.play(&"low", 1)).is_true()
	assert_bool(a.play(&"low", 1)).is_true()
	assert_bool(a.play(&"low", 1)).is_false()   # full, equal priority: dropped
	assert_bool(a.play(&"high", 5)).is_true()   # steals
	assert_int(a.stolen).is_equal(1)
