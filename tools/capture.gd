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
## Give up waiting for --on-combo after this many frames and capture anyway.
var _timeout := 3600
var _mission: Mission


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
		elif a == "--bot":
			_bot = true
	var packed: PackedScene = load(_scene_path)
	var inst := packed.instantiate()
	add_child(inst)
	_mission = inst as Mission
	if _mission != null and _bot:
		_install_bot()
	if _mission != null and _enemies > 0:
		_mission.spawner.target_count = _enemies
		_mission.spawner.spawn_interval = 0.0
		_mission.spawner.burst_to(_enemies)


func _install_bot() -> void:
	var bot := BotInput.new()
	bot.name = "BotInput"
	bot.sim = _mission.sim
	_mission.player.add_child(bot)
	_mission.player.input = bot
	_mission.player.health.invulnerable = true


func _process(_delta: float) -> void:
	_frames += 1
	if _frames >= _timeout:
		_shoot("timeout")
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
	print("CAPTURE %s (%s) -> %s (%dx%d, err %d)" % [
		_scene_path, why, ProjectSettings.globalize_path(_out), img.get_width(), img.get_height(), err])
	get_tree().quit(0 if err == OK else 1)
