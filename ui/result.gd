## Mission result screen.
class_name ResultScreen
extends Control

signal continue_pressed()

var _title: Label
var _body: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.08, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 20)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_body)
	var btn := Button.new()
	btn.text = "Return to base"
	btn.custom_minimum_size = Vector2(300, 48)
	btn.pressed.connect(func() -> void: continue_pressed.emit())
	box.add_child(btn)


func show_result(r: RunResult) -> void:
	_title.text = "EXTRACTED" if r.success else "MISSION FAILED"
	_title.modulate = Color(0.5, 1.0, 0.6) if r.success else Color(1.0, 0.45, 0.4)
	var kills: PackedStringArray = []
	for k: StringName in r.kills:
		kills.append("%s %d" % [Names.display("ENEMY_%s_NAME" % String(k).to_upper()), r.kills[k]])
	_body.text = "%s\nkills %d  (%s) · best combo x%d\ncredit +%d run%s → %d kept\ntime %d:%02d · damage dealt %.0f · taken %.0f\n%s" % [
		Names.display(Content.mission(r.mission_id).display_name_key) if Content.mission(r.mission_id) != null else String(r.mission_id),
		r.total_kills(), ", ".join(kills), r.best_combo,
		r.credits_run, (" + %d bonus" % r.clear_bonus) if r.clear_bonus > 0 else "", r.credits_kept,
		int(r.duration_s) / 60, int(r.duration_s) % 60, r.damage_dealt, r.damage_taken,
		"boss killed" if r.boss_killed else "boss survived",
	]
