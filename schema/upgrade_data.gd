## One upgrade track (weapon +N or a bio part). Level n applies
## `modifiers_per_level` n times: ADD stacks, MUL compounds.
class_name UpgradeData
extends Resource

enum Slot { WEAPON, ARMS, LEGS, TORSO }

@export var id: StringName = &""
@export var display_name_key: String = ""
@export var slot: Slot = Slot.WEAPON
@export var max_level: int = 5
## Cost to go from level i to i+1 (index i). Length == max_level.
@export var costs: PackedInt32Array = PackedInt32Array([1200, 2000, 3300, 5200, 8000])
@export var modifiers_per_level: Array[StatModifier] = []
@export var effects: Array[GameplayEffect] = []


func cost_for_next(level: int) -> int:
	if level < 0 or level >= max_level or level >= costs.size():
		return -1
	return costs[level]


## Modifiers that represent `level` levels of this track.
func modifiers_at(level: int) -> Array[StatModifier]:
	var out: Array[StatModifier] = []
	for _l: int in range(clampi(level, 0, max_level)):
		for m in modifiers_per_level:
			out.append(m)
	return out
