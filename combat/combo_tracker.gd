## Tracks a kill streak: consecutive kills within `window` seconds keep the
## combo alive; a gap longer than that resets it. Time is supplied by the
## caller (mission run_time) so this stays deterministic and unit-testable
## without waiting on a real clock.
class_name ComboTracker
extends RefCounted

var window: float = 1.5

var current: int = 0
var best: int = 0
var _last_kill_t: float = -INF


func register_kill(t: float) -> void:
	if current > 0 and t - _last_kill_t <= window:
		current += 1
	else:
		current = 1
	_last_kill_t = t
	best = maxi(best, current)


## Call once per frame so an expired streak drops to 0 even without a new
## kill (otherwise it would only reset on the next kill).
func update(t: float) -> void:
	if current > 0 and t - _last_kill_t > window:
		current = 0


func is_active(t: float) -> bool:
	return current > 0 and t - _last_kill_t <= window
