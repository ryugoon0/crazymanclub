## On-screen benchmark (decision M). Runs the Mission scene with a bot player,
## fills the swarm to each count, measures, writes CSV to user://bench/.
##   godot --path . res://levels/benchmark.tscn -- --bench-fast --bench-quit
##
## Frame time is recorded two ways on purpose. `delta` from _process is the
## engine's smoothed value: its tail is censored (it pins at physics_step/12,
## i.e. 1.3889 ms = 720 fps at 60 Hz physics), so a "1% low" taken from it is
## not a frame time at all. `_wall` is raw Time.get_ticks_usec() and is the
## number to trust. Both are reported until the old column is retired.
class_name BenchRunner
extends Node

@export var counts: Array[int] = [10, 30, 50, 100, 200, 300]
@export var warmup_s: float = 5.0
@export var measure_s: float = 30.0

var mission: Mission
var _idx := -1
var _phase := 0  # 0 warmup, 1 measure, 2 done
var _t := 0.0
## Engine-supplied _process delta. Smoothed by the engine — tail is unusable.
var _frames: PackedFloat32Array = []
## Raw wall-clock frame times from Time.get_ticks_usec().
var _wall: PackedFloat32Array = []
var _last_us: int = 0
## Wall clock at the start of the measure window, to check the window length.
var _window_us: int = 0
## Last seen sim.frame, so each physics step is sampled exactly once.
var _last_sim_frame: int = -1
var _sim_us: PackedInt32Array = []
var _proc_ms: PackedFloat32Array = []
var _phys_ms: PackedFloat32Array = []
var _gpu_ms: PackedFloat32Array = []
var _draw_calls := 0
var _rows: Array[Dictionary] = []
var _quit_when_done := false
var _measure_gpu := false
## Directory to write bench_<stamp>.csv/.md into (project-relative allowed).
var _out_dir := "user://bench"
var _label := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--bench-fast"):
		warmup_s = 1.0
		measure_s = 2.0
	_quit_when_done = args.has("--bench-quit")
	for a: String in args:
		if a.begins_with("--bench-out="):
			_out_dir = a.trim_prefix("--bench-out=")
		elif a.begins_with("--bench-label="):
			_label = a.trim_prefix("--bench-label=")
		elif a.begins_with("--bench-counts="):
			var parsed: Array[int] = []
			for part: String in a.trim_prefix("--bench-counts=").split(",", false):
				parsed.append(int(part))
			if not parsed.is_empty():
				counts = parsed
	# VSync would cap avg fps at the refresh rate and hide the real headroom.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
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
	_wall.clear()
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
			_last_us = Time.get_ticks_usec()
			_window_us = _last_us
			_last_sim_frame = mission.sim.frame
		return
	var now := Time.get_ticks_usec()
	_wall.append(float(now - _last_us) / 1000000.0)
	_last_us = now
	_frames.append(delta)
	# last_step_usec only changes on a physics tick. Sampling it every render
	# frame would weight each step by how many frames happened to follow it,
	# and that count falls as load rises — a load-dependent bias.
	if mission.sim.frame != _last_sim_frame:
		_last_sim_frame = mission.sim.frame
		_sim_us.append(mission.sim.last_step_usec)
	# Performance.TIME_PROCESS / TIME_PHYSICS_PROCESS are republished once per
	# second holding that second's MAXIMUM, so averaging these samples yields
	# a mean of ~30 peaks, not a mean of frames. Hence the _peak column names.
	_proc_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_phys_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	if _measure_gpu:
		_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
	_draw_calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if _t >= measure_s:
		_record(counts[_idx])
		_next()


func _record(n: int) -> void:
	var wall_window_s := float(Time.get_ticks_usec() - _window_us) / 1000000.0
	var avg_dt := _avg(_frames)
	var avg_wall_dt := _avg(_wall)
	var row := {
		"enemies": n,
		"avg_fps": _fps(avg_dt),
		"avg_fps_wall": _fps(avg_wall_dt),
		"low1_fps": _low1_fps(_frames),
		"low1_wall_fps": _low1_fps(_wall),
		"frame_ms": avg_wall_dt * 1000.0,
		"max_frame_ms": _max(_wall) * 1000.0,
		"window_wall_s": wall_window_s,
		"main_ms_peak": _avg(_proc_ms),
		"sim_ms": _avg_i(_sim_us) / 1000.0,
		"physics_ms_peak": _avg(_phys_ms),
		"gpu_ms": _avg(_gpu_ms) if _measure_gpu else -1.0,
		"draw_calls": _draw_calls,
		"memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"ticks": _sim_us.size(),
		"alive": mission.sim.alive_count,
		"kills": mission.kills,
	}
	_rows.append(row)
	print("BENCH %3d enemies: avg %.1f fps (wall %.1f) · 1%% low wall %.1f fps (delta %.1f) · frame %.2f ms · max %.2f ms · window %.1f s · main peak %.2f ms · sim %.3f ms over %d ticks · phys peak %.2f ms · gpu %.2f ms · draw %d · mem %.0f MB" % [
		n, row.avg_fps, row.avg_fps_wall, row.low1_wall_fps, row.low1_fps, row.frame_ms, row.max_frame_ms,
		row.window_wall_s, row.main_ms_peak, row.sim_ms, row.ticks, row.physics_ms_peak, row.gpu_ms, row.draw_calls, row.memory_mb])


func _fps(dt: float) -> float:
	return 1.0 / maxf(dt, 0.000001)


