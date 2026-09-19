## M0 skeleton: mission root. Only proves the project boots and reports the
## engine configuration. Real assembly (Level/Player/Swarm/HUD) arrives in M0-1.
extends Node3D

@onready var _label: Label = %InfoLabel


func _ready() -> void:
	var lines: PackedStringArray = [
		"XENO RECLAIMER — M0 skeleton",
		"Godot %s" % Engine.get_version_info().string,
		"renderer: %s" % str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
		"physics: %s" % str(ProjectSettings.get_setting("physics/3d/physics_engine")),
		"cpu: %s (%d threads)" % [OS.get_processor_name(), OS.get_processor_count()],
		"gpu: %s" % RenderingServer.get_video_adapter_name(),
	]
	var text := "\n".join(lines)
	_label.text = text
	print(text)
