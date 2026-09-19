## Mouse + keyboard + gamepad. The gamepad right stick overrides mouse aim
## while deflected; mouse motion hands control back. Aim assist applies
## only while the stick is in use (proxy for the touch stick, decision B/N).
class_name DesktopInput
extends InputSource

@export var stick_deadzone: float = 0.25
@export var stick_aim_assist_deg: float = 5.0
## Aim plane height (player chest).
@export var aim_plane_y: float = 1.0

var using_stick: bool = false
var _mouse_moved: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_moved = true


func poll(player_pos: Vector3, camera: Camera3D) -> void:
	var raw_move := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	move = InputSource.to_world_xz(raw_move, camera)
	if move.length_squared() > 1.0:
		move = move.normalized()

	var stick := Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down", stick_deadzone)
	if stick.length_squared() > 0.0:
		using_stick = true
	elif _mouse_moved:
		using_stick = false
	_mouse_moved = false

	if using_stick:
		var d := InputSource.to_world_xz(stick, camera)
		if d.length_squared() > 0.0:
			aim_dir = d.normalized()
		has_aim_world = false
		aim_assist_deg = stick_aim_assist_deg
		# Aim-to-fire: pushing the stick fires; trigger also fires.
		fire = stick.length_squared() > 0.0 or Input.is_action_pressed(&"fire_primary")
	else:
		aim_assist_deg = 0.0
		fire = Input.is_action_pressed(&"fire_primary")
		if camera != null:
			var vp := camera.get_viewport()
			var mouse := vp.get_mouse_position()
			var origin := camera.project_ray_origin(mouse)
			var normal := camera.project_ray_normal(mouse)
			var plane := Plane(Vector3.UP, aim_plane_y)
			var hit: Variant = plane.intersects_ray(origin, normal)
			if hit != null:
				aim_world = hit
				has_aim_world = true
				var d := Vector2(aim_world.x - player_pos.x, aim_world.z - player_pos.z)
				if d.length_squared() > 0.0001:
					aim_dir = d.normalized()

	dash_pressed = Input.is_action_just_pressed(&"dash")
	reload_pressed = Input.is_action_just_pressed(&"reload")
	interact_pressed = Input.is_action_just_pressed(&"interact")
