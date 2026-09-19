## Mission root: wires Level, Player, Swarm, Camera, FX, Audio, HUD and runs
## the loop: waves -> boss -> extraction -> RunResult. Standalone (F5 on this
## scene) works without Main: result shows on the HUD and Esc restarts.
class_name Mission
extends Node3D

signal mission_ended(result: RunResult)

@export var mission_data: MissionData = preload("res://data/missions/m01.tres")
@export var enemy_types: Array[EnemyData] = [
	preload("res://data/enemies/drone.tres"),
	preload("res://data/enemies/runner.tres"),
	preload("res://data/enemies/tank.tres"),
]
## Benchmark / sandbox: endless spawner instead of waves.
@export var endless: bool = false
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
@onready var director: WaveDirector = $Swarm/WaveDirector
@onready var pickups: PickupSystem = $Systems/Pickups
@onready var projectiles: ProjectileSystem = $Systems/Projectiles
@onready var hud: Hud = $HUD
@onready var tracer: Tracer = $FX/Tracer
@onready var debris: DebrisSystem = $FX/Debris
@onready var decals: DecalSystem = $FX/Decals
@onready var hit_stop: HitStop = $FX/HitStop
@onready var extraction: ExtractionZone = $FX/Extraction
@onready var audio: AudioPool = $Audio

var kills: int = 0
var kills_by_type: Dictionary[StringName, int] = {}
var run_credits: int = 0
var damage_dealt: float = 0.0
var damage_taken: float = 0.0
var run_time: float = 0.0
var boss: Boss
var boss_killed := false
var ended := false
var standalone := true
var _rng := RandomNumberGenerator.new()
var _seed := 0
## Feel toggles (F1 hit stop, F2 shake, F4 knockback, F5 fx, F6 audio, F7 flash).
var feel: Dictionary[StringName, bool] = {
	&"hit_stop": true, &"shake": true, &"knockback": true, &"fx": true, &"audio": true, &"flash": true,
}


func _ready() -> void:
	standalone = get_parent() == get_tree().root or not (get_parent() is Node and get_parent().has_method("on_mission_ended"))
	_seed = int(Time.get_unix_time_from_system()) & 0x7fffffff
	_rng.seed = _seed
	sim.types = enemy_types
	sim.obstacles = level.obstacle_circles()
	renderer.sim = sim
	spawner.sim = sim
	spawner.spawn_points = level.spawn_points()
	spawner.type_weights = spawn_weights
	spawner.enabled = endless
	spawner.target_count = target_enemies if endless else 0
	projectiles.sim = sim
	player.sim = sim
	player.global_position = level.player_start() + Vector3(0, 0.1, 0)
	camera.target = player
	hud.sim = sim
	audio.register_dir("res://audio/sfx")
	extraction.global_position = level.extraction_point()

	_apply_profile()

	sim.player_hit.connect(_on_player_hit)
	sim.enemy_killed.connect(_on_enemy_killed)
	sim.enemy_windup.connect(func(_i: int, _p: Vector3) -> void: audio.play(&"enemy_attack", 1, 0.15, -8.0))
	player.health.damaged.connect(_on_player_damaged)
	player.health.died.connect(_on_player_died)
	player.dashed.connect(func() -> void: audio.play(&"dash", 2, 0.05, -4.0))
	pickups.collected.connect(_on_pickup)
	projectiles.hit.connect(_on_hit)
	var w := player.weapon
	w.ammo_changed.connect(hud.set_ammo)
	w.reload_started.connect(func(_d: float) -> void: hud.set_reloading(true); audio.play(&"reload_start", 2))
	w.reload_finished.connect(func() -> void: audio.play(&"reload_end", 2))
	w.fired.connect(_on_fired)
	w.hit.connect(_on_hit)
	hud.set_ammo(w.magazine, w.reserve)
	hud.set_hp(player.health.hp, player.health.max_hp)
	hud.set_credits(0)
	renderer._build()
	_apply_feel()

	if not endless:
		director.mission = mission_data
		director.sim = sim
		director.spawner = spawner
		director.wave_started.connect(_on_wave_started)
		director.boss_phase_started.connect(_on_boss_phase)
		director.reinforcement_called.connect(func(n: int) -> void: hud.flash_center("REINFORCEMENTS +%d" % n, 1.2))
		director.extraction_opened.connect(_on_extraction_opened)
		director.start()
	else:
		hud.set_objective("SANDBOX")
	Telemetry.log(&"mission_start", {"mission": String(mission_data.id), "seed": _seed, "weapon": String(player.weapon.data.id), "endless": endless})


## Equip from Profile: weapon + upgrade level + bio modifiers.
func _apply_profile() -> void:
	var wd := Content.weapon(Profile.equipped_weapon)
	if wd == null:
		wd = Content.weapon(Profile.STARTER_WEAPON)
	var w := player.weapon
	w.setup(wd, _seed)
	w.sim = sim
	w.projectiles = projectiles
	var track := Content.upgrade(&"weapon_track")
	if track != null:
		w.add_modifiers(track.modifiers_at(Profile.weapon_level(wd.id)))
	var bio := Profile.bio_modifiers()
	w.add_modifiers(bio)
	player.stats.add_modifiers(bio)
	player.health.max_hp = player.stats.get_stat(&"max_hp")
	player.health.reset()


