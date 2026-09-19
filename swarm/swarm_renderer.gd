## Draws SwarmSim enemies with one MultiMeshInstance3D per enemy type.
## Writes the whole instance buffer once per frame (no per-instance calls).
class_name SwarmRenderer
extends Node3D

const FLOATS_PER_INSTANCE := 12 + 4 + 4  # transform + color + custom

@export var sim: SwarmSim
@export var shader: Shader = preload("res://swarm/enemy_multimesh.gdshader")
@export var default_height: float = 1.6
@export var flash_enabled: bool = true

var _mmi: Array[MultiMeshInstance3D] = []
var _buffers: Array[PackedFloat32Array] = []
var _heights: PackedFloat32Array = []


func _ready() -> void:
	# Parent (Mission) assigns `sim` after children are ready and calls _build().
	if sim != null:
		_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_mmi.clear()
	_buffers.clear()
	_heights.resize(sim.types.size())
	var mat := ShaderMaterial.new()
	mat.shader = shader
	for t: int in range(sim.types.size()):
		var d := sim.types[t]
		var mesh: Mesh = d.mesh
		var height := default_height * d.scale
		if mesh == null:
			var cap := CapsuleMesh.new()
			cap.radius = d.radius
			cap.height = height
			cap.radial_segments = 8
			cap.rings = 3
			mesh = cap
		_heights[t] = height
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = sim.capacity
		mm.visible_instance_count = 0
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "MM_%s" % String(d.id)
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_mmi.append(mmi)
		var buf := PackedFloat32Array()
		buf.resize(sim.capacity * FLOATS_PER_INSTANCE)
		_buffers.append(buf)


func _process(_delta: float) -> void:
	if sim == null or _mmi.is_empty():
		return
	var counts := PackedInt32Array()
	counts.resize(sim.types.size())
	counts.fill(0)
	var pos := sim.pos
	var vel := sim.vel
	var flash := sim.flash
	var state := sim.state
	var timer := sim.timer
	var alive := sim.alive
	var type_idx := sim.type_idx
	var stagger_time := sim.stagger_time
	for i: int in range(sim.high_water):
		if alive[i] == 0:
			continue
		var t := type_idx[i]
		var d := sim.types[t]
		var k := counts[t]
		counts[t] = k + 1
		var buf := _buffers[t]
		var o := k * FLOATS_PER_INSTANCE
		# Facing: along velocity when moving, otherwise keep identity.
		var v := vel[i]
		var fx := 1.0
		var fz := 0.0
		var l2 := v.x * v.x + v.z * v.z
		if l2 > 0.01:
			var inv := 1.0 / sqrt(l2)
			fx = v.x * inv
			fz = v.z * inv
		var s := d.scale
		var p := pos[i]
		var y := _heights[t] * 0.5
		# Row-major 3x4: basis.x, basis.y, basis.z columns per row + origin.
		buf[o + 0] = fx * s;  buf[o + 1] = 0.0; buf[o + 2] = -fz * s; buf[o + 3] = p.x
		buf[o + 4] = 0.0;     buf[o + 5] = s;   buf[o + 6] = 0.0;     buf[o + 7] = y
		buf[o + 8] = fz * s;  buf[o + 9] = 0.0; buf[o + 10] = fx * s; buf[o + 11] = p.z
		var c := d.color
		buf[o + 12] = c.r; buf[o + 13] = c.g; buf[o + 14] = c.b; buf[o + 15] = 1.0
		var squash := 0.0
		if state[i] == SwarmSim.State.STAGGER and stagger_time > 0.0:
			squash = clampf(timer[i] / stagger_time, 0.0, 1.0)
		elif state[i] == SwarmSim.State.WINDUP:
			squash = 0.5  # telegraph
		buf[o + 16] = flash[i] if flash_enabled else 0.0; buf[o + 17] = squash; buf[o + 18] = 0.0; buf[o + 19] = 0.0
	for t: int in range(_mmi.size()):
		var mm := _mmi[t].multimesh
		mm.visible_instance_count = counts[t]
		if counts[t] > 0:
			mm.buffer = _buffers[t]
