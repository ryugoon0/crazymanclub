class_name TestSpatialHash
extends GdUnitTestSuite


func _make_points(n: int, seed: int, extent: float) -> PackedVector3Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var p := PackedVector3Array()
	p.resize(n)
	for i: int in range(n):
		p[i] = Vector3(rng.randf_range(-extent, extent), 0.0, rng.randf_range(-extent, extent))
	return p


func _brute(point: Vector3, radius: float, pos: PackedVector3Array, alive: PackedByteArray, exclude: int) -> Array[int]:
	var out: Array[int] = []
	for j: int in range(pos.size()):
		if alive[j] == 0 or j == exclude:
			continue
		var d := pos[j] - point
		if d.x * d.x + d.z * d.z <= radius * radius:
			out.append(j)
	out.sort()
	return out


func test_neighbors_match_bruteforce() -> void:
	var n := 300
	var pos := _make_points(n, 42, 20.0)
	var alive := PackedByteArray()
	alive.resize(n)
	alive.fill(1)
	alive[5] = 0
	alive[77] = 0
	var grid := SpatialHash.new(1.5)
	grid.rebuild(pos, alive, n)
	for probe: int in [0, 10, 123, 299]:
		var got: Array[int] = []
		for j: int in grid.neighbors(pos[probe], 2.0, pos, probe):
			got.append(j)
		got.sort()
		assert_array(got).is_equal(_brute(pos[probe], 2.0, pos, alive, probe))


func test_neighbors_respects_max_n() -> void:
	var pos := PackedVector3Array()
	for i: int in range(20):
		pos.append(Vector3(0.1 * i, 0.0, 0.0))
	var alive := PackedByteArray()
	alive.resize(20)
	alive.fill(1)
	var grid := SpatialHash.new(1.5)
	grid.rebuild(pos, alive, 20)
	assert_int(grid.neighbors(Vector3.ZERO, 5.0, pos, -1, 4).size()).is_equal(4)


func test_segment_candidates_include_points_near_segment() -> void:
	var pos := PackedVector3Array([
		Vector3(5.0, 0.0, 0.2),   # on the ray
		Vector3(12.0, 0.0, -0.3), # on the ray
		Vector3(6.0, 0.0, 9.0),   # far off to the side
		Vector3(-4.0, 0.0, 0.0),  # behind
	])
	var alive := PackedByteArray([1, 1, 1, 1])
	var grid := SpatialHash.new(1.5)
	grid.rebuild(pos, alive, 4)
	var c := grid.segment_candidates(Vector3.ZERO, Vector3(20.0, 0.0, 0.0), 0.5)
	assert_bool(c.has(0)).is_true()
	assert_bool(c.has(1)).is_true()
	assert_bool(c.has(2)).is_false()
	assert_bool(c.has(3)).is_false()


func test_rebuild_skips_dead() -> void:
	var pos := PackedVector3Array([Vector3.ZERO, Vector3(0.2, 0.0, 0.0)])
	var alive := PackedByteArray([1, 0])
	var grid := SpatialHash.new(1.5)
	grid.rebuild(pos, alive, 2)
	assert_int(grid.neighbors(Vector3.ZERO, 1.0, pos).size()).is_equal(1)
