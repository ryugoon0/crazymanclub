class_name TestDataResources
extends GdUnitTestSuite


func test_drone_loads_as_enemy_data() -> void:
	var d: Resource = load("res://data/enemies/drone.tres")
	assert_object(d).is_instanceof(EnemyData)
	var e := d as EnemyData
	assert_str(String(e.id)).is_equal("drone")
	assert_float(e.hp).is_equal_approx(105.0, 0.001)
	assert_float(e.move_speed).is_equal_approx(4.8, 0.001)
	assert_float(e.damage).is_equal_approx(14.0, 0.001)


func test_ar_loads_as_weapon_data() -> void:
	var w: Resource = load("res://data/weapons/ar_basic.tres")
	assert_object(w).is_instanceof(WeaponData)
	var a := w as WeaponData
	assert_str(String(a.id)).is_equal("ar_basic")
	assert_int(a.category).is_equal(WeaponData.Category.ASSAULT_RIFLE)
	assert_int(a.fire_mode).is_equal(WeaponData.FireMode.HITSCAN)
	assert_float(a.damage).is_equal_approx(22.0, 0.001)
	assert_int(a.magazine).is_equal(30)
	assert_int(a.reserve_max).is_equal(-1)


func test_extension_arrays_default_empty() -> void:
	var e: EnemyData = load("res://data/enemies/drone.tres")
	assert_array(e.modifiers).is_empty()
	assert_array(e.effects).is_empty()
