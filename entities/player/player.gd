## Player: move, dash, aim (with optional assist), fire the mounted weapon.
## Reads InputSource only. Talks to SwarmSim for aim assist and receives
## enemy hits through Mission wiring (sim.player_hit -> take_hit).
class_name Player
extends CharacterBody3D

signal dashed()

@export var move_speed: float = 6.0
@export var dash_speed: float = 14.0
@export var dash_time: float = 0.2
@export var dash_cooldown: float = 1.0
@export var turn_speed: float = 20.0
@export var muzzle_height: float = 1.0

var input: InputSource
var sim: SwarmSim
var stats := StatSheet.new()
var facing: Vector2 = Vector2(1, 0)
var dash_left: float = 0.0
var dash_cd_left: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO

@onready var health: Health = $Health
@onready var body: Node3D = $Body
@onready var weapon_mount: Node3D = $WeaponMount
@onready var muzzle_flash: MuzzleFlash = $Body/MuzzleFlash
@onready var camera: Camera3D = get_viewport().get_camera_3d()

var weapon: Weapon


func _ready() -> void:
	stats.set_base(&"move_speed", move_speed)
	stats.set_base(&"dash_cooldown", dash_cooldown)
	stats.set_base(&"max_hp", health.max_hp)
	if input == null:
		input = get_node_or_null("Input") as InputSource
	if weapon == null:
		weapon = weapon_mount.get_child(0) if weapon_mount.get_child_count() > 0 else null
	if weapon != null:
		weapon.sim = sim


func is_dashing() -> bool:
	return dash_left > 0.0


func take_hit(damage: float, from_position: Vector3) -> void:
	if is_dashing():
		return  # i-frames
	var dir := global_position - from_position
	health.take(DamageInfo.make(damage, dir.normalized(), 0.0, from_position))


func _physics_process(delta: float) -> void:
	if input == null:
		return
	input.poll(global_position, camera)

	dash_cd_left = maxf(0.0, dash_cd_left - delta)
	if input.dash_pressed and dash_cd_left <= 0.0 and not is_dashing():
		_dash_dir = input.move if input.move.length_squared() > 0.01 else facing
		_dash_dir = _dash_dir.normalized()
		dash_left = dash_time
		dash_cd_left = stats.get_stat(&"dash_cooldown")
		dashed.emit()

	var planar: Vector2
	if is_dashing():
		dash_left -= delta
		planar = _dash_dir * dash_speed
	else:
		planar = input.move * stats.get_stat(&"move_speed")
	velocity = Vector3(planar.x, 0.0, planar.y)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	move_and_slide()

	var aim := input.aim_dir
	if aim.length_squared() > 0.0001:
		aim = _assist(aim, input.aim_assist_deg)
		facing = aim
	elif input.move.length_squared() > 0.01:
		facing = input.move.normalized()
	var target_yaw := atan2(-facing.x, -facing.y)
	body.rotation.y = lerp_angle(body.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))

	if weapon != null:
		var from := global_position + Vector3(0.0, muzzle_height, 0.0) + Vector3(facing.x, 0.0, facing.y) * 0.6
		weapon.tick(delta, input.fire, input.reload_pressed, from, Vector3(facing.x, 0.0, facing.y))


## Snap aim toward the nearest enemy inside `cone_deg` (stick/touch only).
func _assist(aim: Vector2, cone_deg: float) -> Vector2:
	if cone_deg <= 0.0 or sim == null:
		return aim
	var best := aim
	var best_ang := deg_to_rad(cone_deg)
	var p := global_position
	for j: int in sim.grid.neighbors(p, 25.0, sim.pos):
		var d := Vector2(sim.pos[j].x - p.x, sim.pos[j].z - p.z)
		if d.length_squared() < 0.01:
			continue
		var ang := absf(aim.angle_to(d))
		if ang < best_ang:
			best_ang = ang
			best = d.normalized()
	return best
