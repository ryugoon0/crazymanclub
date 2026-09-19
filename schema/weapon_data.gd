## Data definition for one weapon. Weapon.gd reads this plus the owner's
## StatSheet to compute final numbers. No numbers live in code.
class_name WeaponData
extends Resource

enum Category { PISTOL, SMG, ASSAULT_RIFLE, SHOTGUN, MACHINE_GUN, HEAVY, ENERGY, EXPLOSIVE, EXPERIMENTAL }
enum FireMode { HITSCAN, PROJECTILE }

@export var id: StringName = &""
@export var display_name_key: String = ""
@export var category: Category = Category.ASSAULT_RIFLE
@export var fire_mode: FireMode = FireMode.HITSCAN

@export_group("Damage")
@export var damage: float = 22.0
@export var rpm: float = 600.0
## Pellets per shot (shotgun). Each pellet does `damage`.
@export var pellets: int = 1
@export var penetration: int = 0
@export var crit_chance: float = 0.0
@export var crit_mult: float = 1.5

@export_group("Ammo")
@export var magazine: int = 30
## -1 = infinite reserve (M0 decision).
@export var reserve_max: int = -1
@export var reload_time: float = 1.6

@export_group("Accuracy")
@export var spread_deg: float = 1.2
## Extra spread added per shot while firing; recovers when idle. Recoil is
## bloom, never a camera kick (isometric aim).
@export var recoil_bloom_deg: float = 0.6
@export var bloom_max_deg: float = 6.0
@export var bloom_recover_deg_per_s: float = 8.0
@export var range: float = 40.0
## Ray thickness for hitscan hit tests.
@export var ray_radius: float = 0.1

@export_group("Feel")
## Hit stop in frames, quantised (ms below one frame are meaningless).
@export var hit_stop_frames_normal: int = 0
@export var hit_stop_frames_kill: int = 1
## Camera trauma added per shot (shake = trauma^2).
@export var trauma_per_shot: float = 0.035
@export var knockback: float = 2.0

@export_group("Economy (M1)")
@export var price: int = 0

@export_group("Extension")
@export var modifiers: Array[StatModifier] = []
@export var effects: Array[GameplayEffect] = []
