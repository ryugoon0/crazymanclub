## On-screen benchmark (decision M). Runs the Mission scene with a bot player,
## fills the swarm to each count, measures, writes CSV to user://bench/.
##   godot --path . res://levels/benchmark.tscn -- --bench-fast --bench-quit
class_name BenchRunner
extends Node

@export var counts: Array[int] = [10, 30, 50, 100, 200, 300]
@export var warmup_s: float = 5.0
@export var measure_s: float = 30.0

var mission: Mission
var _idx := -1
var _phase := 0  # 0 warmup, 1 measure, 2 done
var _t := 0.0
var _frames: PackedFloat32Array = []
var _sim_us: PackedInt32Array = []
var _proc_ms: PackedFloat32Array = []
var _phys_ms: PackedFloat32Array = []
var _gpu_ms: PackedFloat32Array = []
var _draw_calls := 0
var _rows: Array[Dictionary] = []
var _quit_when_done := false
var _measure_gpu := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--bench-fast"):
		warmup_s = 1.0
		measure_s = 2.0
	_quit_when_done = args.has("--bench-quit")
	mission = get_parent().get_node("Mission") as Mission
	var bot := BotInput.new()
	bot.name = "BotInput"
	bot.sim = mission.sim
	mission.player.add_child(bot)
	mission.player.input = bot
	mission.player.health.invulnerable = true
	mission.spawner.spawn_interval = 0.0
	mission.feel[&"hit_stop"] = false
	mission._apply_feel()
	var rid := get_viewport().get_viewport_rid()
	if RenderingServer.has_method("viewport_set_measure_render_time"):
		RenderingServer.viewport_set_measure_render_time(rid, true)
		_measure_gpu = true
	print("BENCH start · cpu: %s · gpu: %s · counts: %s" % [OS.get_processor_name(), RenderingServer.get_video_adapter_name(), str(counts)])
	_next()


func _next() -> void:
	_idx += 1
	if _idx >= counts.size():
		_finish()
		return
	var n := counts[_idx]
	mission.spawner.target_count = n
	mission.spawner.burst_to(n)
	_phase = 0
	_t = 0.0
	_frames.clear()
	_sim_us.clear()
	_proc_ms.clear()
	_phys_ms.clear()
	_gpu_ms.clear()
	_draw_calls = 0


func _process(delta: float) -> void:
	if _phase == 2 or mission == null:
		return
	_t += delta
	if _phase == 0:
		if _t >= warmup_s:
			_phase = 1
			_t = 0.0
		return
	_frames.append(delta)
	_sim_us.append(mission.sim.last_step_usec)
	_proc_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_phys_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	if _measure_gpu:
		_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
	_draw_calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if _t >= measure_s:
		_record(counts[_idx])
		_next()


func _record(n: int) -> void:
	var sorted := _frames.duplicate()
	sorted.sort()
	var total := 0.0
	for f: float in _frames:
		total += f
	var avg_dt := total / maxf(1.0, _frames.size())
	var worst_n := maxi(1, int(_frames.size() * 0.01))
	var worst_sum := 0.0
	for k: int in range(worst_n):
		worst_sum += sorted[sorted.size() - 1 - k]
	var low1_dt := worst_sum / worst_n
	var row := {
		"enemies": n,
		"avg_fps": 1.0 / avg_dt,
		"low1_fps": 1.0 / low1_dt,
		"frame_ms": avg_dt * 1000.0,
		"main_thread_ms": _avg(_proc_ms),
		"sim_ms": _avg_i(_sim_us) / 1000.0,
		"physics_ms": _avg(_phys_ms),
		"gpu_ms": _avg(_gpu_ms) if _measure_gpu else -1.0,
		"draw_calls": _draw_calls,
		"memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"alive": mission.sim.alive_count,
		"kills": mission.kills,
	}
	_rows.append(row)
	print("BENCH %3d enemies: avg %.1f fps · 1%% low %.1f fps · frame %.2f ms · main %.2f ms · sim %.2f ms · phys %.2f ms · gpu %.2f ms · draw %d · mem %.0f MB" % [
		n, row.avg_fps, row.low1_fps, row.frame_ms, row.main_thread_ms, row.sim_ms, row.physics_ms, row.gpu_ms, row.draw_calls, row.memory_mb])


func _avg(a: PackedFloat32Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v: float in a:
		s += v
	return s / a.size()


func _avg_i(a: PackedInt32Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v: int in a:
		s += v
	return s / a.size()


func _finish() -> void:
	_phase = 2
	DirAccess.make_dir_recursive_absolute("user://bench")
	var path := "user://bench/bench_%d.csv" % Time.get_unix_time_from_system()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_line("# godot %s · cpu %s · gpu %s · %s" % [Engine.get_version_info().string, OS.get_processor_name(), RenderingServer.get_video_adapter_name(), Time.get_datetime_string_from_system()])
		f.store_line("enemies,avg_fps,low1_fps,frame_ms,main_thread_ms,sim_ms,physics_ms,gpu_ms,draw_calls,memory_mb,alive,kills")
		for r: Dictionary in _rows:
			f.store_line("%d,%.2f,%.2f,%.3f,%.3f,%.3f,%.3f,%.3f,%d,%.1f,%d,%d" % [r.enemies, r.avg_fps, r.low1_fps, r.frame_ms, r.main_thread_ms, r.sim_ms, r.physics_ms, r.gpu_ms, r.draw_calls, r.memory_mb, r.alive, r.kills])
		f.close()
		print("BENCH DONE → %s" % ProjectSettings.globalize_path(path))
	var gate_ok := false
	for r: Dictionary in _rows:
		if r.enemies == 200:
			gate_ok = r.avg_fps >= 60.0 and r.low1_fps >= 45.0
			print("GATE (200 enemies, avg>=60, 1%% low>=45): %s" % ("PASS" if gate_ok else "FAIL"))
	if _quit_when_done:
		get_tree().quit(0)
