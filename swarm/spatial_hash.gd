## Uniform grid on the XZ plane for neighbour and segment queries over the
## swarm arrays. Rebuilt every physics frame (O(n)); queries are O(cells).
## Cells hold Array[int] on purpose: PackedInt32Array inside a Dictionary is
## copy-on-write, so in-place append would silently write to a copy.
class_name SpatialHash
extends RefCounted

var cell_size: float = 1.5
var _cells: Dictionary[Vector2i, Array] = {}


func _init(p_cell_size: float = 1.5) -> void:
	cell_size = p_cell_size


func key_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / cell_size), floori(p.z / cell_size))


func rebuild(pos: PackedVector3Array, alive: PackedByteArray, count: int) -> void:
	_cells.clear()
	for i: int in range(count):
		if alive[i] == 0:
			continue
		var k := key_of(pos[i])
		var cell: Array = _cells.get(k, [])
		if cell.is_empty():
			_cells[k] = cell
		cell.append(i)


func cell_count() -> int:
	return _cells.size()


## Indices within `radius` of `point` (XZ distance), excluding `exclude`.
## Stops after `max_n` results (0 = unlimited).
func neighbors(point: Vector3, radius: float, pos: PackedVector3Array, exclude: int = -1, max_n: int = 0) -> PackedInt32Array:
	var out := PackedInt32Array()
	var r2 := radius * radius
	var lo := key_of(Vector3(point.x - radius, 0.0, point.z - radius))
	var hi := key_of(Vector3(point.x + radius, 0.0, point.z + radius))
	for cy: int in range(lo.y, hi.y + 1):
		for cx: int in range(lo.x, hi.x + 1):
			var cell: Array = _cells.get(Vector2i(cx, cy), [])
			for j: int in cell:
				if j == exclude:
					continue
				var d := pos[j] - point
				if d.x * d.x + d.z * d.z <= r2:
					out.append(j)
					if max_n > 0 and out.size() >= max_n:
						return out
	return out


## Candidate indices in every cell the segment (widened by `radius`) touches.
## Exact hit test is the caller's job. Result is deduplicated.
func segment_candidates(from: Vector3, to: Vector3, radius: float) -> PackedInt32Array:
	var seen: Dictionary[int, bool] = {}
	var out := PackedInt32Array()
	var delta := to - from
	delta.y = 0.0
	var length := delta.length()
	var steps := maxi(1, ceili(length / (cell_size * 0.5)))
	var ring := ceili(radius / cell_size) + 1
	var visited: Dictionary[Vector2i, bool] = {}
	for s: int in range(steps + 1):
		var p := from + delta * (float(s) / float(steps))
		var k := key_of(p)
		for oy: int in range(-ring, ring + 1):
			for ox: int in range(-ring, ring + 1):
				var ck := Vector2i(k.x + ox, k.y + oy)
				if visited.has(ck):
					continue
				visited[ck] = true
				var cell: Array = _cells.get(ck, [])
				for j: int in cell:
					if not seen.has(j):
						seen[j] = true
						out.append(j)
	return out
