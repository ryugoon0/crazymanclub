## Trigger-based behavioural effect (kill explosion, chain projectile, spawn on
## death, acid pool, conditional penetration ...).
## M0: data definition only. There is no runtime dispatcher yet; it is added
## when the first real effect is needed. Kept separate from StatModifier on
## purpose so numbers and behaviours never share one representation.
class_name GameplayEffect
extends Resource

## When it fires, e.g. &"on_kill", &"on_hit", &"on_reload", &"on_death".
@export var trigger: StringName = &""
## Optional gate, e.g. &"every_nth_shot", &"target_is_elite". Empty = always.
@export var condition: StringName = &""
## What happens, resolved by id by the future dispatcher, e.g. &"explode".
@export var effect_id: StringName = &""
@export var params: Dictionary = {}
