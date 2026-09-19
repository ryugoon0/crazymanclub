## One wave: which enemies, how many, how fast. Advances when everything has
## spawned and alive count drops to `advance_when_alive_below`, or after
## `max_duration` seconds (0 = never by time).
class_name WaveData
extends Resource

@export var enemy_ids: Array[StringName] = [&"drone"]
@export var counts: PackedInt32Array = PackedInt32Array([20])
@export var spawn_interval: float = 0.25
@export var advance_when_alive_below: int = 5
@export var max_duration: float = 0.0


func total() -> int:
	var n := 0
	for c: int in counts:
		n += c
	return n
