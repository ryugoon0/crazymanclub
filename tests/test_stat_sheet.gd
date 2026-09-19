class_name TestStatSheet
extends GdUnitTestSuite


func test_base_only() -> void:
	var s := StatSheet.new()
	s.set_base(&"damage", 22.0)
	assert_float(s.get_stat(&"damage")).is_equal_approx(22.0, 0.0001)
	assert_float(s.get_stat(&"missing", 7.0)).is_equal_approx(7.0, 0.0001)


func test_add_then_mul_order() -> void:
	var s := StatSheet.new()
	s.set_base(&"damage", 22.0)
	s.add_modifier(StatModifier.make(&"damage", StatModifier.Op.MUL, 1.1))
	s.add_modifier(StatModifier.make(&"damage", StatModifier.Op.ADD, 3.0))
	# (22 + 3) * 1.1 regardless of insertion order
	assert_float(s.get_stat(&"damage")).is_equal_approx(27.5, 0.0001)


func test_override_wins() -> void:
	var s := StatSheet.new()
	s.set_base(&"damage", 22.0)
	s.add_modifier(StatModifier.make(&"damage", StatModifier.Op.MUL, 2.0))
	s.add_modifier(StatModifier.make(&"damage", StatModifier.Op.OVERRIDE, 5.0))
	assert_float(s.get_stat(&"damage")).is_equal_approx(5.0, 0.0001)


func test_cache_invalidates_on_change() -> void:
	var s := StatSheet.new()
	s.set_base(&"speed", 6.0)
	assert_float(s.get_stat(&"speed")).is_equal_approx(6.0, 0.0001)
	var m := StatModifier.make(&"speed", StatModifier.Op.MUL, 1.08)
	s.add_modifier(m)
	assert_float(s.get_stat(&"speed")).is_equal_approx(6.48, 0.0001)
	s.remove_modifier(m)
	assert_float(s.get_stat(&"speed")).is_equal_approx(6.0, 0.0001)
	s.set_base(&"speed", 7.0)
	assert_float(s.get_stat(&"speed")).is_equal_approx(7.0, 0.0001)


func test_unrelated_stats_do_not_interfere() -> void:
	var s := StatSheet.new()
	s.set_base(&"hp", 100.0)
	s.set_base(&"damage", 22.0)
	s.add_modifier(StatModifier.make(&"hp", StatModifier.Op.MUL, 1.15))
	assert_float(s.get_stat(&"damage")).is_equal_approx(22.0, 0.0001)
	assert_float(s.get_stat(&"hp")).is_equal_approx(115.0, 0.0001)
