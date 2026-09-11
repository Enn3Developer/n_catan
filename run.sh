#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -n "${GODOT_BIN:-}" ]]; then
  godot_bin="$GODOT_BIN"
elif command -v godot >/dev/null 2>&1; then
  godot_bin="$(command -v godot)"
elif command -v godot4 >/dev/null 2>&1; then
  godot_bin="$(command -v godot4)"
elif [[ -x /home/enn3/Downloads/Godot/Godot.x86_64 ]]; then
  godot_bin=/home/enn3/Downloads/Godot/Godot.x86_64
else
  echo 'Set GODOT_BIN to your Godot 4 executable.' >&2
  exit 1
fi
if [[ "${1:-}" == '--server' ]]; then
  exec "$godot_bin" --headless --path "$project_dir" -- "$@"
fi
exec "$godot_bin" --path "$project_dir" -- "$@"
