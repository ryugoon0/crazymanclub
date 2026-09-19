## Data definition for one enemy type. Regular enemies are NOT nodes: SwarmSim
## reads these values into its arrays. Boss (M1) may also use this.
class_name EnemyData
extends Resource

@export var id: StringName = &""
@export var display_name_key: String = ""

@export_group("Stats")
@export var hp: float = 100.0
@export var move_speed: float = 4.8
@export var damage: float = 14.0
@export var attack_range: float = 1.4
@export var attack_cooldown: float = 1.0
@export var attack_windup: float = 0.35
## 0 = full knockback, 1 = immune.
@export_range(0.0, 1.0) var knockback_resist: float = 0.25
## Collision/separation radius on the XZ plane.
@export var radius: float = 0.45

@export_group("Presentation")
@export var color: Color = Color(0.8, 0.8, 0.8)
@export var mesh: Mesh
@export var scale: float = 1.0

@export_group("Reward (M1)")
@export var credit_min: int = 0
@export var credit_max: int = 0

@export_group("Extension")
@export var modifiers: Array[StatModifier] = []
@export var effects: Array[GameplayEffect] = []
