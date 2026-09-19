class_name MissionData
extends Resource

@export var id: StringName = &"m01"
@export var display_name_key: String = "MISSION_M01_NAME"
@export_file("*.tscn") var level_scene: String = "res://levels/greybox_01.tscn"
@export var waves: Array[WaveData] = []
@export var boss: EnemyData
## Wave the boss calls in periodically (spawned once per call).
@export var boss_reinforcement: WaveData
@export var boss_reinforcement_interval: float = 12.0
@export var clear_bonus: int = 600
## Seconds between boss death and the extraction zone opening.
@export var extraction_delay: float = 1.5
## Difficulty modifiers (0.1: empty).
@export var modifiers: Array[StatModifier] = []
