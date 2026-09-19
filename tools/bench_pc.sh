#!/usr/bin/env bash
# XENO RECLAIMER — benchmark on a real GPU (Linux/macOS). See bench_pc.bat for Windows.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${1:-${GODOT_BIN:-godot}}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --path . --resolution 1600x900 res://levels/benchmark.tscn -- --bench-quit --bench-out=res://docs/bench --bench-label=pc
ls -t docs/bench/bench_*_pc.md | head -1 | xargs cat
