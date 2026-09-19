class_name TestBoss
extends GdUnitTestSuite


func _boss() -> Boss:
	var b: Boss = auto_free(Boss.new())
	b.data = Content.enemy(&"boss_broodmother")
	add_child(b)
	b.global_position = Vector3(10, 0, 0)
	return b


func test_segment_hit_geometry() -> void:
	var b := _boss()
	assert_bool(b.segment_hit(Vector3.ZERO, Vector3(20, 0, 0), 0.1)).is_true()
	assert_bool(b.segment_hit(Vector3.ZERO, Vector3(20, 0, 5), 0.1)).is_false()
	assert_bool(b.segment_hit(Vector3.ZERO, Vector3(5, 0, 0), 0.1)).is_false()  # too short


func test_damage_and_death_signal() -> void:
	var b := _boss()
	var died: Array[int] = [0]
	b.died.connect(func(_p: Vector3) -> void: died[0] += 1)
	assert_bool(b.apply_damage(DamageInfo.make(1000.0, Vector3.RIGHT))).is_false()
	assert_float(b.health.hp).is_equal_approx(5280.0 - 1000.0, 0.001)
	assert_bool(b.apply_damage(DamageInfo.make(5000.0, Vector3.RIGHT))).is_true()
	assert_int(died[0]).is_equal(1)
	assert_bool(b.segment_hit(Vector3.ZERO, Vector3(20, 0, 0), 0.1)).is_false()


func test_weapon_hits_boss_before_swarm_behind_it() -> void:
	var b := _boss()  # at x=10
	var sim: SwarmSim = auto_free(SwarmSim.new())
	sim.types = [Content.enemy(&"drone")]
	var behind := sim.spawn(0, Vector3(16, 0, 0))
	sim.step(1.0 / 60.0)
	var w: Weapon = auto_free(Weapon.new())
	w.setup(Content.weapon(&"ar_basic"), 1)
	w.sim = sim
	w.boss_target = b
	w.tick(1.0 / 60.0, true, false, Vector3(0, 1, 0), Vector3(1, 0, 0))
	assert_float(b.health.hp).is_equal_approx(5280.0 - 22.0, 0.001)
	assert_float(sim.hp[behind]).is_equal_approx(105.0, 0.001)