func _physics_process(delta: float) -> void:
	if ended:
		return
	run_time += delta
	# Parent runs before children: SwarmSim.step sees this frame's player position.
	sim.player_pos = player.global_position
	pickups.player_pos = player.global_position
	camera.aim_dir = player.facing
	if extraction.visible and extraction.contains(player.global_position):
		_finish(true, &"extracted")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		if standalone:
			get_tree().reload_current_scene()
		elif not ended:
			_finish(false, &"aborted")
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
	player.weapon.knockback_scale = 1.0 if feel[&"knockback"] else 0.0
	debris.enabled = feel[&"fx"]
	decals.enabled = feel[&"fx"]
	player.muzzle_flash.enabled = feel[&"fx"]
	show_tracers = feel[&"fx"]
	audio.enabled = feel[&"audio"]
	renderer.flash_enabled = feel[&"flash"]
	hud.set_feel(feel)


# --- flow ---------------------------------------------------------------------

func _on_wave_started(index: int, total: int) -> void:
	hud.set_objective("WAVE %d / %d" % [index + 1, total])
	hud.flash_center("WAVE %d" % (index + 1), 1.5)
	Telemetry.log(&"wave_start", {"wave": index + 1, "t": run_time})


func _on_boss_phase() -> void:
	hud.set_objective("BOSS")
	hud.flash_center("BROODMOTHER", 2.0)
	boss = Boss.new()
	boss.name = "Boss"
	boss.data = mission_data.boss
	boss.player = player
	var at := spawner.random_spawn_point()
	add_child(boss)
	boss.global_position = Vector3(at.x, 0.0, at.z)
	boss.hit_player.connect(_on_player_hit)
	boss.damaged.connect(func(hp: float, max_hp: float) -> void: hud.set_boss(hp, max_hp))
	boss.died.connect(_on_boss_died)
	boss.telegraph.connect(func(_k: StringName) -> void: audio.play(&"enemy_attack", 3, 0.05, 2.0))
	player.weapon.boss_target = boss
	projectiles.boss_target = boss
	hud.set_boss(boss.max_hp(), boss.max_hp(), true)
	Telemetry.log(&"boss_start", {"t": run_time})


func _on_boss_died(position: Vector3) -> void:
	boss_killed = true
	player.weapon.boss_target = null
	projectiles.boss_target = null
	hud.set_boss(0.0, 1.0, false)
	hit_stop.request(6)
	camera.add_trauma(0.6)
	audio.play(&"kill", 6, 0.0, 4.0)
	debris.burst(position, Vector3.FORWARD, mission_data.boss.color, 40, 9.0)
	decals.splat(position, 4.0, fluid_color.darkened(0.4))
	pickups.drop(position, mission_data.boss.credit_max)
	kills_by_type[mission_data.boss.id] = 1
	director.boss_died()
	hud.set_objective("CLEAR THE AREA")


func _on_extraction_opened() -> void:
	extraction.visible = true
	hud.set_objective("EXTRACTION OPEN — reach the marker")
	hud.flash_center("EXTRACTION OPEN", 2.0)
	audio.play(&"reload_end", 4, 0.0, 2.0)


func _finish(success: bool, reason: StringName) -> void:
	if ended:
		return
	ended = true
	var r := RunResult.new()
	r.mission_id = mission_data.id
	r.seed = _seed
	r.success = success
	r.ended_reason = reason
	r.duration_s = run_time
	r.kills = kills_by_type.duplicate()
	r.credits_run = run_credits
	r.clear_bonus = mission_data.clear_bonus if success else 0
	var retain := Content.economy_data().death_retain_ratio
	r.credits_kept = (run_credits + r.clear_bonus) if success else int(floor(run_credits * retain))
	r.damage_dealt = damage_dealt
	r.damage_taken = damage_taken
	r.weapon_id = player.weapon.data.id
	r.weapon_level = Profile.weapon_level(player.weapon.data.id)
	r.boss_killed = boss_killed
	r.ended_at_unix = int(Time.get_unix_time_from_system())
	Telemetry.log(&"mission_end", r.to_dict())
	Profile.apply_run(r)
	SaveService.save_profile()
	spawner.enabled = false
	director.auto_step = false
	if standalone:
		hud.set_objective("")
		hud.flash_center("%s\nkills %d · credit +%d · %.0fs\nEsc to restart" % ["EXTRACTED" if success else "MISSION FAILED", kills, r.credits_kept, run_time], 999.0)
	mission_ended.emit(r)


# --- combat hooks -------------------------------------------------------------

func _on_player_hit(damage: float, from_position: Vector3) -> void:
	player.take_hit(damage, from_position)


func _on_player_damaged(info: DamageInfo, hp: float) -> void:
	damage_taken += info.amount
	hud.set_hp(hp, player.health.max_hp)
	camera.add_trauma(hurt_trauma)
	audio.play(&"player_hurt", 5)


func _on_enemy_killed(_idx: int, type_idx: int, position: Vector3) -> void:
	kills += 1
	hud.kills = kills
	var d := enemy_types[type_idx]
	kills_by_type[d.id] = kills_by_type.get(d.id, 0) + 1
	if _rng.randf() <= Content.economy_data().credit_drop_chance:
		pickups.drop(position, _rng.randi_range(d.credit_min, d.credit_max))
	Events.enemy_killed.emit(type_idx, position)


func _on_pickup(value: int, _position: Vector3) -> void:
	run_credits += value
	hud.set_credits(run_credits)


func _on_fired(from: Vector3, dir: Vector3) -> void:
	player.muzzle_flash.flash()
	audio.play(&"ar_fire", 3, 0.06)
	camera.add_trauma(player.weapon.data.trauma_per_shot)
	if not show_tracers or player.weapon.data.fire_mode != WeaponData.FireMode.HITSCAN:
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
	damage_dealt += w.stat(&"damage")
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
	Telemetry.log(&"player_death", {"t": run_time, "kills": kills})
	_finish(false, &"died")
