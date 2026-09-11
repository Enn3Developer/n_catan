#!/usr/bin/env bash
# Export into a staging directory, verify the embedded pack, then publish locally.
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -n "${GODOT_BIN:-}" ]]; then
  godot_bin="$GODOT_BIN"
elif command -v godot >/dev/null 2>&1; then
  godot_bin="$(command -v godot)"
elif command -v godot4 >/dev/null 2>&1; then
  godot_bin="$(command -v godot4)"
elif [[ -x /home/enn3/Downloads/Godot/Godot.x86_64 ]]; then
  godot_bin=/home/enn3/Downloads/Godot/Godot.x86_64
else
  echo 'Set GODOT_BIN to your Godot 4 executable with matching export templates.' >&2
  exit 1
fi
mkdir -p "$project_dir/build/linux"
stage_dir="$(mktemp -d "$project_dir/build/.linux-export.XXXXXX")"
trap 'rm -rf -- "$stage_dir"' EXIT
"$godot_bin" --headless --path "$project_dir" --export-release Linux "$stage_dir/N Catan.x86_64"
# Catch accidentally cleared exclusion filters before replacing the current release.
python3 "$project_dir/tools/audit_build_size.py" "$stage_dir/N Catan.x86_64" --verify --max-mib 250 --json "$stage_dir/size-report.json"
chmod +x "$stage_dir/N Catan.x86_64"
mv -- "$stage_dir/N Catan.x86_64" "$project_dir/build/linux/N Catan.x86_64"
mv -- "$stage_dir/size-report.json" "$project_dir/build/linux-size-report.json"
python3 "$project_dir/tools/build_updater.py" --platform linux-x86_64 --output "$project_dir/build/linux/n-catan-updater"
cat > "$project_dir/build/linux/README.txt" <<'EOF'
CATAN - Tides & Timber (Linux x86-64)

Launch: ./"N Catan.x86_64"
The game is self-contained; Godot and the source project are not required.
Keep the updater beside the executable for signed automatic updates.
Use Game updates on the main menu to download and restart to install.
Launch the updater directly to recover an interrupted installation.

Start with Learn to play or Play solo. Configure 2-5 bots in a solo lobby.
Online rooms support 3-6 participants, including bots. The host must make
UDP port 24567 reachable. Enter the public IP/DNS in the lobby and Copy invite;
guests enter the host address. Online traffic uses plain ENet (no encryption).
All players need this game version (network protocol 10).

Right-drag: orbit. Middle-drag: pan. Scroll: zoom. Home: fit board.
H: inspect board. Esc: return. Settings and Piece cosmetics are on the menu.

Dedicated server: ./"N Catan.x86_64" --headless -- --server
Optional room password: append --password=your-room-password
Set --address=your-public-hostname:24567 and share the printed CATAN_INVITE.

Project license: GNU GPL version 3 only. See LICENSE for the full text.
Source: https://github.com/Enn3Developer/n_catan
Use the release tag for the matching source version; fetch assets with Git LFS.

Font: Fira Sans, SIL Open Font License; license included in the resource pack.
Texture sources: Poly Haven (CC0); asset provenance included in the resource pack.
Music: five original instrumental tracks. Host controls shared playback;
volume and mute are personal. Open Music on the menu or Tracks in-game.

Original project geometry, icons and audio. Requires a Vulkan-capable GPU
for the default Forward+ renderer.
EOF
cp -- "$project_dir/LICENSE" "$project_dir/build/linux/LICENSE"
tar -cJf "$stage_dir/N-Catan-linux-x86_64.tar.xz" -C "$project_dir/build" linux
mv -- "$stage_dir/N-Catan-linux-x86_64.tar.xz" "$project_dir/build/N-Catan-linux-x86_64.tar.xz"
(
  cd "$project_dir/build"
  sha256sum 'linux/N Catan.x86_64' N-Catan-linux-x86_64.tar.xz > "$stage_dir/SHA256SUMS"
)
mv -- "$stage_dir/SHA256SUMS" "$project_dir/build/SHA256SUMS"
echo "Ready: $project_dir/build/linux/N Catan.x86_64"
echo "Archive: $project_dir/build/N-Catan-linux-x86_64.tar.xz"
