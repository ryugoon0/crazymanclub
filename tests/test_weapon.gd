class_name TestWeapon
extends GdUnitTestSuite

const DT := 1.0 / 60.0


func _weapon() -> Weapon:
	var w: Weapon = auto_free(Weapon.new())
	w.setup(load("res://data/weapons/ar_basic.tres") as WeaponData, 3)
	return w


func test_fire_rate_matches_rpm() -> void:
	var w := _weapon()
	var shots: Array[int] = [0]
	w.fired.connect(func(_f: Vector3, _d: Vector3) -> void: shots[0] += 1)
	for _i: int in range(60):
		w.tick(DT, true, false, Vector3.ZERO, Vector3(1, 0, 0))
	# 600 rpm = 10/s; allow +-1 for frame quantisation
	assert_int(shots[0]).is_between(9, 11)
	assert_int(w.magazine).is_equal(30 - shots[0])


func test_empty_magazine_auto_reloads_with_infinite_reserve() -> void:
	var w := _weapon()
	var reloads: Array[int] = [0]
	w.reload_finished.connect(func() -> void: reloads[0] += 1)
	for _i: int in range(60 * 4):
		w.tick(DT, true, false, Vector3.ZERO, Vector3(1, 0, 0))
	# 30 rounds at 10/s = 3 s, then reload 1.6 s starts -> not finished at 4 s
	assert_int(reloads[0]).is_equal(0)
	assert_bool(w.reloading).is_true()
	for _i: int in range(60 * 2):
		w.tick(DT, true, false, Vector3.ZERO, Vector3(1, 0, 0))
	assert_int(reloads[0]).is_equal(1)
	assert_int(w.reserve).is_equal(-1)


func test_manual_reload_tops_up() -> void:
	var w := _weapon()
	for _i: int in range(30):
		w.tick(DT, true, false, Vector3.ZERO, Vector3(1, 0, 0))
	var before := w.magazine
	assert_int(before).is_less(30)
	w.tick(DT, false, true, Vector3.ZERO, Vector3(1, 0, 0))
	assert_bool(w.reloading).is_true()
	for _i: int in range(120):
		w.tick(DT, false, false, Vector3.ZERO, Vector3(1, 0, 0))
	assert_int(w.magazine).is_equal(30)


func test_owner_modifier_changes_damage() -> void:
	var w := _weapon()
	assert_float(w.stat(&"damage")).is_equal_approx(22.0, 0.001)
	w.add_modifiers([StatModifier.make(&"damage", StatModifier.Op.MUL, 1.1)])
	assert_float(w.stat(&"damage")).is_equal_approx(24.2, 0.001)


func test_hits_swarm_and_kills() -> void:
	var w := _weapon()
	var sim: SwarmSim = auto_free(SwarmSim.new())
	sim.types = [load("res://data/enemies/drone.tres") as EnemyData]
	w.sim = sim
	var i := sim.spawn(0, Vector3(6, 0, 0))
	sim.step(DT)
	var kills: Array[int] = [0]
	w.hit.connect(func(_p: Vector3, killed: bool) -> void: if killed: kills[0] += 1)
	# 105 hp / 22 = 5 shots -> at 10 shots/s, 0.6 s
	for _k: int in range(60):
		w.tick(DT, true, false, Vector3.ZERO, Vector3(1, 0, 0))
		sim.step(DT)
	assert_int(kills[0]).is_equal(1)
	assert_int(sim.alive[i]).is_equal(0)
