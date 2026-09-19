## Runtime weapon driven by WeaponData + the owner's StatSheet.
## Hitscan only in M0-1. Fires into SwarmSim (regular enemies).
class_name Weapon
extends Node3D

signal fired(from: Vector3, dir: Vector3)
signal hit(position: Vector3, killed: bool)
signal ammo_changed(magazine: int, reserve: int)
signal reload_started(duration: float)
signal reload_finished()

@export var data: WeaponData
## Final numbers = weapon base + owner modifiers (upgrades, bio). Built in setup().
var sheet := StatSheet.new()
var sim: SwarmSim

var magazine: int = 0
var reserve: int = -1
var reloading: bool = false
var bloom_deg: float = 0.0
var _fire_cooldown: float = 0.0
var _reload_left: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if data != null and magazine == 0 and not reloading:
		setup(data)


func setup(p_data: WeaponData, seed: int = 0) -> void:
	data = p_data
	sheet = StatSheet.new()
	sheet.set_base(&"damage", data.damage)
	sheet.set_base(&"rpm", data.rpm)
	sheet.set_base(&"reload_time", data.reload_time)
	sheet.set_base(&"spread_deg", data.spread_deg)
	sheet.set_base(&"recoil_bloom_deg", data.recoil_bloom_deg)
	sheet.set_base(&"bloom_recover_deg_per_s", data.bloom_recover_deg_per_s)
	sheet.set_base(&"range", data.range)
	sheet.set_base(&"knockback", data.knockback)
	magazine = data.magazine
	reserve = data.reserve_max
	reloading = false
	bloom_deg = 0.0
	_fire_cooldown = 0.0
	_rng.seed = seed
	ammo_changed.emit(magazine, reserve)


## Owner (player) modifiers, e.g. from weapon upgrades or bio parts.
func add_modifiers(list: Array[StatModifier]) -> void:
	sheet.add_modifiers(list)


func stat(name: StringName) -> float:
	return sheet.get_stat(name)


func can_fire() -> bool:
	return not reloading and magazine > 0 and _fire_cooldown <= 0.0


## Call every physics frame. `dir` is a unit XZ direction (y ignored).
func tick(dt: float, fire_held: bool, reload_pressed: bool, from: Vector3, dir: Vector3) -> void:
	_fire_cooldown = maxf(0.0, _fire_cooldown - dt)
	bloom_deg = maxf(0.0, bloom_deg - stat(&"bloom_recover_deg_per_s") * dt)
	if reloading:
		_reload_left -= dt
		if _reload_left <= 0.0:
			_finish_reload()
		return
	if reload_pressed and magazine < data.magazine and (reserve != 0):
		start_reload()
		return
	if fire_held:
		if magazine <= 0:
			if reserve != 0:
				start_reload()
			return
		if _fire_cooldown <= 0.0:
			_fire(from, dir)


func start_reload() -> void:
	if reloading:
		return
	reloading = true
	_reload_left = stat(&"reload_time")
	reload_started.emit(_reload_left)


func _finish_reload() -> void:
	reloading = false
	var need := data.magazine - magazine
	if reserve < 0:
		magazine = data.magazine
	else:
		var take := mini(need, reserve)
		magazine += take
		reserve -= take
	ammo_changed.emit(magazine, reserve)
	reload_finished.emit()


func _fire(from: Vector3, dir: Vector3) -> void:
	var rpm := stat(&"rpm")
	_fire_cooldown = 60.0 / maxf(1.0, rpm)
	magazine -= 1
	ammo_changed.emit(magazine, reserve)
	var d3 := Vector3(dir.x, 0.0, dir.z).normalized()
	var spread := stat(&"spread_deg") + bloom_deg
	var dmg := stat(&"damage")
	var knock := stat(&"knockback")
	var rng_range := stat(&"range")
	var max_hits := 1 + data.penetration
	for _p: int in range(maxi(1, data.pellets)):
		var ang := deg_to_rad(_rng.randf_range(-spread, spread))
		var pdir := d3.rotated(Vector3.UP, ang)
		var to := from + pdir * rng_range
		if sim != null:
			var hits := sim.hitscan(from, to, data.ray_radius, max_hits)
			for idx: int in hits:
				var info := DamageInfo.make(dmg, pdir, knock, from)
				var hit_pos := sim.pos[idx]
				var killed := sim.apply_damage(idx, info)
				hit.emit(Vector3(hit_pos.x, 1.0, hit_pos.z), killed)
		fired.emit(from, pdir)
	bloom_deg = minf(data.bloom_max_deg, bloom_deg + stat(&"recoil_bloom_deg"))
