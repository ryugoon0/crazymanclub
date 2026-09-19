## Player projectiles (plasma bolts) in one MultiMesh. Swept hit tests
## against SwarmSim each frame, splash via query_circle, optional boss target.
class_name ProjectileSystem
extends MultiMeshInstance3D

signal hit(position: Vector3, killed: bool)

@export var capacity: int = 256

var sim: SwarmSim
## Optional node with segment_hit(from, to, r) -> bool and apply_damage(DamageInfo) -> bool.
var boss_target: Node

var _pos: PackedVector3Array
var _vel: PackedVector3Array
var _age: PackedFloat32Array
var _life: PackedFloat32Array
var _dmg: PackedFloat32Array
var _knock: PackedFloat32Array
var _splash_r: PackedFloat32Array
var _splash_dmg: PackedFloat32Array
var _radius: PackedFloat32Array
var _size: PackedFloat32Array
var _pen: PackedInt32Array
## Last swarm index this bolt damaged; skipped while still overlapping it.
var _last_hit: PackedInt32Array
var _color: PackedColorArray
var _alive: PackedByteArray
var _next := 0
var _live := 0
var _buf: PackedFloat32Array


func _ready() -> void:
	for a in [_pos, _vel]:
		a.resize(capacity)
	_age.resize(capacity); _life.resize(capacity); _dmg.resize(capacity); _knock.resize(capacity)
	_splash_r.resize(capacity); _splash_dmg.resize(capacity); _radius.resize(capacity); _size.resize(capacity)
	_pen.resize(capacity); _color.resize(capacity); _alive.resize(capacity); _last_hit.resize(capacity)
	_alive.fill(0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	sph.radial_segments = 8
	sph.rings = 4
	mm.mesh = sph
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://fx/projectile.gdshader")
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_buf.resize(capacity * 20)


func spawn(from: Vector3, dir: Vector3, data: ProjectileData, damage: float, knockback: float, penetration: int) -> void:
	var i := _next
	_next = (_next + 1) % capacity
	var d := Vector3(dir.x, 0.0, dir.z).normalized()
	_pos[i] = Vector3(from.x, from.y, from.z)
	_vel[i] = d * data.speed
	_age[i] = 0.0
	_life[i] = data.lifetime
	_dmg[i] = damage
	_knock[i] = knockback
	_splash_r[i] = data.splash_radius
	_splash_dmg[i] = data.splash_damage
	_radius[i] = data.radius
	_size[i] = data.size
	_pen[i] = penetration
	_last_hit[i] = -1
	_color[i] = data.color
	_alive[i] = 1


func live_count() -> int:
	return _live


func step(dt: float) -> void:
	var k := 0
	for i: int in range(capacity):
		if _alive[i] == 0:
			continue
		_age[i] += dt
		if _age[i] >= _life[i]:
			_alive[i] = 0
			continue
		var from := _pos[i]
		var to := from + _vel[i] * dt
		var dead := false
		if sim != null:
			var hits := sim.hitscan(from, to, _radius[i], _pen[i] + 2)
			for idx: int in hits:
				if idx == _last_hit[i]:
					continue
				_last_hit[i] = idx
				var info := DamageInfo.make(_dmg[i], _vel[i].normalized(), _knock[i], from)
				var hp := sim.pos[idx]
				var killed := sim.apply_damage(idx, info)
				hit.emit(Vector3(hp.x, 1.0, hp.z), killed)
				if _splash_r[i] > 0.0:
					_splash(hp, _splash_r[i], _splash_dmg[i], idx)
				_pen[i] -= 1
				if _pen[i] < 0:
					dead = true
					break
			if not dead:
				for o: Vector3 in sim.obstacles:
					var ox := to.x - o.x
					var oz := to.z - o.y
					if ox * ox + oz * oz < o.z * o.z:
						if _splash_r[i] > 0.0:
							_splash(to, _splash_r[i], _splash_dmg[i], -1)
						dead = true
						break
		if not dead and is_instance_valid(boss_target) and boss_target.has_method("segment_hit"):
			if boss_target.segment_hit(from, to, _radius[i]):
				var killed_boss: bool = boss_target.apply_damage(DamageInfo.make(_dmg[i] + _splash_dmg[i], _vel[i].normalized(), 0.0, from))
				hit.emit(Vector3(to.x, 1.0, to.z), killed_boss)
				dead = true
		if dead:
			_alive[i] = 0
			continue
		_pos[i] = to
		var o := k * 20
		var s := _size[i]
		_buf[o + 0] = s;   _buf[o + 1] = 0.0; _buf[o + 2] = 0.0; _buf[o + 3] = to.x
		_buf[o + 4] = 0.0; _buf[o + 5] = s;   _buf[o + 6] = 0.0; _buf[o + 7] = to.y
		_buf[o + 8] = 0.0; _buf[o + 9] = 0.0; _buf[o + 10] = s;  _buf[o + 11] = to.z
		var c := _color[i]
		_buf[o + 12] = c.r; _buf[o + 13] = c.g; _buf[o + 14] = c.b; _buf[o + 15] = 1.0
		_buf[o + 16] = 1.0; _buf[o + 17] = 0.0; _buf[o + 18] = 0.0; _buf[o + 19] = 0.0
		k += 1
	_live = k
	multimesh.visible_instance_count = k
	if k > 0:
		multimesh.buffer = _buf


func _splash(center: Vector3, r: float, dmg: float, exclude: int) -> void:
	for j: int in sim.grid.neighbors(center, r, sim.pos, exclude):
		if sim.alive[j] == 0:
			continue
		var dir := sim.pos[j] - center
		var killed := sim.apply_damage(j, DamageInfo.make(dmg, dir, 1.5, center))
		hit.emit(Vector3(sim.pos[j].x, 1.0, sim.pos[j].z), killed)


func _physics_process(delta: float) -> void:
	step(delta)
