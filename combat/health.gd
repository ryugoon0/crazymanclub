## HP for node-based entities (player, boss). Regular enemies use SwarmSim.hp.
class_name Health
extends Node

signal damaged(info: DamageInfo, remaining: float)
signal died()

@export var max_hp: float = 100.0
@export var invulnerable: bool = false

var hp: float
var is_dead: bool = false


func _ready() -> void:
	hp = max_hp


func take(info: DamageInfo) -> void:
	if is_dead or invulnerable:
		return
	hp = maxf(0.0, hp - info.amount)
	damaged.emit(info, hp)
	if hp <= 0.0:
		is_dead = true
		died.emit()


func reset() -> void:
	hp = max_hp
	is_dead = false
