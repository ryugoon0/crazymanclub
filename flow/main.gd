## Top-level flow: Base -> Mission -> Result -> Base. Loads/saves Profile.
## Contains no game rules.
class_name Main
extends Node

var _current: Node


func _ready() -> void:
	if not SaveService.load_profile():
		Profile.reset()
		SaveService.save_profile()
	Telemetry.log(&"session_start", {"credits": Profile.credits})
	show_base()


func _swap(to: Node) -> void:
	if _current != null:
		_current.queue_free()
	_current = to
	add_child(to)


func show_base() -> void:
	var base := BaseScreen.new()
	base.start_mission.connect(start_mission)
	_swap(base)


func start_mission(mission_id: StringName) -> void:
	var packed: PackedScene = load("res://flow/mission.tscn")
	var m: Mission = packed.instantiate()
	m.mission_data = Content.mission(mission_id)
	m.mission_ended.connect(on_mission_ended)
	_swap(m)


## Mission checks for this method to know it is not standalone.
func on_mission_ended(r: RunResult) -> void:
	# Let the last frame (death FX / extraction) show briefly, then result.
	await get_tree().create_timer(1.2).timeout
	var res := ResultScreen.new()
	res.continue_pressed.connect(show_base)
	_swap(res)
	res.show_result(r)
