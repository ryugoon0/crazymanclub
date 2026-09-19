## Benchmark bot: circles slowly, aims at the nearest enemy, always fires.
class_name BotInput
extends InputSource

@export var sim: SwarmSim
@export var orbit_speed: float = 0.4
@export var search_radius: float = 30.0

var _t := 0.0


func poll(player_pos: Vector3, _camera: Camera3D) -> void:
	_t += 1.0 / 60.0
	move = Vector2(cos(_t * orbit_speed), sin(_t * orbit_speed)) * 0.6
	fire = true
	reload_pressed = false
	dash_pressed = false
	aim_assist_deg = 0.0
	has_aim_world = false
	if sim == null:
		return
	var best := -1
	var best_d2 := search_radius * search_radius
	for j: int in sim.grid.neighbors(player_pos, search_radius, sim.pos):
		var d := sim.pos[j] - player_pos
		var d2 := d.x * d.x + d.z * d.z
		if d2 < best_d2:
			best_d2 = d2
			best = j
	if best >= 0:
		var d := sim.pos[best] - player_pos
		aim_dir = Vector2(d.x, d.z).normalized()
	elif aim_dir == Vector2.ZERO:
		aim_dir = Vector2(1, 0)
