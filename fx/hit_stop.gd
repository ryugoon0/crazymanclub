## Frame-quantised hit stop: scales Engine.time_scale down for N frames.
## Requests overlap by max, never sum. Runs even while time is scaled.
class_name HitStop
extends Node

@export var enabled: bool = true
@export var stopped_time_scale: float = 0.05

var _frames_left: int = 0
var _active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func request(frames: int) -> void:
	if not enabled or frames <= 0:
		return
	_frames_left = maxi(_frames_left, frames)
	if not _active:
		_active = true
		Engine.time_scale = stopped_time_scale


func _process(_delta: float) -> void:
	if not _active:
		return
	_frames_left -= 1
	if _frames_left <= 0:
		_active = false
		Engine.time_scale = 1.0


func _exit_tree() -> void:
	if _active:
		Engine.time_scale = 1.0