## Mean of the worst 1% of samples, expressed as fps.
func _low1_fps(a: PackedFloat32Array) -> float:
	if a.is_empty():
		return 0.0
	var sorted := a.duplicate()
	sorted.sort()
	var worst_n := maxi(1, int(a.size() * 0.01))
	var worst_sum := 0.0
	for k: int in range(worst_n):
		worst_sum += sorted[sorted.size() - 1 - k]
	return _fps(worst_sum / worst_n)


func _max(a: PackedFloat32Array) -> float:
	var m := 0.0
	for v: float in a:
		m = maxf(m, v)
	return m


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
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var stamp := Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "").replace("T", "-")
	var base := _out_dir.path_join("bench_%s%s" % [stamp, ("_" + _label) if not _label.is_empty() else ""])
	var vp := get_viewport().get_visible_rect().size
	var hw := "godot %s · %s · cpu %s (%d threads) · gpu %s · renderer %s · %dx%d · physics %d Hz" % [
		Engine.get_version_info().string, OS.get_name(), OS.get_processor_name(), OS.get_processor_count(),
		RenderingServer.get_video_adapter_name(), str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
		int(vp.x), int(vp.y), int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"))]
	var gate_ok := false
	var gate_row: Dictionary = {}
	for r: Dictionary in _rows:
		if r.enemies == 200:
			gate_row = r
			gate_ok = r.avg_fps_wall >= 60.0 and r.low1_wall_fps >= 45.0
	var f := FileAccess.open(base + ".csv", FileAccess.WRITE)
	if f != null:
		f.store_line("# " + hw)
		f.store_line("enemies,avg_fps,avg_fps_wall,low1_fps,low1_wall_fps,frame_ms,max_frame_ms,window_wall_s,main_ms_peak,sim_ms,ticks,physics_ms_peak,gpu_ms,draw_calls,memory_mb,alive,kills")
		for r: Dictionary in _rows:
			f.store_line("%d,%.2f,%.2f,%.2f,%.2f,%.3f,%.3f,%.2f,%.3f,%.3f,%d,%.3f,%.3f,%d,%.1f,%d,%d" % [
				r.enemies, r.avg_fps, r.avg_fps_wall, r.low1_fps, r.low1_wall_fps, r.frame_ms, r.max_frame_ms,
				r.window_wall_s, r.main_ms_peak, r.sim_ms, r.ticks, r.physics_ms_peak, r.gpu_ms, r.draw_calls,
				r.memory_mb, r.alive, r.kills])
		f.close()
	var md := FileAccess.open(base + ".md", FileAccess.WRITE)
	if md != null:
		md.store_line("# Benchmark %s" % stamp)
		md.store_line("")
		md.store_line(hw)
		md.store_line("warmup %.0fs · measure %.0fs per count · vsync off" % [warmup_s, measure_s])
		md.store_line("")
		md.store_line("| enemies | avg fps | 1% low (wall) | frame ms | max ms | sim ms | ticks | gpu ms | draw calls | mem MB |")
		md.store_line("|---|---|---|---|---|---|---|---|---|---|")
		for r: Dictionary in _rows:
			md.store_line("| %d | %.1f | %.1f | %.2f | %.2f | %.3f | %d | %.2f | %d | %.0f |" % [
				r.enemies, r.avg_fps_wall, r.low1_wall_fps, r.frame_ms, r.max_frame_ms, r.sim_ms, r.ticks,
				r.gpu_ms, r.draw_calls, r.memory_mb])
		md.store_line("")
		md.store_line("Instrument check — the engine `delta` series is kept for one run to document the")
		md.store_line("artifact it produces. `low1 (delta)` is censored by engine frame-time smoothing and")
		md.store_line("is NOT a frame time; `main`/`physics` are Performance-monitor per-second maxima, not means.")
		md.store_line("")
		md.store_line("| enemies | avg fps (delta) | avg fps (wall) | 1% low (delta) | 1% low (wall) | window s | main ms peak | physics ms peak |")
		md.store_line("|---|---|---|---|---|---|---|---|")
		for r: Dictionary in _rows:
			md.store_line("| %d | %.1f | %.1f | %.1f | %.1f | %.1f | %.2f | %.2f |" % [
				r.enemies, r.avg_fps, r.avg_fps_wall, r.low1_fps, r.low1_wall_fps, r.window_wall_s,
				r.main_ms_peak, r.physics_ms_peak])
		md.store_line("")
		if not gate_row.is_empty():
			md.store_line("**GATE (200 enemies, avg ≥ 60, 1%% low ≥ 45, wall-clock): %s** — avg %.1f, 1%% low %.1f" % ["PASS" if gate_ok else "FAIL", gate_row.avg_fps_wall, gate_row.low1_wall_fps])
			md.store_line("")
			md.store_line("Gate criterion reads the wall-clock series (decision M amended 2026-09-19: the engine")
			md.store_line("delta series was a smoothed artifact, see docs/04-m0-status.md). Delta series for reference:")
			md.store_line("avg %.1f, 1%% low %.1f." % [gate_row.avg_fps, gate_row.low1_fps])
		md.close()
	print("BENCH DONE → %s" % ProjectSettings.globalize_path(base + ".md"))
	if not gate_row.is_empty():
		print("GATE (200 enemies, avg>=60, 1%% low>=45, wall-clock): %s — avg %.1f, 1%% low %.1f" % [
			"PASS" if gate_ok else "FAIL", gate_row.avg_fps_wall, gate_row.low1_wall_fps])
	if _quit_when_done:
		get_tree().quit(0)
