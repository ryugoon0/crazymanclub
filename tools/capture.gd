## Runs a scene for N frames and saves a screenshot. Visual check under
## Xvfb + Mesa (software GL) where no real display exists:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##     --rendering-method gl_compatibility res://tools/capture.tscn -- --scene=res://flow/mission.tscn --frames=240
## Runs as a scene (not -s) so autoloads exist.
extends Node

var _frames := 0
var _at := 180
var _scene_path := "res://flow/mission.tscn"
var _out := "user://shots/capture.png"


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			_scene_path = a.trim_prefix("--scene=")
		elif a.begins_with("--frames="):
			_at = int(a.trim_prefix("--frames="))
		elif a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	var packed: PackedScene = load(_scene_path)
	add_child(packed.instantiate())


func _process(_delta: float) -> void:
	_frames += 1
	if _frames < _at:
		return
	set_process(false)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	var err := img.save_png(_out)
	print("CAPTURE %s -> %s (%dx%d, err %d)" % [_scene_path, ProjectSettings.globalize_path(_out), img.get_width(), img.get_height(), err])
	get_tree().quit(0)
