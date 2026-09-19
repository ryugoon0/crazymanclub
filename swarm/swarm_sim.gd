## Central data-oriented simulation for regular enemies (decision L-A).
## No node per enemy. Arrays indexed by slot; free slots are recycled.
## Rendering (SwarmRenderer) and spawning (SwarmSpawner) are separate nodes
## that read/write this. Everything here is plain math so it is unit-testable
## by calling step(dt) directly.
class_name SwarmSim
extends Node

enum State { CHASE, WINDUP, COOLDOWN, STAGGER }

signal enemy_spawned(idx: int, type_idx: int)
signal enemy_killed(idx: int, type_idx: int, position: Vector3)
## Damage dealt to the player this frame by enemy `idx`.
signal player_hit(damage: float, from_position: Vector3)
## An enemy started its attack windup (telegraph / audio hook).
signal enemy_windup(idx: int, position: Vector3)

@export var capacity: int = 512
@export var types: Array[EnemyData] = []
@export var cell_size: float = 1.5
## Enemies closer than this to the player steer every frame.
@export var near_radius: float = 8.0
## Far enemies steer every N-th frame (spread across groups by index).
@export var far_tick_divisor: int = 4
@export var max_neighbors: int = 8
@export var max_concurrent_attackers: int = 8
@export var separation_strength: float = 6.0
@export var obstacle_strength: float = 8.0
@export var stagger_time: float = 0.15
@export var stagger_damping: float = 8.0
@export var flash_decay_per_s: float = 6.0
## Distance factor of attack_range at which an enemy stops pushing forward.
@export var arrive_factor: float = 0.9
## Grace factor on attack_range when the windup resolves.
@export var windup_reach_factor: float = 1.25
## Sideways steering bias (fraction of speed) so far enemies fan out instead
## of forming a conga line. Sign alternates by index; off inside melee range.
@export var tangential_bias: float = 0.35
@export var tangential_min_dist: float = 4.0

var player_pos: Vector3 = Vector3.ZERO
## Circular obstacles: x, z, radius.
var obstacles: PackedVector3Array = PackedVector3Array()

var pos: PackedVector3Array
var vel: PackedVector3Array
var hp: PackedFloat32Array
var type_idx: PackedInt32Array
var state: PackedByteArray
var timer: PackedFloat32Array
var flash: PackedFloat32Array
var alive: PackedByteArray

var alive_count: int = 0
var frame: int = 0
var grid: SpatialHash
## Profiling: microseconds spent in the last step().
var last_step_usec: int = 0
## Highest slot ever used + 1; loops stop here instead of at capacity.
var high_water: int = 0
var _free: PackedInt32Array
var _attackers: int = 0


func _init() -> void:
	grid = SpatialHash.new(cell_size)
	_allocate()


func _allocate() -> void:
	pos.resize(capacity)
	vel.resize(capacity)
	hp.resize(capacity)
	type_idx.resize(capacity)
	state.resize(capacity)
	timer.resize(capacity)
	flash.resize(capacity)
	alive.resize(capacity)
	alive.fill(0)
	_free.resize(capacity)
	for i: int in range(capacity):
		_free[i] = capacity - 1 - i
	alive_count = 0
	high_water = 0


func _physics_process(delta: float) -> void:
	step(delta)


func data_of(idx: int) -> EnemyData:
	return types[type_idx[idx]]


func spawn(p_type: int, at: Vector3) -> int:
	if _free.is_empty():
		return -1
	var idx := _free[_free.size() - 1]
	_free.resize(_free.size() - 1)
	var d := types[p_type]
	pos[idx] = Vector3(at.x, 0.0, at.z)
	vel[idx] = Vector3.ZERO
	hp[idx] = d.hp
	type_idx[idx] = p_type
	state[idx] = State.CHASE
	timer[idx] = 0.0
	flash[idx] = 0.0
	alive[idx] = 1
	alive_count += 1
	high_water = maxi(high_water, idx + 1)
	enemy_spawned.emit(idx, p_type)
	return idx


func kill(idx: int) -> void:
	if alive[idx] == 0:
		return
	alive[idx] = 0
	alive_count -= 1
	_free.append(idx)
	enemy_killed.emit(idx, type_idx[idx], pos[idx])


func clear() -> void:
	for i: int in range(high_water):
		alive[i] = 0
	_allocate()


## Returns true when the hit killed the enemy.
func apply_damage(idx: int, info: DamageInfo) -> bool:
	if alive[idx] == 0:
		return false
	hp[idx] -= info.amount
	flash[idx] = 1.0
	if info.knockback > 0.0:
		var d := data_of(idx)
		var dir := info.direction
		dir.y = 0.0
		vel[idx] += dir.normalized() * info.knockback * (1.0 - d.knockback_resist)
		state[idx] = State.STAGGER
		timer[idx] = stagger_time
	if hp[idx] <= 0.0:
		kill(idx)
		return true
	return false


