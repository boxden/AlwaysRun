#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "[smoke] Ensuring no legacy globals for UI refs..."
if rg -n "_G\.AlwaysRun(MainCheckbox|KeyButton)" lua/autorun/client/always_run.lua; then
  echo "[smoke] Found forbidden _G UI references"
  exit 1
fi

echo "[smoke] Running Lua syntax checks..."
if command -v luac >/dev/null 2>&1; then
  luac -p lua/autorun/client/always_run.lua
  luac -p lua/autorun/client/always_run_localization.lua
elif command -v luac5.1 >/dev/null 2>&1; then
  luac5.1 -p lua/autorun/client/always_run.lua
  luac5.1 -p lua/autorun/client/always_run_localization.lua
else
  echo "[smoke] luac is not installed"
  exit 1
fi

echo "[smoke] OK"
