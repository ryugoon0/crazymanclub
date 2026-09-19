class_name TestProfileAndSave
extends GdUnitTestSuite

var _svc: Node


func before_test() -> void:
	_svc = auto_free(load("res://core/save_service.gd").new())
	_svc.save_dir = "user://test_saves_%d" % Time.get_ticks_usec()
	Profile.reset()


func after_test() -> void:
	_svc.wipe()
	Profile.reset()


func test_profile_roundtrip() -> void:
	Profile.add_credits(2300)
	assert_bool(Profile.buy_weapon(Content.weapon(&"shotgun"))).is_false()  # 5500 > 2300
	assert_bool(Profile.upgrade_weapon(&"ar_basic", Content.upgrade(&"weapon_track"))).is_true()
	assert_int(Profile.credits).is_equal(1100)
	assert_int(Profile.weapon_level(&"ar_basic")).is_equal(1)
	var d := Profile.to_dict()
	assert_int(d["schema_version"]).is_equal(1)
	Profile.reset()
	assert_int(Profile.credits).is_equal(0)
	assert_bool(Profile.from_dict(d)).is_true()
	assert_int(Profile.credits).is_equal(1100)
	assert_int(Profile.weapon_level(&"ar_basic")).is_equal(1)
	assert_str(String(Profile.equipped_weapon)).is_equal("ar_basic")


func test_save_load_atomic_with_backup() -> void:
	Profile.add_credits(500)
	assert_bool(_svc.save_dict(Profile.to_dict())).override_failure_message(_svc.last_error).is_true()
	Profile.add_credits(250)
	assert_bool(_svc.save_dict(Profile.to_dict())).is_true()
	assert_bool(FileAccess.file_exists(_svc.path())).is_true()
	assert_bool(FileAccess.file_exists(_svc.backup_path())).is_true()
	var d: Dictionary = _svc.load_dict()
	assert_int(int(d["wallet"]["credit"])).is_equal(750)
	# corrupt main -> backup used
	var f := FileAccess.open(_svc.path(), FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var d2: Dictionary = _svc.load_dict()
	assert_int(int(d2["wallet"]["credit"])).is_equal(500)
	assert_str(_svc.last_error).contains("backup")


func test_load_missing_returns_empty() -> void:
	assert_bool(_svc.load_dict().is_empty()).is_true()


func test_migrate_from_v0() -> void:
	var d := {"schema_version": 0, "wallet": {"credit": 3}}
	var m: Dictionary = _svc.migrate(d)
	assert_int(int(m["schema_version"])).is_equal(1)


func test_apply_run_and_bio() -> void:
	var r := RunResult.new()
	r.mission_id = &"m01"
	r.success = true
	r.kills = {&"drone": 10, &"runner": 5}
	r.credits_kept = 2300
	Profile.apply_run(r)
	assert_int(Profile.credits).is_equal(2300)
	assert_int(Profile.stats[&"kills"]).is_equal(15)
	assert_int(Profile.missions_cleared[&"m01"]).is_equal(1)
	assert_bool(Profile.upgrade_bio(Content.upgrade(&"torso"))).is_true()
	assert_int(Profile.credits).is_equal(500)
	var mods := Profile.bio_modifiers()
	assert_int(mods.size()).is_equal(1)
	var s := StatSheet.new()
	s.set_base(&"max_hp", 100.0)
	s.add_modifiers(mods)
	assert_float(s.get_stat(&"max_hp")).is_equal_approx(115.0, 0.001)
