## Light + additive billboard shown for a couple of frames per shot.
class_name MuzzleFlash
extends Node3D

@export var frames: int = 2
@export var light_energy: float = 6.0
@export var enabled: bool = true

var _left := 0
var _light: OmniLight3D
var _quad: MeshInstance3D


func _ready() -> void:
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.8, 0.5)
	_light.omni_range = 5.0
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	add_child(_light)
	_quad = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	_quad.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.75, 0.35)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_quad.material_override = m
	_quad.visible = false
	add_child(_quad)


func flash() -> void:
	if not enabled:
		return
	_left = frames
	_light.light_energy = light_energy
	_quad.visible = true
	_quad.rotation.z = randf() * TAU


func _process(_delta: float) -> void:
	if _left <= 0:
		return
	_left -= 1
	_light.light_energy *= 0.5
	if _left <= 0:
		_light.light_energy = 0.0
		_quad.visible = false
