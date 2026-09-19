## Ground splats (alien fluid) in one MultiMesh ring buffer. Pop-in scale,
## long fade. Oldest is overwritten when the buffer is full.
class_name DecalSystem
extends MultiMeshInstance3D

@export var capacity: int = 400
@export var life: float = 12.0
@export var fade_start: float = 8.0
@export var enabled: bool = true

var _pos: PackedVector3Array
var _size: PackedFloat32Array
var _rot: PackedFloat32Array
var _age: PackedFloat32Array
var _color: PackedColorArray
var _next := 0
var _buf: PackedFloat32Array
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 5
	_pos.resize(capacity); _size.resize(capacity); _rot.resize(capacity); _age.resize(capacity); _color.resize(capacity)
	_age.fill(life + 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	mm.mesh = quad
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://fx/decal.gdshader")
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_buf.resize(capacity * 20)


func splat(at: Vector3, size: float, color: Color) -> void:
	if not enabled:
		return
	var i := _next
	_next = (_next + 1) % capacity
	_pos[i] = Vector3(at.x + _rng.randf_range(-0.2, 0.2), 0.02, at.z + _rng.randf_range(-0.2, 0.2))
	_size[i] = size * _rng.randf_range(0.8, 1.3)
	_rot[i] = _rng.randf_range(0.0, TAU)
	_age[i] = 0.0
	_color[i] = color


func step(dt: float) -> void:
	var k := 0
	for i: int in range(capacity):
		if _age[i] >= life:
			continue
		_age[i] += dt
		var a := _age[i]
		var grow := clampf(a / 0.08, 0.0, 1.0)
		var s := _size[i] * (0.5 + 0.5 * grow)
		var alpha := 1.0 if a < fade_start else 1.0 - (a - fade_start) / (life - fade_start)
		var c := cos(_rot[i]) * s
		var sn := sin(_rot[i]) * s
		var p := _pos[i]
		var o := k * 20
		_buf[o + 0] = c;   _buf[o + 1] = 0.0; _buf[o + 2] = -sn; _buf[o + 3] = p.x
		_buf[o + 4] = 0.0; _buf[o + 5] = 1.0; _buf[o + 6] = 0.0; _buf[o + 7] = p.y
		_buf[o + 8] = sn;  _buf[o + 9] = 0.0; _buf[o + 10] = c;  _buf[o + 11] = p.z
		var col := _color[i]
		_buf[o + 12] = col.r; _buf[o + 13] = col.g; _buf[o + 14] = col.b; _buf[o + 15] = 1.0
		_buf[o + 16] = alpha; _buf[o + 17] = 0.0; _buf[o + 18] = 0.0; _buf[o + 19] = 0.0
		k += 1
	multimesh.visible_instance_count = k
	if k > 0:
		multimesh.buffer = _buf


func _process(delta: float) -> void:
	step(delta)
