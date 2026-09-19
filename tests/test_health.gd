class_name TestHealth
extends GdUnitTestSuite


func test_damage_and_death() -> void:
	var h: Health = auto_free(Health.new())
	h.max_hp = 100.0
	h._ready()
	var died: Array[int] = [0]
	h.died.connect(func() -> void: died[0] += 1)
	h.take(DamageInfo.make(40.0, Vector3.RIGHT))
	assert_float(h.hp).is_equal_approx(60.0, 0.001)
	h.take(DamageInfo.make(70.0, Vector3.RIGHT))
	assert_float(h.hp).is_equal_approx(0.0, 0.001)
	assert_bool(h.is_dead).is_true()
	assert_int(died[0]).is_equal(1)
	h.take(DamageInfo.make(10.0, Vector3.RIGHT))
	assert_int(died[0]).is_equal(1)


func test_invulnerable() -> void:
	var h: Health = auto_free(Health.new())
	h.max_hp = 50.0
	h._ready()
	h.invulnerable = true
	h.take(DamageInfo.make(999.0, Vector3.RIGHT))
	assert_float(h.hp).is_equal_approx(50.0, 0.001)
