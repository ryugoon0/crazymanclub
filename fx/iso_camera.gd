## Fixed-angle isometric camera: follows target with look-ahead toward aim,
## trauma-based shake (shake = trauma^2). Angle/offset are data.
class_name IsoCamera
extends Camera3D

@export var target: Node3D
@export var offset: Vector3 = Vector3(14.0, 20.0, 14.0)
@export var follow_speed: float = 8.0
@export var look_ahead: float = 2.0
@export var max_shake_offset: float = 0.35
@export var trauma_decay: float = 1.8

var aim_dir: Vector2 = Vector2.ZERO
var trauma: float = 0.0
var _focus: Vector3 = Vector3.ZERO
var _noise_t := 0.0


func _ready() -> void:
	if target != null:
		_focus = target.global_position
		_snap()


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	if target == null:
		return
	var want := target.global_position + Vector3(aim_dir.x, 0.0, aim_dir.y) * look_ahead
	_focus = _focus.lerp(want, 1.0 - exp(-follow_speed * delta))
	trauma = maxf(0.0, trauma - trauma_decay * delta)
	_noise_t += delta * 30.0
	var shake := trauma * trauma * max_shake_offset
	var jitter := Vector3(sin(_noise_t * 1.3), cos(_noise_t * 1.7), sin(_noise_t * 0.9)) * shake
	global_position = _focus + offset + jitter
	look_at(_focus + jitter * 0.5, Vector3.UP)


func _snap() -> void:
	global_position = _focus + offset
	look_at(_focus, Vector3.UP)
