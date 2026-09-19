## Keeps `target_count` enemies alive by spawning at spawn points.
## M0-1: single type (index 0). Type weights come with M0-2.
class_name SwarmSpawner
extends Node

@export var sim: SwarmSim
@export var target_count: int = 30
@export var spawn_interval: float = 0.05
@export var spawn_points: PackedVector3Array = PackedVector3Array()
@export var jitter: float = 1.5
## Spawn type weights, parallel to sim.types. Empty = always type 0.
@export var type_weights: PackedFloat32Array = PackedFloat32Array()
@export var seed: int = 1
@export var enabled: bool = true

var _rng := RandomNumberGenerator.new()
var _timer := 0.0


func _ready() -> void:
	_rng.seed = seed


func _physics_process(delta: float) -> void:
	if not enabled or sim == null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	if sim.alive_count < target_count:
		spawn_one()
		_timer = spawn_interval


func spawn_one() -> int:
	if spawn_points.is_empty():
		return -1
	var at := spawn_points[_rng.randi_range(0, spawn_points.size() - 1)]
	at += Vector3(_rng.randf_range(-jitter, jitter), 0.0, _rng.randf_range(-jitter, jitter))
	return sim.spawn(_pick_type(), at)


## Immediately fill up to `count` (benchmark / wave bursts).
func burst_to(count: int) -> void:
	while sim.alive_count < count:
		if spawn_one() < 0:
			return


func _pick_type() -> int:
	if type_weights.is_empty() or type_weights.size() != sim.types.size():
		return 0
	var total := 0.0
	for w: float in type_weights:
		total += w
	var r := _rng.randf() * total
	for t: int in range(type_weights.size()):
		r -= type_weights[t]
		if r <= 0.0:
			return t
	return type_weights.size() - 1
