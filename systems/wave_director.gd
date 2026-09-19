## Drives a MissionData through its waves, then the boss phase (periodic
## reinforcements), then extraction. Pure timing/state; Mission spawns the
## boss node and the extraction zone on the signals.
class_name WaveDirector
extends Node

enum Phase { IDLE, WAVES, BOSS, EXTRACTION, DONE }

signal wave_started(index: int, total: int)
signal boss_phase_started()
signal reinforcement_called(count: int)
signal extraction_opened()
signal completed()

var mission: MissionData
var sim: SwarmSim
var spawner: SwarmSpawner
## Set false to drive step() manually (tests).
@export var auto_step: bool = true

var phase: Phase = Phase.IDLE
var wave_index: int = -1
var wave_time: float = 0.0
var _queue: PackedInt32Array = PackedInt32Array()
var _spawn_timer: float = 0.0
var _interval: float = 0.25
var _reinforce_timer: float = 0.0
var _extraction_timer: float = -1.0


func start() -> void:
	phase = Phase.WAVES
	wave_index = -1
	_next_wave()


func _physics_process(delta: float) -> void:
	if auto_step:
		step(delta)


func step(dt: float) -> void:
	match phase:
		Phase.WAVES:
			_step_spawning(dt)
			var w := mission.waves[wave_index]
			wave_time += dt
			var spawned_all := _queue.is_empty()
			var cleared := spawned_all and sim.alive_count <= w.advance_when_alive_below
			var timed_out := w.max_duration > 0.0 and wave_time >= w.max_duration
			if cleared or timed_out:
				_next_wave()
		Phase.BOSS:
			_step_spawning(dt)
			if mission.boss_reinforcement != null and mission.boss_reinforcement_interval > 0.0:
				_reinforce_timer -= dt
				if _reinforce_timer <= 0.0:
					_reinforce_timer = mission.boss_reinforcement_interval
					_enqueue(mission.boss_reinforcement)
					reinforcement_called.emit(mission.boss_reinforcement.total())
		Phase.EXTRACTION:
			if _extraction_timer >= 0.0:
				_extraction_timer -= dt
				if _extraction_timer < 0.0:
					_extraction_timer = -1.0
					extraction_opened.emit()
		_:
			pass


func _step_spawning(dt: float) -> void:
	if _queue.is_empty():
		return
	_spawn_timer -= dt
	while _spawn_timer <= 0.0 and not _queue.is_empty():
		var t := _queue[0]
		_queue.remove_at(0)
		spawner.spawn_type(t)
		_spawn_timer += _interval


func _next_wave() -> void:
	wave_index += 1
	wave_time = 0.0
	_queue.clear()  # a timed-out wave drops what it did not spawn
	if wave_index >= mission.waves.size():
		phase = Phase.BOSS
		_reinforce_timer = mission.boss_reinforcement_interval
		boss_phase_started.emit()
		return
	var w := mission.waves[wave_index]
	_interval = w.spawn_interval
	_spawn_timer = 0.0
	_enqueue(w)
	wave_started.emit(wave_index, mission.waves.size())


## Interleave the wave's entries so mixed waves arrive mixed, not in blocks.
func _enqueue(w: WaveData) -> void:
	var remaining := w.counts.duplicate()
	var types: PackedInt32Array = PackedInt32Array()
	for id: StringName in w.enemy_ids:
		types.append(type_index(id))
	var left := w.total()
	while left > 0:
		for k: int in range(types.size()):
			if remaining[k] > 0 and types[k] >= 0:
				_queue.append(types[k])
				remaining[k] -= 1
				left -= 1
			elif remaining[k] > 0:
				remaining[k] = 0
				left -= 1


func type_index(id: StringName) -> int:
	for t: int in range(sim.types.size()):
		if sim.types[t].id == id:
			return t
	push_warning("WaveDirector: enemy id %s not in sim.types" % String(id))
	return -1


## Called by Mission when the boss node dies.
func boss_died() -> void:
	if phase != Phase.BOSS:
		return
	phase = Phase.EXTRACTION
	_queue.clear()
	_extraction_timer = mission.extraction_delay


func complete() -> void:
	phase = Phase.DONE
	completed.emit()


func queued() -> int:
	return _queue.size()
