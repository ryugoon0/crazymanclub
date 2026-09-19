class_name TestSwarmSim
extends GdUnitTestSuite

const DT := 1.0 / 60.0


func _sim(capacity: int = 64) -> SwarmSim:
	var s: SwarmSim = auto_free(SwarmSim.new())
	s.capacity = capacity
	s._allocate()
	s.types = [load("res://data/enemies/drone.tres") as EnemyData]
	return s


func _run(s: SwarmSim, frames: int) -> void:
	for _i: int in range(frames):
		s.step(DT)


func test_spawn_kill_recycles_slots() -> void:
	var s := _sim(4)
	var a := s.spawn(0, Vector3(1, 0, 0))
	var b := s.spawn(0, Vector3(2, 0, 0))
	var c := s.spawn(0, Vector3(3, 0, 0))
	assert_int(a).is_equal(0)
	assert_int(b).is_equal(1)
	assert_int(c).is_equal(2)
	assert_int(s.alive_count).is_equal(3)
	s.kill(b)
	assert_int(s.alive_count).is_equal(2)
	assert_int(s.spawn(0, Vector3.ZERO)).is_equal(1)
	assert_int(s.spawn(0, Vector3.ZERO)).is_equal(3)
	assert_int(s.spawn(0, Vector3.ZERO)).is_equal(-1)
	assert_int(s.high_water).is_equal(4)


func test_seeks_player() -> void:
	var s := _sim()
	s.player_pos = Vector3.ZERO
	var i := s.spawn(0, Vector3(10, 0, 0))
	_run(s, 60)
	var d := s.pos[i].length()
	assert_float(d).is_less(10.0)
	# ~4.8 m/s for 1 s, stops at arrive distance
	assert_float(d).is_greater(1.0)
	assert_float(absf(s.pos[i].z)).is_less(0.01)


func test_arrives_and_attacks_after_windup() -> void:
	var s := _sim()
	s.player_pos = Vector3.ZERO
	var hits: Array[float] = []
	s.player_hit.connect(func(dmg: float, _p: Vector3) -> void: hits.append(dmg))
	s.spawn(0, Vector3(1.0, 0, 0))  # inside attack_range 1.4
	_run(s, 1)
	assert_int(s.state[0]).is_equal(SwarmSim.State.WINDUP)
	_run(s, 22)  # 0.35 s windup = 21 frames
	assert_int(hits.size()).is_equal(1)
	assert_float(hits[0]).is_equal_approx(14.0, 0.001)
	assert_int(s.state[0]).is_equal(SwarmSim.State.COOLDOWN)
	_run(s, 60)  # cooldown 1.0 s -> back to CHASE
	assert_int(hits.size()).is_equal(1)
	_run(s, 30)  # re-enter windup + resolve
	assert_int(hits.size()).is_equal(2)


func test_concurrent_attackers_capped() -> void:
	var s := _sim()
	s.max_concurrent_attackers = 3
	s.player_pos = Vector3.ZERO
	for k: int in range(10):
		var a := float(k) / 10.0 * TAU
		s.spawn(0, Vector3(cos(a), 0.0, sin(a)) * 1.0)
	_run(s, 1)
	var winding := 0
	for i: int in range(s.high_water):
		if s.state[i] == SwarmSim.State.WINDUP:
			winding += 1
	assert_int(winding).is_equal(3)


func test_separation_pushes_overlapping_apart() -> void:
	var s := _sim()
	s.player_pos = Vector3(0, 0, 100)  # far away, so seek barely matters over 30 frames
	var a := s.spawn(0, Vector3(5, 0, 5))
	var b := s.spawn(0, Vector3(5, 0, 5))
	_run(s, 30)
	var dist := (s.pos[a] - s.pos[b]).length()
	assert_float(dist).is_greater(0.5)


func test_obstacle_repels() -> void:
	var s := _sim()
	s.player_pos = Vector3.ZERO
	s.obstacles = PackedVector3Array([Vector3(5.0, 0.0, 2.0)])  # x=5, z=0, r=2
	var i := s.spawn(0, Vector3(10, 0, 0.3))
	var min_d := 1000.0
	for _k: int in range(180):
		s.step(DT)
		min_d = minf(min_d, Vector2(s.pos[i].x - 5.0, s.pos[i].z).length())
	# never inside the obstacle circle (+ own radius 0.45)
	assert_float(min_d).is_greater_equal(2.45 - 0.001)
	# and it still got around to the player
	assert_float(s.pos[i].length()).is_less(2.0)


func test_damage_knockback_and_kill() -> void:
	var s := _sim()
	var killed: Array[int] = []
	s.enemy_killed.connect(func(idx: int, _t: int, _p: Vector3) -> void: killed.append(idx))
	var i := s.spawn(0, Vector3(3, 0, 0))
	var hit := DamageInfo.make(22.0, Vector3(1, 0, 0), 2.0)
	assert_bool(s.apply_damage(i, hit)).is_false()
	assert_float(s.hp[i]).is_equal_approx(105.0 - 22.0, 0.001)
	assert_int(s.state[i]).is_equal(SwarmSim.State.STAGGER)
	assert_float(s.vel[i].x).is_greater(0.0)
	assert_float(s.flash[i]).is_equal_approx(1.0, 0.001)
	for _k: int in range(4):
		s.apply_damage(i, hit)
	# 5 hits x 22 = 110 >= 105
	assert_bool(s.alive[i] == 0).is_true()
	assert_array(killed).is_equal([i])
	assert_int(s.alive_count).is_equal(0)


func test_hitscan_nearest_first_and_penetration() -> void:
	var s := _sim()
	var far := s.spawn(0, Vector3(10, 0, 0))
	var near := s.spawn(0, Vector3(5, 0, 0.2))
	s.spawn(0, Vector3(7, 0, 3))  # off the ray
	s.step(DT)  # rebuild grid
	var one := s.hitscan(Vector3.ZERO, Vector3(40, 0, 0), 0.1, 1)
	assert_int(one.size()).is_equal(1)
	assert_int(one[0]).is_equal(near)
	var two := s.hitscan(Vector3.ZERO, Vector3(40, 0, 0), 0.1, 2)
	assert_array(Array(two)).is_equal([near, far])
	var short := s.hitscan(Vector3.ZERO, Vector3(4, 0, 0), 0.1, 0)
	assert_int(short.size()).is_equal(0)


func test_deterministic() -> void:
	var a := _sim()
	var b := _sim()
	for s: SwarmSim in [a, b]:
		s.player_pos = Vector3(1, 0, 2)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for _k: int in range(40):
			s.spawn(0, Vector3(rng.randf_range(-15, 15), 0, rng.randf_range(-15, 15)))
	_run(a, 120)
	_run(b, 120)
	for i: int in range(40):
		assert_vector(a.pos[i]).is_equal(b.pos[i])


func test_far_enemies_still_move_between_steer_ticks() -> void:
	var s := _sim()
	s.player_pos = Vector3.ZERO
	var i := s.spawn(0, Vector3(30, 0, 0))  # beyond near_radius
	_run(s, 1)
	var x1 := s.pos[i].x
	assert_float(x1).is_less(30.0)  # steers on its first frame
	_run(s, 1)
	var x2 := s.pos[i].x
	assert_float(x2).is_less(x1)  # keeps moving on non-steer frames
	_run(s, 1)
	assert_float(s.pos[i].x).is_less(x2)
