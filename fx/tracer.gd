## Hitscan tracers drawn with ImmediateMesh, fading over `life` seconds.
class_name Tracer
extends MeshInstance3D

@export var life: float = 0.06
@export var color: Color = Color(1.0, 0.85, 0.5, 1.0)

var _from: PackedVector3Array = []
var _to: PackedVector3Array = []
var _age: PackedFloat32Array = []
var _mesh := ImmediateMesh.new()


func _ready() -> void:
	mesh = _mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func add(from: Vector3, to: Vector3) -> void:
	_from.append(from)
	_to.append(to)
	_age.append(0.0)


func _process(delta: float) -> void:
	_mesh.clear_surfaces()
	if _from.is_empty():
		return
	var keep_from := PackedVector3Array()
	var keep_to := PackedVector3Array()
	var keep_age := PackedFloat32Array()
	for i: int in range(_from.size()):
		var a := _age[i] + delta
		if a >= life:
			continue
		keep_from.append(_from[i])
		keep_to.append(_to[i])
		keep_age.append(a)
	_from = keep_from
	_to = keep_to
	_age = keep_age
	if _from.is_empty():
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i: int in range(_from.size()):
		var c := color
		c.a = 1.0 - _age[i] / life
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(_from[i])
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(_to[i])
	_mesh.surface_end()
