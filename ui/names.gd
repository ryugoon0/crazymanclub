## Placeholder display strings for localisation keys. Replaced by
## TranslationServer + .po/.csv when localisation starts. Keys stay.
class_name Names
extends RefCounted

const EN: Dictionary = {
	"WEAPON_AR_BASIC_NAME": "Assault Rifle",
	"WEAPON_SHOTGUN_NAME": "Shotgun",
	"WEAPON_PLASMA_NAME": "Plasma Rifle",
	"ENEMY_DRONE_NAME": "Drone",
	"ENEMY_RUNNER_NAME": "Runner",
	"ENEMY_TANK_NAME": "Tank",
	"ENEMY_BOSS_BROODMOTHER_NAME": "Broodmother",
	"UPGRADE_WEAPON_NAME": "Weapon Upgrade",
	"BIO_ARMS_NAME": "Arms",
	"BIO_LEGS_NAME": "Legs",
	"BIO_TORSO_NAME": "Torso",
	"MISSION_M01_NAME": "Operation: Outpost Reclaim",
}


static func display(key: String) -> String:
	return EN.get(key, key)


static func stat_label(m: StatModifier) -> String:
	var s := String(m.stat).replace("_", " ")
	match m.op:
		StatModifier.Op.MUL:
			var pct := (m.value - 1.0) * 100.0
			return "%s %+.0f%%" % [s, pct]
		StatModifier.Op.ADD:
			return "%s %+.1f" % [s, m.value]
		_:
			return "%s = %.1f" % [s, m.value]
