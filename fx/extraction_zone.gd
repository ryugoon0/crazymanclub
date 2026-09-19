## Visible cylinder; Mission checks player distance. Placeholder.
class_name ExtractionZone
extends Node3D

@export var radius: float = 2.5

var _mesh: MeshInstance3D
var _t := 0.0


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.15
	_mesh.mesh = cyl
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.3, 0.9, 1.0, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh.material_override = m
	add_child(_mesh)
	visible = false


func contains(p: Vector3) -> bool:
	var dx := p.x - global_position.x
	var dz := p.z - global_position.z
	return dx * dx + dz * dz <= radius * radius


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_mesh.position.y = 0.1 + sin(_t * 3.0) * 0.05
	_mesh.rotation.y += delta
