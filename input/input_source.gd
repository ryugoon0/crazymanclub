## Abstract input. Player reads only this. Implementations: DesktopInput
## (mouse/keyboard/gamepad, M0-1), TouchInput (M0.75), BotInput (benchmark).
class_name InputSource
extends Node

## Camera-relative movement on the XZ plane, length <= 1.
var move: Vector2 = Vector2.ZERO
## World-space XZ aim direction, unit length. Zero when no aim.
var aim_dir: Vector2 = Vector2.ZERO
## World-space aim point (mouse) when available.
var aim_world: Vector3 = Vector3.ZERO
var has_aim_world: bool = false
var fire: bool = false
var dash_pressed: bool = false
var reload_pressed: bool = false
var interact_pressed: bool = false
## Aim assist cone in degrees (0 = off). Set per input device.
var aim_assist_deg: float = 0.0


## Called by the player every physics frame before it acts.
func poll(_player_pos: Vector3, _camera: Camera3D) -> void:
	pass


## Camera-relative basis on the XZ plane: returns [forward, right].
static func camera_axes(camera: Camera3D) -> Array[Vector2]:
	if camera == null:
		return [Vector2(0, -1), Vector2(1, 0)]
	var f3 := -camera.global_transform.basis.z
	var f := Vector2(f3.x, f3.z)
	if f.length_squared() < 0.0001:
		f = Vector2(0, -1)
	f = f.normalized()
	var r := Vector2(-f.y, f.x)
	return [f, r]


static func to_world_xz(stick: Vector2, camera: Camera3D) -> Vector2:
	var axes := camera_axes(camera)
	# stick.y is +down on screen
	return axes[1] * stick.x + axes[0] * (-stick.y)
