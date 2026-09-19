#!/usr/bin/env bash
# Local gate: import + smoke check + unit tests. Usage: GODOT=/path/to/godot tools/check.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . -s res://tools/smoke_check.gd
"$GODOT" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
