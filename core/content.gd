## Read-only registry of shipped content (.tres in res://data), keyed by id.
## Static + lazy; not an autoload. Save files reference these ids only.
class_name Content
extends RefCounted

static var _weapons: Dictionary[StringName, WeaponData] = {}
static var _enemies: Dictionary[StringName, EnemyData] = {}
static var _upgrades: Dictionary[StringName, UpgradeData] = {}
static var _missions: Dictionary[StringName, MissionData] = {}
static var _loaded := false
static var economy: EconomyData


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	for r: Resource in _scan("res://data/weapons"):
		if r is WeaponData:
			_weapons[(r as WeaponData).id] = r
	for r: Resource in _scan("res://data/enemies"):
		if r is EnemyData:
			_enemies[(r as EnemyData).id] = r
	for r: Resource in _scan("res://data/upgrades"):
		if r is UpgradeData:
			_upgrades[(r as UpgradeData).id] = r
	for r: Resource in _scan("res://data/missions"):
		if r is MissionData:
			_missions[(r as MissionData).id] = r
	if ResourceLoader.exists("res://data/economy.tres"):
		economy = load("res://data/economy.tres")
	else:
		economy = EconomyData.new()


static func _scan(dir: String) -> Array[Resource]:
	var out: Array[Resource] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f: String in d.get_files():
		var name := f.trim_suffix(".remap")
		if name.ends_with(".tres") or name.ends_with(".res"):
			var r: Resource = load(dir.path_join(name))
			if r != null:
				out.append(r)
	return out


static func reload() -> void:
	_loaded = false
	_weapons.clear(); _enemies.clear(); _upgrades.clear(); _missions.clear()
	_ensure()


static func weapon(id: StringName) -> WeaponData:
	_ensure()
	return _weapons.get(id)


static func enemy(id: StringName) -> EnemyData:
	_ensure()
	return _enemies.get(id)


static func upgrade(id: StringName) -> UpgradeData:
	_ensure()
	return _upgrades.get(id)


static func mission(id: StringName) -> MissionData:
	_ensure()
	return _missions.get(id)


static func weapons() -> Array[WeaponData]:
	_ensure()
	var out: Array[WeaponData] = []
	for k: StringName in _weapons:
		out.append(_weapons[k])
	out.sort_custom(func(a: WeaponData, b: WeaponData) -> bool: return a.price < b.price)
	return out


static func upgrades_in_slot(slot: UpgradeData.Slot) -> Array[UpgradeData]:
	_ensure()
	var out: Array[UpgradeData] = []
	for k: StringName in _upgrades:
		if _upgrades[k].slot == slot:
			out.append(_upgrades[k])
	return out


static func economy_data() -> EconomyData:
	_ensure()
	return economy
