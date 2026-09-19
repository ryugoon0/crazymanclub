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
