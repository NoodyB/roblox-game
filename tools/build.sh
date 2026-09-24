#!/usr/bin/env bash
# Builds build/SweepSquad.rbxl, a place file you can open directly in Roblox Studio.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
rojo build default.project.json -o build/SweepSquad.rbxl
echo "Built build/SweepSquad.rbxl"
