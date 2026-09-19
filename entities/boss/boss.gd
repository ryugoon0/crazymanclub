## Node-based boss (decision L-A: complex entities stay nodes). Data from
## EnemyData; behaviours: chase, charge (telegraph 0.7 s), ground slam
## (telegraph 1.0 s, AoE), reinforcement calls come from WaveDirector.
class_name Boss
extends CharacterBody3D

enum State { CHASE, CHARGE_TELEGRAPH, CHARGE, SLAM_TELEGRAPH, SLAM_RECOVER, DEAD }

signal hit_player(damage: float, from_position: Vector3)
signal damaged(hp: float, max_hp: float)
signal died(position: Vector3)
signal telegraph(kind: StringName)

@export var data: EnemyData
@export var charge_cooldown: float = 6.0
@export var charge_telegraph: float = 0.7
@export var charge_speed: float = 14.0
@export var charge_duration: float = 0.6
@export var charge_damage: float = 25.0
@export var charge_knockback: float = 6.0
@export var slam_cooldown: float = 5.0
@export var slam_telegraph: float = 1.0
@export var slam_radius: float = 4.0
@export var slam_damage: float = 40.0
@export var slam_trigger_range: float = 3.5
@export var contact_range_pad: float = 0.6

var player: Node3D
var state: State = State.CHASE
var health: Health
var _timer := 0.0
var _charge_cd := 3.0
var _slam_cd := 4.0
var _charge_dir := Vector3.FORWARD
var _charge_hit := false
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _flash := 0.0
var _base_scale := Vector3.ONE


func _ready() -> void:
	collision_layer = 1 << 9
	collision_mask = 1
	wall_min_slide_angle = 0.0
	health = Health.new()
	health.name = "Health"
	health.max_hp = data.hp if data != null else 1000.0
	add_child(health)
	health.died.connect(_on_died)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = data.radius if data != null else 1.3
	cyl.height = 3.0
	shape.shape = cyl
	shape.position.y = 1.5
	add_child(shape)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = data.mesh if (data != null and data.mesh != null) else BoxMesh.new()
	_mesh.position.y = 1.5
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = data.color if data != null else Color.RED
	_mesh.material_override = _mat
	add_child(_mesh)
	_base_scale = _mesh.scale


func max_hp() -> float:
	return health.max_hp


## Circle (XZ) vs segment test for weapons/projectiles.
func segment_hit(from: Vector3, to: Vector3, ray_radius: float) -> bool:
	if state == State.DEAD:
		return false
	var d := to - from
	d.y = 0.0
	var l := d.length()
	if l < 0.0001:
		return false
	var dir := d / l
	var rel := global_position - from
	rel.y = 0.0
	var t := clampf(rel.dot(dir), 0.0, l)
	var closest := from + dir * t
	var dx := global_position.x - closest.x
	var dz := global_position.z - closest.z
	var reach := ray_radius + (data.radius if data != null else 1.3)
	return dx * dx + dz * dz <= reach * reach


func apply_damage(info: DamageInfo) -> bool:
	if state == State.DEAD:
		return false
	health.take(info)
	_flash = 1.0
	damaged.emit(health.hp, health.max_hp)
	return health.is_dead


func _on_died() -> void:
	state = State.DEAD
	died.emit(global_position)
	queue_free()


func _physics_process(delta: float) -> void:
	if player == null or state == State.DEAD:
		return
	_charge_cd -= delta
	_slam_cd -= delta
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	var dir := to_player / maxf(dist, 0.0001)
	var speed := data.move_speed if data != null else 2.4
	match state:
		State.CHASE:
			velocity = dir * speed if dist > 2.0 else Vector3.ZERO
			if _slam_cd <= 0.0 and dist <= slam_trigger_range:
				state = State.SLAM_TELEGRAPH
				_timer = slam_telegraph
				velocity = Vector3.ZERO
				telegraph.emit(&"slam")
			elif _charge_cd <= 0.0 and dist > 4.0 and dist < 18.0:
				state = State.CHARGE_TELEGRAPH
				_timer = charge_telegraph
				_charge_dir = dir
				velocity = Vector3.ZERO
				telegraph.emit(&"charge")
		State.CHARGE_TELEGRAPH:
			_timer -= delta
			_charge_dir = _charge_dir.lerp(dir, 0.1).normalized()
			if _timer <= 0.0:
				state = State.CHARGE
				_timer = charge_duration
				_charge_hit = false
		State.CHARGE:
			_timer -= delta
			velocity = _charge_dir * charge_speed
			if not _charge_hit and dist <= (data.radius if data != null else 1.3) + contact_range_pad:
				_charge_hit = true
				hit_player.emit(charge_damage, global_position)
			if _timer <= 0.0:
				state = State.CHASE
				_charge_cd = charge_cooldown
		State.SLAM_TELEGRAPH:
			_timer -= delta
			velocity = Vector3.ZERO
			if _timer <= 0.0:
				if dist <= slam_radius:
					hit_player.emit(slam_damage, global_position)
				state = State.SLAM_RECOVER
				_timer = 0.8
				_slam_cd = slam_cooldown
		State.SLAM_RECOVER:
			_timer -= delta
			velocity = Vector3.ZERO
			if _timer <= 0.0:
				state = State.CHASE
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	move_and_slide()
	# facing + telegraph visuals
	if dist > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 0.15)
	_flash = maxf(0.0, _flash - 6.0 * delta)
	var base := data.color if data != null else Color.RED
	var tele := state == State.CHARGE_TELEGRAPH or state == State.SLAM_TELEGRAPH
	_mat.albedo_color = base.lerp(Color.WHITE, _flash).lerp(Color(1.0, 0.9, 0.2), 0.6 if tele else 0.0)
	_mesh.scale = _base_scale * (Vector3(1.15, 0.85, 1.15) if state == State.SLAM_TELEGRAPH else Vector3.ONE)
