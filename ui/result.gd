## Mission result screen.
class_name ResultScreen
extends Control

signal continue_pressed()

var _title: Label
var _body: Label
## One portrait + count per enemy type killed.
var _kills_box: HBoxContainer


func _ready() -> void:
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
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
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(header)
	header.add_child(Portraits.make_icon(&"player", 88, Color(1.0, 0.42, 0.12)))
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_title)
	_kills_box = HBoxContainer.new()
	_kills_box.add_theme_constant_override("separation", 18)
	_kills_box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_kills_box)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 20)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_body)
	var btn := Button.new()
	btn.text = "Return to base"
	btn.custom_minimum_size = Vector2(300, 48)
	btn.pressed.connect(func() -> void: continue_pressed.emit())
	box.add_child(btn)


## flow/main.gd swaps screens under a plain Node, so there is no parent Control
## to anchor against and PRESET_FULL_RECT alone leaves this at 0x0 — the
## background never draws and the CenterContainer centres inside zero width,
## pushing the widest line off the left edge. Take the size from the viewport.
func _fit_to_viewport() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func show_result(r: RunResult) -> void:
	_title.text = "EXTRACTED" if r.success else "MISSION FAILED"
	_title.modulate = Color(0.5, 1.0, 0.6) if r.success else Color(1.0, 0.45, 0.4)
	for c in _kills_box.get_children():
		c.queue_free()
	for k: StringName in r.kills:
		var e := Content.enemy(k)
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 2)
		card.add_child(Portraits.make_icon(k, 56, e.color if e != null else Color.GRAY))
		var count := Label.new()
		count.name = "Count"
		count.text = "%s %d" % [Names.display(e.display_name_key) if e != null else String(k), r.kills[k]]
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.add_theme_font_size_override("font_size", 14)
		card.add_child(count)
		_kills_box.add_child(card)
	_body.text = "%s\nkills %d · best combo x%d\ncredit +%d run%s → %d kept\ntime %d:%02d · damage dealt %.0f · taken %.0f\n%s" % [
		Names.display(Content.mission(r.mission_id).display_name_key) if Content.mission(r.mission_id) != null else String(r.mission_id),
		r.total_kills(), r.best_combo,
		r.credits_run, (" + %d bonus" % r.clear_bonus) if r.clear_bonus > 0 else "", r.credits_kept,
		int(r.duration_s) / 60, int(r.duration_s) % 60, r.damage_dealt, r.damage_taken,
		"boss killed" if r.boss_killed else "boss survived",
	]
