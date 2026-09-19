class_name TestComboTracker
extends GdUnitTestSuite


func test_consecutive_kills_within_window_increment() -> void:
	var c := ComboTracker.new()
	c.window = 1.5
	c.register_kill(0.0)
	c.register_kill(1.0)
	c.register_kill(2.0)
	assert_int(c.current).is_equal(3)
	assert_int(c.best).is_equal(3)


func test_gap_past_window_resets_current() -> void:
	var c := ComboTracker.new()
	c.window = 1.5
	c.register_kill(0.0)
	c.register_kill(1.0)
	c.register_kill(5.0)
	assert_int(c.current).is_equal(1)
	assert_int(c.best).is_equal(2)


func test_update_expires_streak_without_a_new_kill() -> void:
	var c := ComboTracker.new()
	c.window = 1.5
	c.register_kill(0.0)
	c.update(1.0)
	assert_int(c.current).is_equal(1)
	c.update(2.0)
	assert_int(c.current).is_equal(0)
	assert_bool(c.is_active(2.0)).is_false()


func test_best_survives_reset() -> void:
	var c := ComboTracker.new()
	c.window = 1.0
	c.register_kill(0.0)
	c.register_kill(0.5)
	c.register_kill(0.9)
	c.update(5.0)
	assert_int(c.current).is_equal(0)
	assert_int(c.best).is_equal(3)
