## Global economy constants (0.1). Numbers live here, not in code.
class_name EconomyData
extends Resource

@export_range(0.0, 1.0) var death_retain_ratio: float = 0.5
@export var pickup_magnet_radius: float = 3.0
@export var pickup_collect_radius: float = 0.8
@export var pickup_magnet_speed: float = 12.0
## Credit drop chance per kill (1 = always).
@export_range(0.0, 1.0) var credit_drop_chance: float = 1.0
