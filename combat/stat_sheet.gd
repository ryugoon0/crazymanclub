## Base values + StatModifier list -> final value. Shared by player, weapons
## and (later) boss. Order: (base + sum ADD) * product MUL, then OVERRIDE wins.
## Values are cached until a modifier or base changes.
class_name StatSheet
extends RefCounted

var _base: Dictionary[StringName, float] = {}
var _mods: Array[StatModifier] = []
var _cache: Dictionary[StringName, float] = {}


func set_base(stat: StringName, value: float) -> void:
	_base[stat] = value
	_cache.clear()


func get_base(stat: StringName, default: float = 0.0) -> float:
	return _base.get(stat, default)


func add_modifier(m: StatModifier) -> void:
	_mods.append(m)
	_cache.clear()


func add_modifiers(list: Array[StatModifier]) -> void:
	for m in list:
		_mods.append(m)
	_cache.clear()


func remove_modifier(m: StatModifier) -> void:
	_mods.erase(m)
	_cache.clear()


func clear_modifiers() -> void:
	_mods.clear()
	_cache.clear()


func get_stat(stat: StringName, default: float = 0.0) -> float:
	if _cache.has(stat):
		return _cache[stat]
	var add := 0.0
	var mul := 1.0
	var has_override := false
	var override := 0.0
	for m in _mods:
		if m.stat != stat:
			continue
		match m.op:
			StatModifier.Op.ADD:
				add += m.value
			StatModifier.Op.MUL:
				mul *= m.value
			StatModifier.Op.OVERRIDE:
				has_override = true
				override = m.value
	var value: float = override if has_override else (_base.get(stat, default) + add) * mul
	_cache[stat] = value
	return value
