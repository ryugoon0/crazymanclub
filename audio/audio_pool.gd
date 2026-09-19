## Fixed voice pool with priority stealing and per-sound concurrency caps
## (30 enemies dying at once must not open 30 voices). Non-positional in M0.
class_name AudioPool
extends Node

@export var voices: int = 24
@export var per_sound_cap: int = 3
## Minimum seconds between two plays of the same sound.
@export var min_interval: float = 0.02
@export var master_db: float = -6.0
@export var enabled: bool = true

var _players: Array[AudioStreamPlayer] = []
var _priority: PackedInt32Array = []
var _ids: Array[StringName] = []
## Busy flags kept by us: `playing` is unreliable on the dummy audio driver
## (headless/tests) and only flips after the mix thread starts.
var _busy: PackedByteArray = []
var _started: PackedFloat32Array = []
var _streams: Dictionary[StringName, AudioStream] = {}
var _gain_db: Dictionary[StringName, float] = {}
var _last_play: Dictionary[StringName, float] = {}
var stolen: int = 0
var dropped: int = 0


func _ready() -> void:
	for i: int in range(voices):
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		p.finished.connect(_on_finished.bind(i))
		_players.append(p)
		_priority.append(-1)
		_ids.append(&"")
		_busy.append(0)
		_started.append(0.0)


func _on_finished(i: int) -> void:
	_busy[i] = 0


func _is_busy(i: int, now: float) -> bool:
	if _busy[i] == 0:
		return false
	# Real driver: playing stays true until finished. Dummy driver: never
	# flips to playing, so release after a short grace period.
	return _players[i].playing or now - _started[i] < 0.1


func register(id: StringName, stream: AudioStream, gain_db: float = 0.0) -> void:
	_streams[id] = stream
	_gain_db[id] = gain_db


func register_dir(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f: String in d.get_files():
		if f.ends_with(".wav") or f.ends_with(".ogg"):
			register(StringName(f.get_basename()), load(dir.path_join(f)))


## Returns true when a voice was started.
func play(id: StringName, priority: int = 0, pitch_var: float = 0.08, gain_db: float = 0.0) -> bool:
	if not enabled or not _streams.has(id):
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if _last_play.has(id) and now - _last_play[id] < min_interval:
		dropped += 1
		return false
	var same := 0
	var free := -1
	var weakest := -1
	var weakest_pri := 1 << 30
	for i: int in range(_players.size()):
		if not _is_busy(i, now):
			if free < 0:
				free = i
			continue
		if _ids[i] == id:
			same += 1
		if _priority[i] < weakest_pri:
			weakest_pri = _priority[i]
			weakest = i
	if same >= per_sound_cap:
		dropped += 1
		return false
	var slot := free
	if slot < 0:
		if weakest >= 0 and weakest_pri < priority:
			slot = weakest
			stolen += 1
		else:
			dropped += 1
			return false
	var p := _players[slot]
	p.stream = _streams[id]
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.volume_db = master_db + _gain_db.get(id, 0.0) + gain_db
	p.play()
	_priority[slot] = priority
	_ids[slot] = id
	_busy[slot] = 1
	_started[slot] = now
	_last_play[id] = now
	return true


func active_voices() -> int:
	var now := Time.get_ticks_msec() / 1000.0
	var n := 0
	for i: int in range(_players.size()):
		if _is_busy(i, now):
			n += 1
	return n
