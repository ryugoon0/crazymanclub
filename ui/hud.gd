class_name Hud
extends CanvasLayer

@onready var _hp: Label = %HpLabel
@onready var _ammo: Label = %AmmoLabel
@onready var _kills: Label = %KillsLabel
@onready var _perf: Label = %PerfLabel

var sim: SwarmSim
var kills: int = 0
var _frame_ms_avg := 16.7


func set_hp(hp: float, max_hp: float) -> void:
	_hp.text = "HP %d / %d" % [roundi(hp), roundi(max_hp)]


func set_ammo(magazine: int, reserve: int) -> void:
	_ammo.text = "AMMO %d / %s" % [magazine, "∞" if reserve < 0 else str(reserve)]


func set_reloading(active: bool) -> void:
	if active:
		_ammo.text += "  RELOADING"


func _process(delta: float) -> void:
	_frame_ms_avg = lerpf(_frame_ms_avg, delta * 1000.0, 0.05)
	var sim_ms := (sim.last_step_usec / 1000.0) if sim != null else 0.0
	var alive := sim.alive_count if sim != null else 0
	_kills.text = "KILLS %d   ENEMIES %d" % [kills, alive]
	_perf.text = "%.0f fps  frame %.2f ms  sim %.2f ms" % [Engine.get_frames_per_second(), _frame_ms_avg, sim_ms]
