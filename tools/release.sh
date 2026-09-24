#!/usr/bin/env bash
# Rebuilds the committed, ready-to-open place file: release/SweepSquad.rbxl
# (Open it directly in Roblox Studio; no toolchain needed on the owner's machine.)
set -euo pipefail
cd "$(dirname "$0")/.."
./tools/check.sh
mkdir -p release
cp build/SweepSquad.rbxl release/SweepSquad.rbxl
echo "Updated release/SweepSquad.rbxl"
