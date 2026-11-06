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
	assert_str(s._body.text).contains("kills 3")
	assert_str(s._body.text).contains("1:05")
	# per-type kill cards: portrait (or swatch) + "Drone 3"
	assert_int(s._kills_box.get_child_count()).is_equal(1)
	assert_str((s._kills_box.get_child(0).get_node("Count") as Label).text).is_equal("Drone 3")


func test_base_threat_intel_lists_mission_enemy_types_and_boss() -> void:
	var b: BaseScreen = auto_free(BaseScreen.new())
	add_child(b)
	# m01 fields drone/runner/tank across its waves plus the Broodmother.
	assert_int(b._intel_box.get_child_count()).is_equal(4)
	var names: PackedStringArray = []
	for card in b._intel_box.get_children():
		names.append((card.get_child(1) as Label).text)
	assert_array(names).contains(["Drone", "Runner", "Tank", "Broodmother"])
