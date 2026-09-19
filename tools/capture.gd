## Runs a scene for N frames and saves a screenshot. Visual check under
## Xvfb + Mesa (software GL) where no real display exists:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##     --rendering-method gl_compatibility res://tools/capture.tscn -- --scene=res://flow/mission.tscn --frames=240
## Runs as a scene (not -s) so autoloads exist.
##
## Transient HUD states (the combo counter only shows while a streak is alive)
## cannot be caught by a fixed frame number, and with no input nothing is ever
## killed. --bot drives the player, --enemies fills the arena, and --on-combo
## waits for the state instead of guessing a frame:
##   godot --path . --resolution 1600x900 res://tools/capture.tscn -- \
##     --bot --enemies=120 --on-combo=3 --out=res://docs/shots/m1-combo.png
extends Node

var _frames := 0
var _at := 180
var _scene_path := "res://flow/mission.tscn"
var _out := "user://shots/capture.png"
## Drive the player with BotInput so kills actually happen.
var _bot := false
## Burst the swarm to this many enemies up front (0 = leave the scene alone).
var _enemies := 0
## Capture the first frame where the combo counter reads at least this (0 = off).
var _on_combo := 0
## Play a real mission to its end and capture the result screen instead.
var _on_result := false
## Mission to run for --on-result.
var _mission_id := &"m01"
## Engine.time_scale while playing. A full mission is ~185 s of game time.
var _speed := 1.0
## Give up waiting for --on-combo after this many frames and capture anyway.
var _timeout := 3600
var _mission: Mission
var _result_screen: ResultScreen
var _frames_on_result := 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			_scene_path = a.trim_prefix("--scene=")
		elif a.begins_with("--frames="):
			_at = int(a.trim_prefix("--frames="))
		elif a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--enemies="):
			_enemies = int(a.trim_prefix("--enemies="))
		elif a.begins_with("--on-combo="):
			_on_combo = int(a.trim_prefix("--on-combo="))
		elif a.begins_with("--timeout="):
			_timeout = int(a.trim_prefix("--timeout="))
		elif a.begins_with("--mission="):
			_mission_id = StringName(a.trim_prefix("--mission="))
		elif a.begins_with("--speed="):
			_speed = float(a.trim_prefix("--speed="))
		elif a == "--bot":
			_bot = true
		elif a == "--on-result":
			_on_result = true
			_bot = true
	var packed: PackedScene = load(_scene_path)
	var inst := packed.instantiate()
	_mission = inst as Mission
	if _mission != null and _on_result:
		# Mirror flow/main.gd: a real mission, then the real ResultScreen fed
		# the RunResult that mission actually produced. Must be set before
		# add_child, because Mission._ready reads it.
		_mission.mission_data = Content.mission(_mission_id)
		_mission.endless = false
		_mission.mission_ended.connect(_on_mission_ended)
	add_child(inst)
	if _mission != null and _bot:
		_install_bot()
	if _mission != null and _enemies > 0:
		_mission.spawner.target_count = _enemies
		_mission.spawner.spawn_interval = 0.0
		_mission.spawner.burst_to(_enemies)
	Engine.time_scale = _speed


func _install_bot() -> void:
	var bot := BotInput.new()
	bot.name = "BotInput"
	bot.sim = _mission.sim
	_mission.player.add_child(bot)
	_mission.player.input = bot
	_mission.player.health.invulnerable = true
	if not _on_result:
		return
	# BotInput only orbits and shoots the nearest swarm enemy. Finishing a real
	# mission also needs the boss as a target and a walk to the extraction
	# marker, exactly as tools/autoplay.gd wires them.
	_mission.director.boss_phase_started.connect(func() -> void: bot.boss_target = _mission.boss)
	_mission.director.extraction_opened.connect(func() -> void: bot.goal = _mission.extraction.global_position)


func _on_mission_ended(r: RunResult) -> void:
	Engine.time_scale = 1.0
	_mission.queue_free()
	_result_screen = ResultScreen.new()
	add_child(_result_screen)
	_result_screen.show_result(r)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames >= _timeout:
		_shoot("timeout")
		return
	if _on_result:
		# Give the screen a few frames to lay out before reading the viewport.
		if _result_screen != null and _result_screen.is_inside_tree():
			_frames_on_result += 1
			if _frames_on_result >= 10:
				_shoot("result screen")
		return
	if _on_combo > 0:
		if _mission == null:
			_shoot("no mission")
			return
		if _mission.combo.current >= _on_combo and _mission.combo.is_active(_mission.run_time):
			_shoot("combo x%d" % _mission.combo.current)
		return
	if _frames >= _at:
		_shoot("frame %d" % _frames)


func _shoot(why: String) -> void:
	set_process(false)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	var err := img.save_png(_out)
	var extra := ""
	if _result_screen != null:
		# A screen that does not fill the viewport is the failure mode this tool
		# exists to catch, so record the rect rather than leaving it to the eye.
		extra = " · result rect %s size %s · viewport %s" % [
			str(_result_screen.position), str(_result_screen.size), str(get_viewport().get_visible_rect().size)]
	print("CAPTURE %s (%s) -> %s (%dx%d, err %d)%s" % [
		_scene_path, why, ProjectSettings.globalize_path(_out), img.get_width(), img.get_height(), err, extra])
	get_tree().quit(0 if err == OK else 1)
