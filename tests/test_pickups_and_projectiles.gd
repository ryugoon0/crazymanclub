class_name TestPickupsAndProjectiles
extends GdUnitTestSuite

const DT := 1.0 / 60.0


func test_pickup_magnet_and_collect() -> void:
	var p: PickupSystem = auto_free(PickupSystem.new())
	p.capacity = 16
	p._ready()
	var got: Array[int] = [0]
	p.collected.connect(func(v: int, _pos: Vector3) -> void: got[0] += v)
	p.player_pos = Vector3.ZERO
	p.drop(Vector3(2.0, 0, 0), 6)     # inside magnet radius 3
	p.drop(Vector3(20.0, 0, 0), 4)    # far
	for _k: int in range(120):
		p.step(DT)
	assert_int(got[0]).is_equal(6)
	assert_int(p.live_count()).is_equal(1)


func test_projectile_hits_and_splashes() -> void:
	var sim: SwarmSim = auto_free(SwarmSim.new())
	sim.types = [Content.enemy(&"drone")]
	var a := sim.spawn(0, Vector3(6, 0, 0))
	var b := sim.spawn(0, Vector3(6.8, 0, 1.0))   # within splash 1.8 of a
	var c := sim.spawn(0, Vector3(12, 0, 0))      # behind a, on the line
	sim.step(DT)
	var ps: ProjectileSystem = auto_free(ProjectileSystem.new())
	ps.capacity = 8
	ps._ready()
	ps.sim = sim
	var hits: Array[int] = [0]
	ps.hit.connect(func(_p: Vector3, _k: bool) -> void: hits[0] += 1)
	var bolt: ProjectileData = load("res://data/projectiles/plasma_bolt.tres")
	ps.spawn(Vector3(0, 1, 0), Vector3(1, 0, 0), bolt, 62.0, 3.0, 0)  # no penetration
	for _k: int in range(30):
		ps.step(DT)
		sim.step(DT)
	assert_float(sim.hp[a]).is_equal_approx(105.0 - 62.0, 0.001)
	assert_float(sim.hp[b]).is_equal_approx(105.0 - 28.0, 0.001)   # splash only
	assert_float(sim.hp[c]).is_equal_approx(105.0, 0.001)          # stopped at a
	assert_int(hits[0]).is_equal(2)
	assert_int(ps.live_count()).is_equal(0)


func test_projectile_penetrates_once() -> void:
	var sim: SwarmSim = auto_free(SwarmSim.new())
	sim.types = [Content.enemy(&"drone")]
	var a := sim.spawn(0, Vector3(6, 0, 0))
	var c := sim.spawn(0, Vector3(12, 0, 0))
	var far := sim.spawn(0, Vector3(20, 0, 0))
	sim.step(DT)
	var ps: ProjectileSystem = auto_free(ProjectileSystem.new())
	ps.capacity = 8
	ps._ready()
	ps.sim = sim
	var bolt := ProjectileData.new()
	bolt.speed = 28.0
	bolt.lifetime = 2.0
	bolt.radius = 0.25
	ps.spawn(Vector3(0, 1, 0), Vector3(1, 0, 0), bolt, 10.0, 0.0, 1)
	for _k: int in range(60):
		ps.step(DT)
		sim.step(DT)
	assert_float(sim.hp[a]).is_equal_approx(95.0, 0.001)
	assert_float(sim.hp[c]).is_equal_approx(95.0, 0.001)
	assert_float(sim.hp[far]).is_equal_approx(105.0, 0.001)


func test_projectile_dies_on_obstacle() -> void:
	var sim: SwarmSim = auto_free(SwarmSim.new())
	sim.types = [Content.enemy(&"drone")]
	sim.obstacles = PackedVector3Array([Vector3(5, 0, 1.5)])
	var behind := sim.spawn(0, Vector3(10, 0, 0))
	sim.step(DT)
	var ps: ProjectileSystem = auto_free(ProjectileSystem.new())
	ps.capacity = 8
	ps._ready()
	ps.sim = sim
	var bolt := ProjectileData.new()
	ps.spawn(Vector3(0, 1, 0), Vector3(1, 0, 0), bolt, 10.0, 0.0, 0)
	for _k: int in range(60):
		ps.step(DT)
	assert_float(sim.hp[behind]).is_equal_approx(105.0, 0.001)
	assert_int(ps.live_count()).is_equal(0)
