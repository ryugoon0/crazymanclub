## Persistent player state (in memory). The only writer of progression.
## SaveService serialises to_dict(); UI reads fields and calls methods.
extends Node

signal changed()

const SCHEMA_VERSION := 1
const STARTER_WEAPON := &"ar_basic"

var account_id: String = ""
var created_at_unix: int = 0
var credits: int = 0
var owned_weapons: Array[StringName] = [STARTER_WEAPON]
var equipped_weapon: StringName = STARTER_WEAPON
var weapon_levels: Dictionary[StringName, int] = {}
var bio_levels: Dictionary[StringName, int] = {}
var missions_cleared: Dictionary[StringName, int] = {}
var stats: Dictionary[StringName, int] = {&"kills": 0, &"runs": 0, &"deaths": 0}
var recent_runs: Array[Dictionary] = []
const MAX_RECENT_RUNS := 20


func _ready() -> void:
	if account_id.is_empty():
		reset()


func reset() -> void:
	account_id = "local-" + _uuid()
	created_at_unix = int(Time.get_unix_time_from_system())
	credits = 0
	owned_weapons = [STARTER_WEAPON]
	equipped_weapon = STARTER_WEAPON
	weapon_levels = {}
	bio_levels = {}
	missions_cleared = {}
	stats = {&"kills": 0, &"runs": 0, &"deaths": 0}
	recent_runs = []
	changed.emit()


static func _uuid() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%08x%08x" % [rng.randi(), rng.randi()]


# --- economy -----------------------------------------------------------------

func can_afford(cost: int) -> bool:
	return cost >= 0 and credits >= cost


func add_credits(amount: int) -> void:
	credits = maxi(0, credits + amount)
	changed.emit()


func spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	credits -= cost
	changed.emit()
	return true


# --- weapons -----------------------------------------------------------------

func owns_weapon(id: StringName) -> bool:
	return owned_weapons.has(id)


func weapon_level(id: StringName) -> int:
	return weapon_levels.get(id, 0)


func buy_weapon(w: WeaponData) -> bool:
	if w == null or owns_weapon(w.id) or not spend(w.price):
		return false
	owned_weapons.append(w.id)
	equipped_weapon = w.id
	changed.emit()
	return true


func equip(id: StringName) -> bool:
	if not owns_weapon(id):
		return false
	equipped_weapon = id
	changed.emit()
	return true


## Weapon upgrade track is shared (one UpgradeData with slot WEAPON), level per weapon.
func upgrade_weapon(id: StringName, track: UpgradeData) -> bool:
	if track == null or not owns_weapon(id):
		return false
	var lvl := weapon_level(id)
	var cost := track.cost_for_next(lvl)
	if cost < 0 or not spend(cost):
		return false
	weapon_levels[id] = lvl + 1
	changed.emit()
	return true


# --- bio ---------------------------------------------------------------------

func bio_level(id: StringName) -> int:
	return bio_levels.get(id, 0)


func upgrade_bio(track: UpgradeData) -> bool:
	if track == null:
		return false
	var lvl := bio_level(track.id)
	var cost := track.cost_for_next(lvl)
	if cost < 0 or not spend(cost):
		return false
	bio_levels[track.id] = lvl + 1
	changed.emit()
	return true


## All player-side modifiers (bio parts) as one list.
func bio_modifiers() -> Array[StatModifier]:
	var out: Array[StatModifier] = []
	for id: StringName in bio_levels:
		var track := Content.upgrade(id)
		if track != null:
			out.append_array(track.modifiers_at(bio_levels[id]))
	return out


# --- runs --------------------------------------------------------------------

func apply_run(result: RunResult) -> void:
	credits += result.credits_kept
	stats[&"kills"] = stats.get(&"kills", 0) + result.total_kills()
	stats[&"runs"] = stats.get(&"runs", 0) + 1
	if not result.success:
		stats[&"deaths"] = stats.get(&"deaths", 0) + 1
	else:
		missions_cleared[result.mission_id] = missions_cleared.get(result.mission_id, 0) + 1
	recent_runs.append(result.to_dict())
	while recent_runs.size() > MAX_RECENT_RUNS:
		recent_runs.pop_front()
	changed.emit()


# --- serialisation (schema in docs/03, section 10) ---------------------------

func to_dict() -> Dictionary:
	var weapons := []
	for id: StringName in owned_weapons:
		weapons.append({"instance_id": String(id), "def_id": String(id), "level": weapon_level(id), "affixes": []})
	var bio := {}
	for k: StringName in bio_levels:
		bio[String(k)] = bio_levels[k]
	var cleared := {}
	for k: StringName in missions_cleared:
		cleared[String(k)] = missions_cleared[k]
	var st := {}
	for k: StringName in stats:
		st[String(k)] = stats[k]
	return {
		"schema_version": SCHEMA_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"account": {"account_id": account_id, "created_at_unix": created_at_unix, "rank": 0, "rank_points": 0, "loadouts": []},
		"wallet": {"credit": credits},
		"characters": [{
			"character_id": "c1", "loadout_id": "", "equipped_weapon_id": String(equipped_weapon),
			"bio_levels": bio, "stats": st,
		}],
		"inventory": {"weapons": weapons},
		"progress": {"missions_cleared": cleared},
		"runs": recent_runs.duplicate(),
	}


func from_dict(d: Dictionary) -> bool:
	if d.is_empty() or int(d.get("schema_version", 0)) != SCHEMA_VERSION:
		return false
	var acc: Dictionary = d.get("account", {})
	account_id = str(acc.get("account_id", "local-" + _uuid()))
	created_at_unix = int(acc.get("created_at_unix", Time.get_unix_time_from_system()))
	credits = int((d.get("wallet", {}) as Dictionary).get("credit", 0))
	owned_weapons = []
	weapon_levels = {}
	for w: Dictionary in (d.get("inventory", {}) as Dictionary).get("weapons", []):
		var id := StringName(str(w.get("def_id", "")))
		if id == &"" or owned_weapons.has(id):
			continue
		owned_weapons.append(id)
		weapon_levels[id] = int(w.get("level", 0))
	if owned_weapons.is_empty():
		owned_weapons = [STARTER_WEAPON]
	var chars: Array = d.get("characters", [])
	var c: Dictionary = chars[0] if not chars.is_empty() else {}
	equipped_weapon = StringName(str(c.get("equipped_weapon_id", STARTER_WEAPON)))
	if not owned_weapons.has(equipped_weapon):
		equipped_weapon = owned_weapons[0]
	bio_levels = {}
	for k: String in (c.get("bio_levels", {}) as Dictionary):
		bio_levels[StringName(k)] = int(c["bio_levels"][k])
	stats = {&"kills": 0, &"runs": 0, &"deaths": 0}
	for k: String in (c.get("stats", {}) as Dictionary):
		stats[StringName(k)] = int(c["stats"][k])
	missions_cleared = {}
	for k: String in ((d.get("progress", {}) as Dictionary).get("missions_cleared", {}) as Dictionary):
		missions_cleared[StringName(k)] = int(d["progress"]["missions_cleared"][k])
	recent_runs = []
	for r in d.get("runs", []):
		if r is Dictionary:
			recent_runs.append(r)
	changed.emit()
	return true