## Hitscan: enemies whose XZ circle intersects the segment, nearest first.
func hitscan(from: Vector3, to: Vector3, ray_radius: float, max_hits: int = 1) -> PackedInt32Array:
	var candidates := grid.segment_candidates(from, to, ray_radius + 1.0)
	var dir := to - from
	dir.y = 0.0
	var length := dir.length()
	if length <= 0.0001:
		return PackedInt32Array()
	dir /= length
	var hits: Array[Vector2] = []  # x = t along ray, y = idx
	for j: int in candidates:
		if alive[j] == 0:
			continue
		var rel := pos[j] - from
		rel.y = 0.0
		var t := clampf(rel.dot(dir), 0.0, length)
		var closest := from + dir * t
		var dx := pos[j].x - closest.x
		var dz := pos[j].z - closest.z
		var reach := ray_radius + data_of(j).radius
		if dx * dx + dz * dz <= reach * reach:
			hits.append(Vector2(t, float(j)))
	hits.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var out := PackedInt32Array()
	for h: Vector2 in hits:
		out.append(int(h.y))
		if max_hits > 0 and out.size() >= max_hits:
			break
	return out


func step(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	frame += 1
	grid.rebuild(pos, alive, high_water)
	_attackers = 0
	for i: int in range(high_water):
		if alive[i] == 1 and state[i] == State.WINDUP:
			_attackers += 1

	for i: int in range(high_water):
		if alive[i] == 0:
			continue
		var d := types[type_idx[i]]
		var to_player := player_pos - pos[i]
		to_player.y = 0.0
		var dist := to_player.length()
		var near := dist < near_radius
		# Freshly spawned (or fully stopped) enemies steer immediately.
		var do_steer := near or ((frame + i) % far_tick_divisor == 0) or vel[i] == Vector3.ZERO

		match state[i]:
			State.STAGGER:
				timer[i] -= dt
				vel[i] = vel[i].move_toward(Vector3.ZERO, stagger_damping * dt * vel[i].length())
				if timer[i] <= 0.0:
					state[i] = State.CHASE
			State.WINDUP:
				timer[i] -= dt
				vel[i] = Vector3.ZERO
				if timer[i] <= 0.0:
					if dist <= d.attack_range * windup_reach_factor:
						player_hit.emit(d.damage, pos[i])
					state[i] = State.COOLDOWN
					timer[i] = d.attack_cooldown
			State.COOLDOWN:
				timer[i] -= dt
				if timer[i] <= 0.0:
					state[i] = State.CHASE
			State.CHASE:
				if dist <= d.attack_range and _attackers < max_concurrent_attackers:
					state[i] = State.WINDUP
					timer[i] = d.attack_windup
					_attackers += 1
					vel[i] = Vector3.ZERO
					enemy_windup.emit(i, pos[i])

		if do_steer and (state[i] == State.CHASE or state[i] == State.COOLDOWN):
			vel[i] = _steer(i, d, to_player, dist)

		if state[i] != State.WINDUP:
			pos[i] += vel[i] * dt
			_resolve_obstacles(i, d.radius)

		if flash[i] > 0.0:
			flash[i] = maxf(0.0, flash[i] - flash_decay_per_s * dt)

	last_step_usec = Time.get_ticks_usec() - t0


## Hard constraint: never end a frame inside an obstacle circle.
func _resolve_obstacles(i: int, radius: float) -> void:
	for o: Vector3 in obstacles:
		var dx := pos[i].x - o.x
		var dz := pos[i].z - o.y
		var reach := o.z + radius
		var l2 := dx * dx + dz * dz
		if l2 < reach * reach and l2 > 0.00000001:
			var l := sqrt(l2)
			pos[i].x = o.x + dx / l * reach
			pos[i].z = o.y + dz / l * reach


func _steer(i: int, d: EnemyData, to_player: Vector3, dist: float) -> Vector3:
	var desired := Vector3.ZERO
	if dist > d.attack_range * arrive_factor and dist > 0.0001:
		var fwd := to_player / dist
		desired = fwd * d.move_speed
		if dist > tangential_min_dist and tangential_bias > 0.0:
			var side := Vector3(-fwd.z, 0.0, fwd.x) * (1.0 if (i & 1) == 0 else -1.0)
			desired += side * d.move_speed * tangential_bias
			desired = desired.normalized() * d.move_speed

	var sep := Vector3.ZERO
	var r := d.radius * 2.0
	var near_idx := grid.neighbors(pos[i], r, pos, i, max_neighbors)
	for j: int in near_idx:
		var away := pos[i] - pos[j]
		away.y = 0.0
		var l := away.length()
		if l < 0.0001:
			# Exactly overlapping: deterministic push based on index parity.
			away = Vector3(1.0, 0.0, 0.0) if (i + j) % 2 == 0 else Vector3(0.0, 0.0, 1.0)
			l = 0.0001
		var overlap := (r - l) / r
		sep += away / l * overlap
	sep *= separation_strength

	# Obstacles: radial push plus a tangential slide toward the desired side,
	# so head-on approaches go around instead of stalling.
	var obst := Vector3.ZERO
	for o: Vector3 in obstacles:
		var away := Vector3(pos[i].x - o.x, 0.0, pos[i].z - o.y)
		var l := away.length()
		var reach := o.z + d.radius
		var influence := reach * 2.0
		if l < influence and l > 0.0001:
			var n := away / l
			var t := Vector3(-n.z, 0.0, n.x)
			if t.dot(desired) < 0.0:
				t = -t
			var w := clampf((influence - l) / reach, 0.0, 1.0)
			obst += (n + t) * w
	obst *= obstacle_strength

	var v := desired + sep + obst
	var max_speed := d.move_speed * 1.5
	if v.length() > max_speed:
		v = v.normalized() * max_speed
	return v
