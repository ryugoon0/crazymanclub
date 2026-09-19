## Headless end-to-end run: bot player plays mission m01 to extraction.
##   godot --headless --path . --audio-driver Dummy res://tools/autoplay.tscn -- --speed=6 --timeout=400
## Exits 0 on success (extracted), 1 otherwise. Prints the RunResult.
extends Node

var _speed := 6.0
var _timeout := 400.0
var _elapsed := 0.0
var _dbg := 0.0
var mission: Mission
var bot: BotInput


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--speed="):
			_speed = float(a.trim_prefix("--speed="))
		elif a.begins_with("--timeout="):
			_timeout = float(a.trim_prefix("--timeout="))
	Profile.reset()
	SaveService.save_dir = "user://autoplay_saves"
	var packed: PackedScene = load("res://flow/mission.tscn")
	mission = packed.instantiate()
	mission.mission_ended.connect(_on_ended)
	add_child(mission)
	bot = BotInput.new()
	bot.name = "BotInput"
	bot.sim = mission.sim
	mission.player.add_child(bot)
	mission.player.input = bot
	mission.player.health.invulnerable = true
	mission.director.extraction_opened.connect(func() -> void:
		bot.goal = mission.extraction.global_position
		print("AUTOPLAY extraction open at %.1fs, goal %s, player %s" % [mission.run_time, str(bot.goal), str(mission.player.global_position)]))
	mission.director.wave_started.connect(func(i: int, t: int) -> void: print("AUTOPLAY wave %d/%d at %.1fs kills %d" % [i + 1, t, mission.run_time, mission.kills]))
	mission.director.boss_phase_started.connect(func() -> void:
		bot.boss_target = mission.boss
		print("AUTOPLAY boss at %.1fs kills %d" % [mission.run_time, mission.kills]))
	Engine.time_scale = _speed
	Engine.physics_ticks_per_second = int(60 * _speed)
	Engine.max_physics_steps_per_frame = int(8 * _speed) + 8


## Called by Mission when it has a parent with this method (non-standalone).
func on_mission_ended(_r: RunResult) -> void:
	pass


func _process(delta: float) -> void:
	_elapsed += delta / maxf(Engine.time_scale, 0.001)
	_dbg += delta / maxf(Engine.time_scale, 0.001)
	if bot.goal != Vector3.INF and _dbg > 3.0:
		_dbg = 0.0
		print("AUTOPLAY walking: player %s vel %s" % [str(mission.player.global_position), str(mission.player.velocity)])
	if _elapsed > _timeout:
		print("AUTOPLAY TIMEOUT after %.0fs wall · phase %d wave %d kills %d alive %d" % [_elapsed, mission.director.phase, mission.director.wave_index, mission.kills, mission.sim.alive_count])
		get_tree().quit(1)


func _on_ended(r: RunResult) -> void:
	Engine.time_scale = 1.0
	print("AUTOPLAY RESULT: %s" % JSON.stringify(r.to_dict()))
	print("AUTOPLAY profile credits %d runs %d cleared %s" % [Profile.credits, Profile.stats[&"runs"], str(Profile.missions_cleared)])
	print("AUTOPLAY save ok: %s (%s)" % [str(FileAccess.file_exists(SaveService.path())), SaveService.last_error])
	get_tree().quit(0 if r.success else 1)
