## GdUnit4 smoke test: proves the test runner works on Godot 4.7.2 and that
## the project skeleton is wired. Real tests (SpatialHash, SwarmSim, StatSheet)
## are added in M0-1.
class_name TestProjectSkeleton
extends GdUnitTestSuite


func test_engine_version_is_4_7() -> void:
	var v := Engine.get_version_info()
	assert_int(v.major).is_equal(4)
	assert_int(v.minor).is_equal(7)


func test_physics_engine_is_jolt() -> void:
	assert_str(str(ProjectSettings.get_setting("physics/3d/physics_engine"))).is_equal("Jolt Physics")


func test_input_map_has_core_actions() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "fire_primary", "dash", "reload", "aim_left", "aim_right", "aim_up", "aim_down"]:
		assert_bool(InputMap.has_action(action)).override_failure_message("missing action %s" % action).is_true()


func test_events_autoload_present() -> void:
	var events: Node = Engine.get_main_loop().root.get_node_or_null("Events")
	assert_object(events).is_not_null()
	assert_bool(events.has_signal("enemy_killed")).is_true()


func test_main_scene_instantiates() -> void:
	var scene: PackedScene = load("res://flow/mission.tscn")
	assert_object(scene).is_not_null()
	var inst: Node = auto_free(scene.instantiate())
	assert_object(inst).is_not_null()
