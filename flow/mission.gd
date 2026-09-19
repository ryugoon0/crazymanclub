## Mission root: wires Level, Player, Swarm, Camera, FX, Audio, HUD.
## Game rules in M0: player died -> restart. Wave/boss/extraction: M1.
class_name Mission
extends Node3D

@export var enemy_types: Array[EnemyData] = [
	preload("res://data/enemies/drone.tres"),
	preload("res://data/enemies/runner.tres"),
	preload("res://data/enemies/tank.tres"),
]
## Spawn weights parallel to enemy_types (drone/runner/tank = 40/50/10).
@export var spawn_weights: PackedFloat32Array = PackedFloat32Array([0.4, 0.5, 0.1])
@export var target_enemies: int = 50
@export var show_tracers: bool = true
@export var kill_trauma: float = 0.08
@export var hurt_trauma: float = 0.35
@export var fluid_color: Color = Color(0.25, 0.7, 0.35)

@onready var level: GreyboxLevel = $Level
@onready var player: Player = $Player
@onready var camera: IsoCamera = $IsoCamera
@onready var sim: SwarmSim = $Swarm/SwarmSim
@onready var renderer: SwarmRenderer = $Swarm/SwarmRenderer
@onready var spawner: SwarmSpawner = $Swarm/SwarmSpawner
@onready var hud: Hud = $HUD
@onready var tracer: Tracer = $FX/Tracer
@onready var debris: DebrisSystem = $FX/Debris
@onready var decals: DecalSystem = $FX/Decals
@onready var hit_stop: HitStop = $FX/HitStop
@onready var audio: AudioPool = $Audio

var kills: int = 0
## Feel toggles (F1 hit stop, F2 shake, F4 knockback, F5 fx, F6 audio, F7 flash).
var feel: Dictionary[StringName, bool] = {
	&"hit_stop": true, &"shake": true, &"knockback": true, &"fx": true, &"audio": true, &"flash": true,
}


func _ready() -> void:
	sim.types = enemy_types
	sim.obstacles = level.obstacle_circles()
	renderer.sim = sim
	spawner.sim = sim
	spawner.spawn_points = level.spawn_points()
	spawner.target_count = target_enemies
	spawner.type_weights = spawn_weights
	player.sim = sim
	if player.weapon != null:
		player.weapon.sim = sim
	camera.target = player
	hud.sim = sim
	audio.register_dir("res://audio/sfx")

	sim.player_hit.connect(_on_player_hit)
	sim.enemy_killed.connect(_on_enemy_killed)
	sim.enemy_windup.connect(func(_i: int, _p: Vector3) -> void: audio.play(&"enemy_attack", 1, 0.15, -8.0))
	player.health.damaged.connect(_on_player_damaged)
	player.health.died.connect(_on_player_died)
	player.dashed.connect(func() -> void: audio.play(&"dash", 2, 0.05, -4.0))
	if player.weapon != null:
		var w := player.weapon
		w.ammo_changed.connect(hud.set_ammo)
		w.reload_started.connect(func(_d: float) -> void: hud.set_reloading(true); audio.play(&"reload_start", 2))
		w.reload_finished.connect(func() -> void: audio.play(&"reload_end", 2))
		w.fired.connect(_on_fired)
		w.hit.connect(_on_hit)
		hud.set_ammo(w.magazine, w.reserve)
	hud.set_hp(player.health.hp, player.health.max_hp)
	renderer._build()
	_apply_feel()


func _physics_process(_delta: float) -> void:
	# Parent runs before children: SwarmSim.step sees this frame's player position.
	sim.player_pos = player.global_position
	camera.aim_dir = player.facing


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed(&"debug_bench"):
		get_tree().change_scene_to_file("res://levels/benchmark.tscn")
	elif event.is_action_pressed(&"debug_toggle_hitstop"):
		_toggle(&"hit_stop")
	elif event.is_action_pressed(&"debug_toggle_shake"):
		_toggle(&"shake")
	elif event.is_action_pressed(&"debug_toggle_knockback"):
		_toggle(&"knockback")
	elif event.is_action_pressed(&"debug_toggle_fx"):
		_toggle(&"fx")
	elif event.is_action_pressed(&"debug_toggle_audio"):
		_toggle(&"audio")
	elif event.is_action_pressed(&"debug_toggle_flash"):
		_toggle(&"flash")


func _toggle(key: StringName) -> void:
	feel[key] = not feel[key]
	_apply_feel()


func _apply_feel() -> void:
	hit_stop.enabled = feel[&"hit_stop"]
	camera.max_shake_offset = 0.35 if feel[&"shake"] else 0.0
	if player.weapon != null:
		player.weapon.knockback_scale = 1.0 if feel[&"knockback"] else 0.0
	debris.enabled = feel[&"fx"]
	decals.enabled = feel[&"fx"]
	player.muzzle_flash.enabled = feel[&"fx"]
	show_tracers = feel[&"fx"]
	audio.enabled = feel[&"audio"]
	renderer.flash_enabled = feel[&"flash"]
	hud.set_feel(feel)


func _on_player_hit(damage: float, from_position: Vector3) -> void:
	player.take_hit(damage, from_position)


func _on_player_damaged(_info: DamageInfo, hp: float) -> void:
	hud.set_hp(hp, player.health.max_hp)
	camera.add_trauma(hurt_trauma)
	audio.play(&"player_hurt", 5)


func _on_enemy_killed(_idx: int, type_idx: int, position: Vector3) -> void:
	kills += 1
	hud.kills = kills
	Events.enemy_killed.emit(type_idx, position)


func _on_fired(from: Vector3, dir: Vector3) -> void:
	if player.weapon == null:
		return
	player.muzzle_flash.flash()
	audio.play(&"ar_fire", 3, 0.06)
	camera.add_trauma(player.weapon.data.trauma_per_shot)
	if not show_tracers:
		return
	var to := from + dir * player.weapon.stat(&"range")
	var hits := sim.hitscan(from, to, player.weapon.data.ray_radius, 1)
	if not hits.is_empty():
		var p := sim.pos[hits[0]]
		to = Vector3(p.x, from.y, p.z)
	tracer.add(from, to)


func _on_hit(position: Vector3, killed: bool) -> void:
	var w := player.weapon
	var dir := Vector3(player.facing.x, 0.0, player.facing.y)
	if killed:
		hit_stop.request(w.data.hit_stop_frames_kill)
		camera.add_trauma(kill_trauma)
		audio.play(&"kill", 4, 0.12)
		debris.burst(position, dir, fluid_color, 7, 6.5)
		decals.splat(position, 1.6, fluid_color.darkened(0.3))
	else:
		hit_stop.request(w.data.hit_stop_frames_normal)
		audio.play(&"hit", 1, 0.15, -6.0)
		decals.splat(position + dir * 0.4, 0.5, fluid_color.darkened(0.2))


func _on_player_died() -> void:
	Events.player_died.emit()
	print("player died — kills: %d" % kills)
	get_tree().reload_current_scene()
