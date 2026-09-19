## Numeric stat change. This is the ONLY thing upgrades, affixes, difficulty
## modifiers and elite traits use to change numbers. Behavioural effects
## (explode on death, chain, spawn) are GameplayEffect, never a fake stat.
class_name StatModifier
extends Resource

enum Op { ADD, MUL, OVERRIDE }

@export var stat: StringName = &""
@export var op: Op = Op.ADD
@export var value: float = 0.0


static func make(p_stat: StringName, p_op: Op, p_value: float) -> StatModifier:
	var m := StatModifier.new()
	m.stat = p_stat
	m.op = p_op
	m.value = p_value
	return m
