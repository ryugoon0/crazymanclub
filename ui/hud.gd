class_name Hud
extends CanvasLayer

@onready var _hp: Label = %HpLabel
@onready var _ammo: Label = %AmmoLabel
@onready var _kills: Label = %KillsLabel
@onready var _perf: Label = %PerfLabel
@onready var _feel: Label = %FeelLabel
@onready var _objective: Label = %ObjectiveLabel
@onready var _credits: Label = %CreditsLabel
@onready var _boss: ProgressBar = %BossBar
@onready var _center: Label = %CenterLabel

var sim: SwarmSim
var kills: int = 0
var _frame_ms_avg := 16.7
var _center_t := 0.0


func set_hp(hp: float, max_hp: float) -> void:
	_hp.text = "HP %d / %d" % [roundi(hp), roundi(max_hp)]


func set_ammo(magazine: int, reserve: int) -> void:
	_ammo.text = "AMMO %d / %s" % [magazine, "∞" if reserve < 0 else str(reserve)]


func set_reloading(active: bool) -> void:
	if active:
		_ammo.text += "  RELOADING"


func set_objective(text: String) -> void:
	_objective.text = text


func set_credits(run_credits: int) -> void:
	_credits.text = "CREDIT +%d" % run_credits


func set_boss(hp: float, max_hp: float, visible_bar: bool = true) -> void:
	_boss.visible = visible_bar
	_boss.max_value = max_hp
	_boss.value = hp


func flash_center(text: String, seconds: float = 2.0) -> void:
	_center.text = text
	_center.visible = true
	_center_t = seconds


func set_feel(feel: Dictionary[StringName, bool]) -> void:
	var parts: PackedStringArray = []
	var keys: Array[Array] = [[&"hit_stop", "F1 hitstop"], [&"shake", "F2 shake"], [&"knockback", "F4 knockback"], [&"fx", "F5 fx"], [&"audio", "F6 audio"], [&"flash", "F7 flash"]]
	for k: Array in keys:
		parts.append("%s %s" % [k[1], "ON" if feel[k[0]] else "off"])
	_feel.text = " · ".join(parts)


func _process(delta: float) -> void:
	_frame_ms_avg = lerpf(_frame_ms_avg, delta * 1000.0, 0.05)
	var sim_ms := (sim.last_step_usec / 1000.0) if sim != null else 0.0
	var alive := sim.alive_count if sim != null else 0
	_kills.text = "KILLS %d   ENEMIES %d" % [kills, alive]
	_perf.text = "%.0f fps  frame %.2f ms  sim %.2f ms" % [Engine.get_frames_per_second(), _frame_ms_avg, sim_ms]
	if _center.visible:
		_center_t -= delta
		if _center_t <= 0.0:
			_center.visible = false
