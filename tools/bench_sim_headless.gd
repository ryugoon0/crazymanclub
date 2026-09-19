## Headless micro-benchmark of SwarmSim.step() alone (no rendering).
##   godot --headless --path . -s res://tools/bench_sim_headless.gd
## Early signal only: the real gate is the on-screen benchmark scene.
extends SceneTree

const COUNTS: Array[int] = [10, 30, 50, 100, 200, 300]
const FRAMES := 300


func _init() -> void:
	print("cpu: %s (%d threads)" % [OS.get_processor_name(), OS.get_processor_count()])
	print("count, avg_step_ms, max_step_ms, budget_share_60fps")
	var drone: EnemyData = load("res://data/enemies/drone.tres")
	for n: int in COUNTS:
		var sim := SwarmSim.new()
		sim.types = [drone]
		sim.obstacles = PackedVector3Array([Vector3(6, 0, 2), Vector3(-8, 4, 2.5), Vector3(0, -10, 3)])
		var rng := RandomNumberGenerator.new()
		rng.seed = 1234
		for _k: int in range(n):
			sim.spawn(0, Vector3(rng.randf_range(-25, 25), 0, rng.randf_range(-25, 25)))
		var total := 0
		var worst := 0
		for f: int in range(FRAMES):
			var t := float(f) / 60.0
			sim.player_pos = Vector3(cos(t) * 6.0, 0, sin(t * 0.7) * 6.0)
			sim.step(1.0 / 60.0)
			total += sim.last_step_usec
			worst = maxi(worst, sim.last_step_usec)
		var avg_ms := float(total) / FRAMES / 1000.0
		print("%d, %.3f, %.3f, %.0f%%" % [n, avg_ms, worst / 1000.0, avg_ms / 16.667 * 100.0])
		sim.free()
	quit(0)
