## Mission root: wires Level, Player, Swarm, Camera, HUD. No game rules
## beyond "player died -> restart" in M0-1. Wave/boss/extraction: M1.
class_name Mission
extends Node3D

@export var enemy_types: Array[EnemyData] = [preload("res://data/enemies/drone.tres")]
@export var target_enemies: int = 50
## Tracer FX for hitscan.
@export var show_tracers: bool = true

@onready var level: GreyboxLevel = $Level
@onready var player: Player = $Player
@onready var camera: IsoCamera = $IsoCamera
@onready var sim: SwarmSim = $Swarm/SwarmSim
@onready var renderer: SwarmRenderer = $Swarm/SwarmRenderer
@onready var spawner: SwarmSpawner = $Swarm/SwarmSpawner
@onready var hud: Hud = $HUD
@onready var tracer: Tracer = $FX/Tracer

var kills: int = 0


func _ready() -> void:
	sim.types = enemy_types
	sim.obstacles = level.obstacle_circles()
	renderer.sim = sim
	spawner.sim = sim
	spawner.spawn_points = level.spawn_points()
	spawner.target_count = target_enemies
	player.sim = sim
	if player.weapon != null:
		player.weapon.sim = sim
	camera.target = player
	hud.sim = sim

	sim.player_hit.connect(_on_player_hit)
	sim.enemy_killed.connect(_on_enemy_killed)
	player.health.damaged.connect(func(_i: DamageInfo, hp: float) -> void: hud.set_hp(hp, player.health.max_hp))
	player.health.died.connect(_on_player_died)
	if player.weapon != null:
		player.weapon.ammo_changed.connect(hud.set_ammo)
		player.weapon.reload_started.connect(func(_d: float) -> void: hud.set_reloading(true))
		player.weapon.fired.connect(_on_fired)
		hud.set_ammo(player.weapon.magazine, player.weapon.reserve)
	hud.set_hp(player.health.hp, player.health.max_hp)
	renderer._build()


func _physics_process(_delta: float) -> void:
	# Parent runs before children: SwarmSim.step sees this frame's player position.
	sim.player_pos = player.global_position
	camera.aim_dir = player.facing


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed(&"debug_bench"):
		get_tree().change_scene_to_file("res://levels/benchmark.tscn")


func _on_player_hit(damage: float, from_position: Vector3) -> void:
	player.take_hit(damage, from_position)


func _on_enemy_killed(_idx: int, type_idx: int, position: Vector3) -> void:
	kills += 1
	hud.kills = kills
	Events.enemy_killed.emit(type_idx, position)


func _on_fired(from: Vector3, dir: Vector3) -> void:
	if not show_tracers or player.weapon == null:
		return
	var to := from + dir * player.weapon.stat(&"range")
	var hits := sim.hitscan(from, to, player.weapon.data.ray_radius, 1)
	if not hits.is_empty():
		var p := sim.pos[hits[0]]
		to = Vector3(p.x, from.y, p.z)
	tracer.add(from, to)
	camera.add_trauma(player.weapon.data.trauma_per_shot)


func _on_player_died() -> void:
	Events.player_died.emit()
	print("player died — kills: %d" % kills)
	get_tree().reload_current_scene()
