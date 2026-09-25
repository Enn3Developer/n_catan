# Linux build size

Measured September 9, 2026 with Godot 4.7.2, Linux x86-64, release export and an embedded resource pack. Sizes below are MiB (1,048,576 bytes).

| Component | Old executable | Optimized executable |
|---|---:|---:|
| Godot engine | 70.26 | 70.26 |
| Unused authoring textures | 154.60 | 0 |
| Runtime textures, 2048 px | 144.01 | 101.34 |
| Runtime textures, 1024 px | 36.01 | 25.34 |
| Runtime textures, 512 px | 9.01 | 6.34 |
| Biome models | 62.76 | 5.98 |
| Audio | 10.75 | 10.75 |
| Test scripts | 0.06 | 0 |
| Other resources and pack metadata | 3.42 | 0.75 |
| **Total** | **490.88** | **220.76** |

Exact executable sizes: **514,722,520 → 231,487,616 bytes**. Savings: **283,234,904 bytes (270.11 MiB, 55.03%)**. The baseline is the existing September 8 executable supplied in `build/linux/`. The new export also incorporates the preceding sculpted-art and responsive-UI work; that earlier art rework accounts for the model-size reduction in this comparison.

The verified `build/N-Catan-linux-x86_64.tar.xz` download is **146.51 MiB** (153,629,384 bytes). It contains the executable and a short launch guide. Archive extraction reproduces the executable exactly and preserves its executable permission.

Executable SHA-256: `fbd9fa8b97c4b51407a8f3f167ad7612d470bfe19dadd1f93fb7c2becc02befe`.

## Changes made for this export

- Excluded nine unused full-resolution authoring texture directories, five obsolete GLBs, development tests, tools, documentation, source files and build outputs through the Linux export preset. All authoring files remain in the project.
- Excluded the unused `rock_face` texture set at all three tiers. It has since been deleted from the repository, along with the unused runtime maps and the five obsolete GLBs.
- Changed material texture loading to request only channels actually sampled by each shader. Sculpted props use albedo; cliffs use albedo and normal; ground uses all three maps. Unused bark/wood normal and ORM maps and cliff ORM maps are excluded from the package. This also avoids allocating those unused textures during play.
- Preserved all 57 sampled textures, all mipmaps, all three resolution choices, all 12 current biome models, both fonts, all cosmetic styles and all 10 audio clips. All **67 retained texture/audio payloads match the old pack's MD5 checksums**; there is no new texture or audio recompression.
- Included the font license and texture provenance explicitly. Added `build/.gdignore` so generated distributions cannot enter Godot's import pipeline.
- Added `tools/export_linux.sh` and `tools/audit_build_size.py`. The exporter stages output and checks the embedded pack before replacing the executable; the audit reports source asset names by reading the packed import remaps.

The existing BPTC/RGTC texture formats remain intact to retain GPU memory efficiency and loading behavior. Godot documents the tradeoffs between disk compression and VRAM compression in [Importing images](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html). The pack audit follows the [engine's PCK reader](https://github.com/godotengine/godot/blob/master/core/io/file_access_pack.cpp).

## Verification

- Release export completed with no errors or warnings.
- Every one of the **271 packed entries** passed its checksum check. The inventory contains no tests, old source textures, documentation, authoring files or nested builds.
- The exported executable launched from a separate directory, with its embedded resources, and completed a 240-frame Forward+ GPU smoke test without errors or warnings. The final export contains exactly the same packed file checksums as the tested candidate.
- Tests used the exported executable as `--main-pack`, with the Godot test runner loading external test scripts. This tests the shipped compiled scripts and resources, without adding tests to the release. The installed release template disables external path overrides.
- `graphics_test.gd`: **201 checks, 0 failures**, using Forward+ on the GPU, including all texture/model tiers and graphics controls.
- `feature_test.gd`: **72 checks, 0 failures**, including settings, solo play and all tutorial lessons.
- `cosmetics_test.gd`: **35 checks, 0 failures**, including all four sets, previews and bot selection.
- `audio_test.gd`: **10 checks, 0 failures**, including full PCM loop lengths and wraparound.
- `network_test.gd`: **0 failures**, with three ENet peers, private hands, setup, invalid-action rejection, dice synchronization and reconnection over loopback.

A populated board, the main menu, trades, and all six biomes were also rendered from the exported pack and the board capture inspected: [optimized-build-board.png](optimized-build-board.png).

The existing headless audio/cosmetics tests still report resource cleanup warnings at exit. They report no failed assertions or missing runtime resources.


## Resource icon update

After the size measurements above, timber and grain were redrawn as stacked logs and distinct wheat ears. The rebuilt executable is 231,491,456 bytes (220.77 MiB); only the two icon payloads changed. The archive and `build/SHA256SUMS` were regenerated. A render of the exported icons at 18, 22, 28, 38, 64 and 96 px matches the source preview pixel for pixel. [Icon preview](resource-icons.png).

## Rebuild after cleared export filters

A later build grew to **431.50 MiB (452,457,448 bytes)** because the Linux preset's `include_filter` and `exclude_filter` were empty. The pack contained 444 entries, including 154.60 MiB of unused authoring textures, unused runtime maps, obsolete models and test scripts. The file does not establish what cleared those settings.

Restored the exclusions and explicit license/provenance inclusion, then rebuilt to **220.77 MiB (231,491,456 bytes)** with the original 271-entry compact inventory. The archive is **146.52 MiB (153,634,224 bytes)**. Packed checksums, distribution SHA-256 hashes, archived executable contents and executable permissions all passed verification. The actual release completed a 240-frame Forward+ startup test without errors or warnings.

Use `./tools/export_linux.sh` for subsequent releases. It now rejects exports over **250 MiB** before replacing the previous executable or archive, with a message directing you to the Linux exclusion filters. This guard was checked against the actual 431.50 MiB build and passed for the compact rebuild. Direct exports from Godot's editor use the restored preset but bypass the script's size guard. If substantial content is intentionally added later, review the packed inventory before increasing the limit in the script.


## Windows parity (September 11)

Windows now has the same include/exclude filters and disabled debug symbols as Linux. `tools/export_windows.sh` stages and verifies the executable before replacing the local release, creates a ZIP, and writes `build/windows-size-report.json` plus `build/WINDOWS-SHA256SUMS`. Its limit is 275 MiB because the installed Windows engine template is larger; Linux retains 250 MiB.

Current sizes after the gameplay update: Linux 231,502,920 bytes (220.78 MiB); Windows 267,239,800 bytes (254.86 MiB). Both contain 275 resources, with identical asset payloads. Original authoring files and all runtime texture quality tiers remain available. Direct editor exports use the optimized presets but bypass the scripts' size guards.


## Expanded soundtrack (September 11)

Four additional Vorbis tracks add approximately 4 MiB; all five music tracks and the existing effects ship in both builds. Current Linux executable: 235,783,872 bytes (224.86 MiB). Windows: 271,520,752 bytes (258.94 MiB). Both have 299 verified packed resources with identical asset payloads. The existing exclusions and 250/275 MiB size guards remain in force.
