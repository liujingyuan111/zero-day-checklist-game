#!/bin/sh
set -eu
ZD_GODOT="${1:-godot}"
ZD_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
"$ZD_GODOT" --headless --path "$ZD_ROOT" --editor --import --quit >"$ZD_ROOT/tests/import.log" 2>&1
"$ZD_GODOT" --headless --path "$ZD_ROOT" --script tests/run_tests.gd >"$ZD_ROOT/tests/engine.log" 2>&1 || { cat "$ZD_ROOT/tests/engine.log"; exit 1; }
cat "$ZD_ROOT/tests/engine.log"
