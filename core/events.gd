## Global signal bus. The only autoload allowed in M0.
## Rule: signals only. No state, no logic.
extends Node

## Emitted by SwarmSim when an enemy dies. type_idx indexes SwarmSim.types.
signal enemy_killed(type_idx: int, position: Vector3)
## Emitted by the player's Health when it reaches zero.
signal player_died()
## Emitted by BenchRunner after each measured step.
signal bench_step_done(enemy_count: int, result: Dictionary)
