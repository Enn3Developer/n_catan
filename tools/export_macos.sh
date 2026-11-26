#!/usr/bin/env bash
# Export the Apple Silicon bundle into a staging directory, verify its pack, then publish locally.
# The bundle is ad-hoc signed (Godot's built-in signer) and not notarized.
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -n "${GODOT_BIN:-}" ]]; then
  godot_bin="$GODOT_BIN"
elif command -v godot >/dev/null 2>&1; then
  godot_bin="$(command -v godot)"
elif command -v godot4 >/dev/null 2>&1; then
  godot_bin="$(command -v godot4)"
else
  echo 'Set GODOT_BIN to your Godot 4 executable with matching export templates.' >&2
  exit 1
fi
mkdir -p "$project_dir/build/macos"
stage_dir="$(mktemp -d "$project_dir/build/.macos-export.XXXXXX")"
trap 'rm -rf -- "$stage_dir"' EXIT
"$godot_bin" --headless --path "$project_dir" --export-release macOS "$stage_dir/N Catan.zip"
cat > "$stage_dir/README.txt" <<'EOF'
CATAN - Tides & Timber (macOS, Apple Silicon)

Launch: open "CATAN · Tides and Timber.app" (move it to Applications if you like).
The game is self-contained; Godot and the source project are not required.
The app is ad-hoc signed but not notarized. If macOS refuses to open it,
open System Settings > Privacy & Security and choose Open Anyway, or run:
  xattr -dr com.apple.quarantine "CATAN · Tides and Timber.app"
Automatic updates are not available on macOS: download new versions from
https://github.com/Enn3Developer/n_catan/releases

Start with Learn to play or Play solo. Configure 2-5 bots in a solo lobby.
Online rooms support 3-6 participants, including bots. The host must make
UDP port 24567 reachable. Enter the public IP/DNS in the lobby and Copy invite;
guests paste the compact invite code. Online traffic is encrypted with DTLS.
Everyone in a room needs the same release.

Right-drag: orbit. Middle-drag: pan. Scroll: zoom. Home: fit board.
H: inspect board. Esc: return. Settings and Piece cosmetics are on the menu.

Project license: GNU GPL version 3 only. See LICENSE for the full text.
Source: https://github.com/Enn3Developer/n_catan
Use the release tag for the matching source version; fetch assets with Git LFS.

Font: Fira Sans, SIL Open Font License; license included in the resource pack.
Texture sources: Poly Haven (CC0); asset provenance included in the resource pack.
Original project geometry, icons and audio. Requires macOS 11 on Apple Silicon.
EOF
python3 - "$stage_dir/N Catan.zip" "$stage_dir" "$project_dir/LICENSE" <<'PYZIP'
from pathlib import Path
import sys, zipfile
archive_path, stage, license_path = map(Path, sys.argv[1:])
with zipfile.ZipFile(archive_path, 'a', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    names = archive.namelist()
    bundles = {name.split('/')[0] for name in names}
    if len(bundles) != 1 or not next(iter(bundles)).endswith('.app'):
        sys.exit(f'Expected exactly one app bundle, got {sorted(bundles)}')
    bundle = bundles.pop()
    app = bundle.removesuffix('.app')
    pck = f'{bundle}/Contents/Resources/{app}.pck'
    executable = f'{bundle}/Contents/MacOS/{app}'
    if pck not in names or executable not in names or f'{bundle}/Contents/_CodeSignature/CodeResources' not in names:
        sys.exit(f'Unexpected bundle layout: {names[:20]}')
    if not (archive.getinfo(executable).external_attr >> 16) & 0o111:
        sys.exit('Exported executable lost its execute bit')
    (stage / 'N Catan.pck').write_bytes(archive.read(pck))
    archive.write(stage / 'README.txt', 'README.txt')
    archive.write(license_path, 'LICENSE')
PYZIP
# Catch accidentally cleared exclusion filters before replacing the current release.
python3 "$project_dir/tools/audit_build_size.py" "$stage_dir/N Catan.pck" --verify --max-mib 250 --json "$stage_dir/size-report.json"
mv -- "$stage_dir/size-report.json" "$project_dir/build/macos-size-report.json"
mv -- "$stage_dir/N Catan.zip" "$project_dir/build/N-Catan-macos-arm64.zip"
echo "Archive: $project_dir/build/N-Catan-macos-arm64.zip"
