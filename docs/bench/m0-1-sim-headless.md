# M0-1 headless SwarmSim micro-benchmark (step() only, no rendering)

Date: 2026-09-19 · Godot 4.7.2 · `tools/bench_sim_headless.gd`
Machine: remote container, Intel Xeon @ 2.10GHz (4 threads). Slower than the RTX 3070 desktop CPU; treat as an upper bound on step cost.
Scenario: Drone only, 3 circular obstacles, player moving in a slow loop, 300 frames at 60Hz.

| enemies | avg step ms | max step ms | share of 16.67ms |
|---|---|---|---|
| 10 | 0.051 | 0.109 | 0% |
| 30 | 0.159 | 0.361 | 1% |
| 50 | 0.261 | 0.474 | 2% |
| 100 | 0.562 | 0.903 | 3% |
| 200 | 1.208 | 2.943 | 7% |
| 300 | 2.001 | 6.569 | 12% |

Reading: the simulation alone is linear and well inside budget at 300 on a slow CPU. The official gate (decision M: 200 enemies, avg ≥ 60 FPS, 1% low ≥ 45) is measured in the on-screen benchmark scene with MultiMesh rendering, which is not built yet. Max spikes (6.6ms at 300) are likely GC/allocation from `neighbors()` result arrays; revisit only if the on-screen benchmark shows them.

## Headless full-scene smoke run (benchmark scene, `--bench-fast`, no GPU)

Same container. FPS here is the headless loop cap (~145) and means nothing; the useful columns are the CPU ones. `phys_ms` includes `SwarmSim.step()` (it runs in `_physics_process`) plus spawner and player physics.

| enemies | sim ms | physics ms (incl. sim) | main thread ms |
|---|---|---|---|
| 100 | 1.89 | 4.68 | 0.40 |
| 200 | 3.45 | 5.77 | 0.51 |
| 300 | 5.27 | 7.63 | 0.64 |

Sim cost is ~2.5x the micro-benchmark because the bot is inside the swarm (every enemy is "near", so steering runs every frame) and kills/respawns churn the free list. That is the realistic case. On the RTX 3070 desktop CPU expect roughly half. Real gate numbers come from an on-screen run: `godot --path . res://levels/benchmark.tscn -- --bench-quit`.
