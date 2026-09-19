class_name TestWaveDirector
extends GdUnitTestSuite

const DT := 1.0 / 60.0


func _setup() -> Array:
	var sim: SwarmSim = auto_free(SwarmSim.new())
	sim.types = [Content.enemy(&"drone"), Content.enemy(&"runner"), Content.enemy(&"tank")]
	var sp: SwarmSpawner = auto_free(SwarmSpawner.new())
	sp.sim = sim
	sp.spawn_points = PackedVector3Array([Vector3(20, 0, 0)])
	sp.jitter = 0.0
	var d: WaveDirector = auto_free(WaveDirector.new())
	d.auto_step = false
	d.mission = Content.mission(&"m01")
	d.sim = sim
	d.spawner = sp
	sim.player_pos = Vector3(-100, 0, 0)  # far away: nobody arrives
	return [sim, sp, d]


func test_waves_spawn_interleaved_and_advance_on_clear() -> void:
	var s := _setup()
	var sim: SwarmSim = s[0]
	var d: WaveDirector = s[2]
	var started: Array[int] = []
	d.wave_started.connect(func(i: int, _t: int) -> void: started.append(i))
	d.start()
	assert_array(started).is_equal([0])
	var w0 := d.mission.waves[0]
	# spawn everything of wave 1
	for _k: int in range(int(w0.total() * w0.spawn_interval / DT) + 5):
		d.step(DT)
	assert_int(sim.alive_count).is_equal(w0.total())
	assert_int(d.wave_index).is_equal(0)
	# kill down to the threshold -> wave 2 starts
	var to_kill := w0.total() - w0.advance_when_alive_below
	var killed := 0
	for i: int in range(sim.high_water):
		if killed >= to_kill:
			break
		if sim.alive[i] == 1:
			sim.kill(i)
			killed += 1
	d.step(DT)
	assert_array(started).is_equal([0, 1])
	assert_int(d.phase).is_equal(WaveDirector.Phase.WAVES)


func test_mixed_wave_is_interleaved() -> void:
	var s := _setup()
	var sim: SwarmSim = s[0]
	var d: WaveDirector = s[2]
	d.start()
	# jump to wave 3 (drone, runner, tank)
	d.wave_index = 1
	d._next_wave()
	var first: Array[int] = []
	for _k: int in range(3):
		d._spawn_timer = 0.0
		d.step(DT)
	for i: int in range(sim.high_water):
		if sim.alive[i] == 1:
			first.append(sim.type_idx[i])
	assert_array(first).is_equal([0, 1, 2])


func test_boss_phase_reinforcements_and_extraction() -> void:
	var s := _setup()
	var sim: SwarmSim = s[0]
	var d: WaveDirector = s[2]
	var reinf: Array[int] = [0]
	var opened: Array[int] = [0]
	d.reinforcement_called.connect(func(_n: int) -> void: reinf[0] += 1)
	d.extraction_opened.connect(func() -> void: opened[0] += 1)
	d.start()
	d.wave_index = d.mission.waves.size() - 1
	d._next_wave()
	assert_int(d.phase).is_equal(WaveDirector.Phase.BOSS)
	for _k: int in range(int(12.5 / DT)):
		d.step(DT)
	assert_int(reinf[0]).is_equal(1)
	assert_int(sim.alive_count).is_greater_equal(1)
	d.boss_died()
	assert_int(d.phase).is_equal(WaveDirector.Phase.EXTRACTION)
	for _k: int in range(int(2.0 / DT)):
		d.step(DT)
	assert_int(opened[0]).is_equal(1)
