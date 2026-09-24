#!/usr/bin/env bash
# Runs every automated quality gate. Usage: ./tools/check.sh
# Requires: stylua, selene, lune, rojo (see rokit.toml / README).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Formatting (stylua --check)"
stylua --check src tests tools

echo "==> Lint (selene)"
selene src

echo "==> Tests (lune)"
lune run tests/run

echo "==> Build place file (rojo)"
mkdir -p build
rojo build default.project.json -o build/SweepSquad.rbxl

echo "==> Validate built place (lune)"
lune run tools/validate_place.luau build/SweepSquad.rbxl

echo "All checks passed."
