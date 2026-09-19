## Credit pickups in one MultiMesh. Magnet toward the player, collect on
## contact. Ring buffer; the oldest is overwritten when full.
class_name PickupSystem
extends MultiMeshInstance3D

signal collected(value: int, position: Vector3)

@export var capacity: int = 512
@export var magnet_radius: float = 3.0
@export var collect_radius: float = 0.8
@export var magnet_speed: float = 12.0
@export var color: Color = Color(1.0, 0.82, 0.25)
@export var size: float = 0.28

var player_pos: Vector3 = Vector3.ZERO
var _pos: PackedVector3Array
var _value: PackedInt32Array
var _age: PackedFloat32Array
var _alive: PackedByteArray
var _next := 0
var _buf: PackedFloat32Array
var _live := 0


func _ready() -> void:
	_pos.resize(capacity); _value.resize(capacity); _age.resize(capacity); _alive.resize(capacity)
	_alive.fill(0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE * size
	mm.mesh = box
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://fx/debris.gdshader")
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_buf.resize(capacity * 20)
	var eco := Content.economy_data()
	magnet_radius = eco.pickup_magnet_radius
	collect_radius = eco.pickup_collect_radius
	magnet_speed = eco.pickup_magnet_speed


func drop(at: Vector3, value: int) -> void:
	if value <= 0:
		return
	var i := _next
	_next = (_next + 1) % capacity
	_pos[i] = Vector3(at.x, 0.0, at.z)
	_value[i] = value
	_age[i] = 0.0
	_alive[i] = 1


func live_count() -> int:
	return _live


func step(dt: float) -> void:
	var k := 0
	var mr2 := magnet_radius * magnet_radius
	var cr2 := collect_radius * collect_radius
	for i: int in range(capacity):
		if _alive[i] == 0:
			continue
		_age[i] += dt
		var p := _pos[i]
		var dx := player_pos.x - p.x
		var dz := player_pos.z - p.z
		var d2 := dx * dx + dz * dz
		if d2 <= cr2:
			_alive[i] = 0
			collected.emit(_value[i], p)
			continue
		if d2 <= mr2:
			var d := sqrt(d2)
			var pull := magnet_speed * (1.5 - d / magnet_radius)
			p.x += dx / d * pull * dt
			p.z += dz / d * pull * dt
			_pos[i] = p
		var o := k * 20
		var ang := _age[i] * 3.0
		var c := cos(ang) * 0.7071
		var s := sin(ang) * 0.7071
		var y := 0.35 + sin(_age[i] * 4.0) * 0.06
		# 45° tilt around X then spin around Y (gem look)
		_buf[o + 0] = c;   _buf[o + 1] = -s * 0.7071; _buf[o + 2] = s * 0.7071;  _buf[o + 3] = p.x
		_buf[o + 4] = 0.0; _buf[o + 5] = 0.7071;      _buf[o + 6] = 0.7071;      _buf[o + 7] = y
		_buf[o + 8] = -s;  _buf[o + 9] = -c * 0.7071; _buf[o + 10] = c * 0.7071; _buf[o + 11] = p.z
		_buf[o + 12] = color.r; _buf[o + 13] = color.g; _buf[o + 14] = color.b; _buf[o + 15] = 1.0
		_buf[o + 16] = 1.0; _buf[o + 17] = 0.0; _buf[o + 18] = 0.0; _buf[o + 19] = 0.0
		k += 1
	_live = k
	multimesh.visible_instance_count = k
	if k > 0:
		multimesh.buffer = _buf


func _physics_process(delta: float) -> void:
	step(delta)
