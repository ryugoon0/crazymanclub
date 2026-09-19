## One damage event. Created by the attacker, consumed by Health / SwarmSim.
class_name DamageInfo
extends RefCounted

var amount: float = 0.0
var source_position: Vector3 = Vector3.ZERO
## Unit direction the damage travels (for knockback / blood direction).
var direction: Vector3 = Vector3.ZERO
var knockback: float = 0.0
var is_crit: bool = false


static func make(p_amount: float, p_direction: Vector3, p_knockback: float = 0.0, p_source: Vector3 = Vector3.ZERO) -> DamageInfo:
	var d := DamageInfo.new()
	d.amount = p_amount
	d.direction = p_direction
	d.knockback = p_knockback
	d.source_position = p_source
	return d
