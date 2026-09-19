## Headless smoke check. Run:
##   godot --headless --path . -s res://tools/smoke_check.gd
## Exits 0 when the project settings the M0 gate depends on are in place.
extends SceneTree


func _init() -> void:
	var failures: PackedStringArray = []
	var v := Engine.get_version_info()
	if v.major != 4 or v.minor != 7:
		failures.append("expected Godot 4.7.x, got %s" % v.string)
	if str(ProjectSettings.get_setting("physics/3d/physics_engine")) != "Jolt Physics":
		failures.append("physics engine is not Jolt")
	if str(ProjectSettings.get_setting("rendering/renderer/rendering_method")) != "forward_plus":
		failures.append("PC renderer is not forward_plus")
	for action in ["move_left", "move_right", "move_up", "move_down", "fire_primary", "dash", "reload", "aim_left", "aim_up"]:
		if not InputMap.has_action(action):
			failures.append("missing input action: %s" % action)
	if not ResourceLoader.exists("res://flow/mission.tscn"):
		failures.append("main scene missing")
	if not FileAccess.file_exists("res://addons/gdUnit4/plugin.cfg"):
		failures.append("GdUnit4 addon missing")
	print("godot   : %s" % v.string)
	print("cpu     : %s (%d threads)" % [OS.get_processor_name(), OS.get_processor_count()])
	print("physics : %s" % str(ProjectSettings.get_setting("physics/3d/physics_engine")))
	if failures.is_empty():
		print("SMOKE CHECK: OK")
		quit(0)
	else:
		for f in failures:
			printerr("SMOKE CHECK FAIL: %s" % f)
		quit(1)
