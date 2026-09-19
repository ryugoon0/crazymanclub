class_name TestUiScreens
extends GdUnitTestSuite


func before_test() -> void:
	Profile.reset()


func test_base_builds_and_reacts_to_profile() -> void:
	var b: BaseScreen = auto_free(BaseScreen.new())
	add_child(b)
	assert_int(b._weapons_box.get_child_count()).is_equal(3)
	assert_int(b._bio_box.get_child_count()).is_equal(3)
	Profile.add_credits(6000)
	assert_bool(Profile.buy_weapon(Content.weapon(&"shotgun"))).is_true()
	assert_str(String(Profile.equipped_weapon)).is_equal("shotgun")
	assert_str(b._credits.text).contains("500")


func test_result_shows_summary() -> void:
	var r := RunResult.new()
	r.mission_id = &"m01"
	r.success = true
	r.kills = {&"drone": 3}
	r.credits_run = 100
	r.clear_bonus = 600
	r.credits_kept = 700
	r.duration_s = 65.0
	var s: ResultScreen = auto_free(ResultScreen.new())
	add_child(s)
	s.show_result(r)
	assert_str(s._title.text).is_equal("EXTRACTED")
	assert_str(s._body.text).contains("Drone 3")
	assert_str(s._body.text).contains("1:05")
