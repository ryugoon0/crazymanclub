## Base screen: shop (buy/equip), weapon upgrade, bio upgrades, start.
## Built in code from Content + Profile; refreshes on Profile.changed.
class_name BaseScreen
extends Control

signal start_mission(mission_id: StringName)

@export var mission_id: StringName = &"m01"

var _credits: Label
var _weapons_box: VBoxContainer
var _bio_box: VBoxContainer
var _stats: Label


func _ready() -> void:
	# See _fit_to_viewport: anchors alone leave this 0x0 under a plain Node
	# parent, which is why the background never drew.
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var title := Label.new()
	title.text = "XENO RECLAIMER — BASE"
	title.add_theme_font_size_override("font_size", 32)
	root.add_child(title)
	_credits = Label.new()
	_credits.add_theme_font_size_override("font_size", 22)
	_credits.modulate = Color(1, 0.85, 0.35)
	root.add_child(_credits)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 32)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	_weapons_box = _panel(cols, "WEAPONS")
	_bio_box = _panel(cols, "BIO AUGMENTATION")

	_stats = Label.new()
	_stats.modulate = Color(0.75, 0.75, 0.75)
	root.add_child(_stats)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	root.add_child(bottom)
	var start := Button.new()
	start.text = "DEPLOY — %s" % Names.display(Content.mission(mission_id).display_name_key)
	start.custom_minimum_size = Vector2(420, 48)
	start.pressed.connect(func() -> void: start_mission.emit(mission_id))
	bottom.add_child(start)
	var reset := Button.new()
	reset.text = "Reset save (debug)"
	reset.pressed.connect(func() -> void:
		Profile.reset()
		SaveService.save_profile())
	bottom.add_child(reset)

	Profile.changed.connect(refresh)
	refresh()


## flow/main.gd swaps screens under a plain Node, so there is no parent Control
## to anchor against and PRESET_FULL_RECT alone leaves this at 0x0. The content
## still lays out at its natural size from the origin, which is why this screen
## looked right, but the full-rect background never drew. Size to the viewport.
func _fit_to_viewport() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _panel(parent: Control, title_text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	parent.add_child(box)
	var t := Label.new()
	t.text = title_text
	t.add_theme_font_size_override("font_size", 20)
	box.add_child(t)
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 6)
	box.add_child(rows)
	return rows


func refresh() -> void:
	_credits.text = "CREDIT  %d" % Profile.credits
	_stats.text = "runs %d · kills %d · deaths %d · m01 cleared %d" % [
		Profile.stats.get(&"runs", 0), Profile.stats.get(&"kills", 0), Profile.stats.get(&"deaths", 0), Profile.missions_cleared.get(&"m01", 0)]
	for c in _weapons_box.get_children():
		c.queue_free()
	for c in _bio_box.get_children():
		c.queue_free()
	var track := Content.upgrade(&"weapon_track")
	for w: WeaponData in Content.weapons():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_weapons_box.add_child(row)
		var owned := Profile.owns_weapon(w.id)
		var lvl := Profile.weapon_level(w.id)
		var name := Label.new()
		name.custom_minimum_size.x = 220
		name.text = "%s%s" % [Names.display(w.display_name_key), ("  +%d" % lvl) if lvl > 0 else ""]
		if Profile.equipped_weapon == w.id:
			name.modulate = Color(1, 0.6, 0.4)
			name.text += "  [equipped]"
		row.add_child(name)
		var info := Label.new()
		info.custom_minimum_size.x = 260
		info.modulate = Color(0.7, 0.7, 0.7)
		info.text = "dmg %.0f · rpm %.0f · mag %d%s" % [w.damage * pow(1.1, lvl), w.rpm, w.magazine, (" · %d pellets" % w.pellets) if w.pellets > 1 else ""]
		row.add_child(info)
		var btn := Button.new()
		btn.custom_minimum_size.x = 150
		if not owned:
			btn.text = "Buy  %d" % w.price
			btn.disabled = not Profile.can_afford(w.price)
			btn.pressed.connect(func() -> void: Profile.buy_weapon(w))
		elif Profile.equipped_weapon != w.id:
			btn.text = "Equip"
			btn.pressed.connect(func() -> void: Profile.equip(w.id))
		else:
			btn.text = "Equipped"
			btn.disabled = true
		row.add_child(btn)
		var up := Button.new()
		up.custom_minimum_size.x = 150
		var cost := track.cost_for_next(lvl) if track != null else -1
		if owned and cost >= 0:
			up.text = "Upgrade  %d" % cost
			up.disabled = not Profile.can_afford(cost)
			up.pressed.connect(func() -> void: Profile.upgrade_weapon(w.id, track))
		else:
			up.text = "MAX" if owned else "—"
			up.disabled = true
		row.add_child(up)

	for slot: UpgradeData.Slot in [UpgradeData.Slot.ARMS, UpgradeData.Slot.LEGS, UpgradeData.Slot.TORSO]:
		for u: UpgradeData in Content.upgrades_in_slot(slot):
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			_bio_box.add_child(row)
			var lvl := Profile.bio_level(u.id)
			var name := Label.new()
			name.custom_minimum_size.x = 140
			name.text = "%s  Lv %d/%d" % [Names.display(u.display_name_key), lvl, u.max_level]
			row.add_child(name)
			var effects: PackedStringArray = []
			for m in u.modifiers_per_level:
				effects.append(Names.stat_label(m))
			var info := Label.new()
			info.custom_minimum_size.x = 260
			info.modulate = Color(0.7, 0.7, 0.7)
			info.text = " / ".join(effects) + " per level"
			row.add_child(info)
			var btn := Button.new()
			btn.custom_minimum_size.x = 150
			var cost := u.cost_for_next(lvl)
			if cost >= 0:
				btn.text = "Upgrade  %d" % cost
				btn.disabled = not Profile.can_afford(cost)
				btn.pressed.connect(func() -> void: Profile.upgrade_bio(u))
			else:
				btn.text = "MAX"
				btn.disabled = true
			row.add_child(btn)
