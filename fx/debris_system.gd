## Pooled chunk debris (kill bursts) in one MultiMesh. Simple ballistic
## motion with ground bounce; instances shrink out over their life.
class_name DebrisSystem
extends MultiMeshInstance3D

@export var capacity: int = 800
@export var gravity: float = 22.0
@export var life: float = 1.4
@export var chunk_size: float = 0.18
@export var bounce: float = 0.35
@export var enabled: bool = true

var _pos: PackedVector3Array
var _vel: PackedVector3Array
var _age: PackedFloat32Array
var _color: PackedColorArray
var _spin: PackedFloat32Array
var _next := 0
var _live := 0
var _buf: PackedFloat32Array
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 99
	_pos.resize(capacity); _vel.resize(capacity); _age.resize(capacity); _color.resize(capacity); _spin.resize(capacity)
	_age.fill(life + 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE * chunk_size
	mm.mesh = box
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://fx/debris.gdshader")
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_buf.resize(capacity * 20)


func burst(at: Vector3, dir: Vector3, color: Color, count: int = 6, speed: float = 6.0) -> void:
	if not enabled:
		return
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length_squared() < 0.0001:
		d = Vector3.FORWARD
	d = d.normalized()
	for _k: int in range(count):
		var i := _next
		_next = (_next + 1) % capacity
		_pos[i] = at + Vector3(0.0, 0.6, 0.0)
		var spread := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.4, 1.4), _rng.randf_range(-1, 1))
		_vel[i] = (d * 0.7 + spread).normalized() * speed * _rng.randf_range(0.6, 1.3)
		_age[i] = 0.0
		_color[i] = color.darkened(_rng.randf_range(0.0, 0.35))
		_spin[i] = _rng.randf_range(-8.0, 8.0)


func step(dt: float) -> void:
	var k := 0
	for i: int in range(capacity):
		if _age[i] >= life:
			continue
		_age[i] += dt
		var v := _vel[i]
		v.y -= gravity * dt
		var p := _pos[i] + v * dt
		if p.y < chunk_size * 0.5:
			p.y = chunk_size * 0.5
			v.y = -v.y * bounce
			v.x *= 0.7
			v.z *= 0.7
		_pos[i] = p
		_vel[i] = v
		var o := k * 20
		var ang := _age[i] * _spin[i]
		var c := cos(ang)
		var s := sin(ang)
		_buf[o + 0] = c;   _buf[o + 1] = -s;  _buf[o + 2] = 0.0; _buf[o + 3] = p.x
		_buf[o + 4] = s;   _buf[o + 5] = c;   _buf[o + 6] = 0.0; _buf[o + 7] = p.y
		_buf[o + 8] = 0.0; _buf[o + 9] = 0.0; _buf[o + 10] = 1.0; _buf[o + 11] = p.z
		var col := _color[i]
		_buf[o + 12] = col.r; _buf[o + 13] = col.g; _buf[o + 14] = col.b; _buf[o + 15] = 1.0
		_buf[o + 16] = 1.0 - _age[i] / life; _buf[o + 17] = 0.0; _buf[o + 18] = 0.0; _buf[o + 19] = 0.0
		k += 1
	_live = k
	multimesh.visible_instance_count = k
	if k > 0:
		multimesh.buffer = _buf


func live_count() -> int:
	return _live


func _process(delta: float) -> void:
	step(delta)
