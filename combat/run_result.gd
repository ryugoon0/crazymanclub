## Structured outcome of one mission run. Persisted (last N) and the future
## input for rankings / server validation. Never trusted as-is later.
class_name RunResult
extends RefCounted

var mission_id: StringName = &""
var seed: int = 0
var success: bool = false
var ended_reason: StringName = &""  # &"extracted", &"died", &"aborted"
var duration_s: float = 0.0
var kills: Dictionary[StringName, int] = {}
var credits_run: int = 0
var clear_bonus: int = 0
var credits_kept: int = 0
var damage_dealt: float = 0.0
var damage_taken: float = 0.0
var weapon_id: StringName = &""
var weapon_level: int = 0
var boss_killed: bool = false
var ended_at_unix: int = 0


func total_kills() -> int:
	var n := 0
	for k: StringName in kills:
		n += kills[k]
	return n


func to_dict() -> Dictionary:
	var kd := {}
	for k: StringName in kills:
		kd[String(k)] = kills[k]
	return {
		"mission_id": String(mission_id), "seed": seed, "success": success, "ended_reason": String(ended_reason),
		"duration_s": duration_s, "kills": kd, "credits_run": credits_run, "clear_bonus": clear_bonus,
		"credits_kept": credits_kept, "damage_dealt": damage_dealt, "damage_taken": damage_taken,
		"weapon_id": String(weapon_id), "weapon_level": weapon_level, "boss_killed": boss_killed, "ended_at_unix": ended_at_unix,
	}
