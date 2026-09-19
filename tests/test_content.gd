class_name TestContent
extends GdUnitTestSuite


func test_registry_finds_shipped_content() -> void:
	assert_object(Content.weapon(&"ar_basic")).is_not_null()
	assert_object(Content.weapon(&"shotgun")).is_not_null()
	assert_object(Content.weapon(&"plasma_rifle")).is_not_null()
	assert_object(Content.enemy(&"tank")).is_not_null()
	assert_object(Content.enemy(&"boss_broodmother")).is_not_null()
	assert_object(Content.upgrade(&"weapon_track")).is_not_null()
	assert_object(Content.mission(&"m01")).is_not_null()
	assert_object(Content.weapon(&"nope")).is_null()


func test_weapons_sorted_by_price() -> void:
	var ws := Content.weapons()
	assert_int(ws.size()).is_equal(3)
	assert_str(String(ws[0].id)).is_equal("ar_basic")
	assert_str(String(ws[2].id)).is_equal("plasma_rifle")
	assert_object(ws[2].projectile).is_not_null()


func test_mission_waves_and_economy() -> void:
	var m := Content.mission(&"m01")
	assert_int(m.waves.size()).is_equal(5)
	var total := 0
	for w in m.waves:
		total += w.total()
	# ~250 regular enemies per run (economy hypothesis)
	assert_int(total).is_between(150, 260)
	assert_object(m.boss).is_not_null()
	assert_float(Content.economy_data().death_retain_ratio).is_equal_approx(0.5, 0.001)


func test_upgrade_track_math() -> void:
	var t := Content.upgrade(&"weapon_track")
	assert_int(t.cost_for_next(0)).is_equal(1200)
	assert_int(t.cost_for_next(4)).is_equal(8000)
	assert_int(t.cost_for_next(5)).is_equal(-1)
	var s := StatSheet.new()
	s.set_base(&"damage", 22.0)
	s.add_modifiers(t.modifiers_at(2))
	# +10% compounding twice: 22 * 1.21 = 26.62 -> runner (52 hp) dies in 2 shots
	assert_float(s.get_stat(&"damage")).is_equal_approx(26.62, 0.001)
	assert_bool(s.get_stat(&"damage") * 2.0 >= 52.0).is_true()
