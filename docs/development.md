# Development

Build, release and test reference for contributors.

## Build standalone executables

Install Go and the Godot export templates matching your editor, then run:

```bash
./tools/export_linux.sh
./tools/export_windows.sh
```

Set `GODOT_BIN` if needed. Each script stages an export, verifies every packed resource checksum and builds the native updater. It replaces the local build only after the game export passes its checks.

| Platform | Game executable | Archive | Game size limit |
| --- | --- | --- | --- |
| Linux | `build/linux/N Catan.x86_64` | `build/N-Catan-linux-x86_64.tar.xz` | 250 MiB |
| Windows | `build/win/N Catan.exe` | `build/N-Catan-windows-x86_64.zip` | 275 MiB |

The scripts also write size reports and checksums under `build/`. Windows has a larger engine template, so its size limit is higher. Inspect a build with:

```bash
python3 tools/audit_build_size.py 'build/linux/N Catan.x86_64' --verify
```

Export presets exclude authoring textures, old models, tests, generated releases and unused material maps. They retain the game's texture tiers, audio, font license and texture source information. The original assets and Blender sources remain in the repository. See [build size measurements](build-size.md) for the earlier size reduction and validation results.

## Releases and updates

The game checks [GitHub Releases](https://github.com/Enn3Developer/n_catan/releases) for the latest stable version at startup. Open **Game updates** on the home screen or **Updates** in Settings, choose **Download update**, then **Restart to update**. You can keep playing while it downloads, but must leave the room before installing. Dedicated servers do not update automatically.

The exact Git tag sets the application and manifest version. Multiplayer uses a separate protocol number, currently 12. Releases with the same protocol can play together. A protocol mismatch rejects the join and identifies both versions. If a release changes the protocol, the group should update together.

The updater verifies the manifest's RSA/SHA-256 signature with its embedded public key, then checks the package and executable SHA-256 hashes. It uses a delta patch only when the installed executable matches a published base and the patch is smaller than 85% of the full download. If the delta fails, it downloads the full package.

The release builder reuses unchanged blocks from the exact previous published executable. The first release has full packages only. Later releases can include patches from the previous stable release.

Installation waits for the game to exit and keeps the old executables. If the new game fails to finish startup, the updater restores the old version. After an interrupted installation, launch the updater directly to recover and open the game. Keep the installation folder together. The updater retains one previous backup and leaves preferences in Godot's user data folder.

Pre-releases are available for manual testing. The stable update channel does not offer them.

### Publishing

Git LFS tracks assets and image files. Git ignores local builds, release output, caches and private keys.

The Release workflow runs when you push a version tag or publish a GitHub release. Use a SemVer tag such as `v1.0.0` or `v1.1.0-rc.1`. The workflow preserves the tag exactly in the manifest.

It builds Linux x86-64 and Windows x86-64 packages with their native updaters. The Godot version and download checksums are pinned in `config/release.json`. Release assets include full ZIPs, delta ZIPs where they save enough space, `SHA256SUMS` and `update-manifest.json`.

A tag push creates a draft release, uploads the packages and signed manifest, then publishes it. Publishing a release manually triggers the same build and upload. The workflow does not overwrite completed signed releases or accept a tag moved to a different commit. Retry a failed run to finish an incomplete release.

The repository has the required `UPDATE_SIGNING_PRIVATE_KEY` secret. Its public key is `updater/update_public.pem`. Back up the private key securely. Without it, existing clients cannot trust new updates. Replacing the public key without a transition release requires users to install manually. Never commit the private key or include it in a build.

You can also dispatch the workflow manually for an existing tag. Publishing defaults to off, so this can validate a build and produce downloadable Actions artifacts. Release tooling is in `tools/release.py`. Its `stamp` command changes version metadata in the build checkout.

## Source structure

The main scene, `scenes/main.tscn`, contains the Network, Board and Audio scenes. The board scene contains the camera, sun, environment, terrain, buildings and scenery nodes. The game generates terrain at runtime.

Edit the interface in `scenes/ui/`. Its named Controls define the layout, and `assets/ui_theme.tres` supplies the shared theme. The game does not run `tools/create_ui_scenes.py`. Rerunning that generator can overwrite manual scene edits.

| Path | Purpose |
| --- | --- |
| `scripts/rules.gd` | Board topology, rules, resources, scoring and private snapshots |
| `scripts/network.gd` | ENet host, lobby, passwords, replication, reconnection and UPnP |
| `scripts/board.gd` | Terrain, buildings, picking, camera and animations |
| `scripts/main.gd` | Scene connections and game interface |
| `scripts/bot.gd` | Bot decisions and difficulty settings |
| `scripts/tutorial.gd` | Guided practice scenarios |
| `scripts/settings.gd`, `scripts/audio.gd` | Preferences and audio buses |
| `scripts/cosmetics.gd`, `scripts/cosmetics_menu.gd` | Piece models and cosmetics screen |
| `scripts/tile_art.gd` | Terrain materials, model detail and texture tiers |
| `assets/premium/` | Twelve Blender biome variants |
| `assets/materials/` | Texture sources and runtime maps |
| `assets/source/` | Editable Blender models |
| `tools/prepare_tile_textures.py` | Texture preparation |
| `shaders/` | Ground, cliffs, foliage and water |
| `scripts/build_info.gd`, `scripts/updater.gd` | Version metadata and update interface |
| `updater/` | Native update verification and installation helper |

The server owns dice rolls, the deck, hands, resources and action validation. Clients receive other players' public counts, not private cards.

Online rooms use plain ENet over UDP. Room passwords still gate admission, but transport is unencrypted. Share the host address (optionally `:port`); old certificate invites are no longer supported. Protocol 12 clients must update together. Update downloads retain signature and hash verification.

## Verification

CI runs updater tests, Go race checks, patch producer tests, Windows updater compilation, game rules, update interface checks and multiplayer version checks. To run game tests locally:

```bash
# Replace godot with your Godot executable as needed.
godot --headless --path . --script res://tests/rules_test.gd
godot --headless --path . --script res://tests/network_test.gd
godot --headless --path . --script res://tests/bot_test.gd
godot --headless --path . --script res://tests/bot_network_test.gd
godot --headless --path . --script res://tests/solo_match_test.gd
godot --headless --path . --script res://tests/updater_ui_test.gd
godot --headless --path . --script res://tests/version_network_test.gd
GODOT_BIN=/path/to/godot python3 tests/run_online_test.py

go -C updater test -race ./...
python3 -m unittest discover -s tests -p 'test_*.py'
```

The rules suite checks setup, resource conservation, legal actions, trades, development cards, privacy, awards and victory. Network tests cover lobby replication, private hands, invalid moves, disconnects and reconnection. The dedicated-server test starts a server and two clients in separate processes. These tests use loopback networking. Internet access still depends on the host's router and firewall.

Bot tests cover every difficulty and mixed opponents. The feature suite checks lobby controls, bot setup, tutorial lessons, settings and audio. A solo match test runs the bot scheduler through to victory.

Run extension tests with:

```bash
godot --headless --path . --script res://tests/extension_test.gd
godot --headless --path . --script res://tests/extension_bot_test.gd
godot --headless --path . --script res://tests/extension_solo_test.gd
godot --path . --script res://tests/extension_ui_test.gd
python3 tests/run_online_test.py 6
```

Music tests are in `tests/music_test.gd`, `tests/music_network_test.gd` and `tests/music_ui_test.gd`. The script `tests/run_music_process_test.py` checks playback across separate processes.

Visual tests need a graphical session. They write captures under `/tmp`:

```bash
godot --path . --script res://tests/capture.gd
godot --path . --script res://tests/ui_test.gd
godot --path . --script res://tests/feature_test.gd
godot --path . --script res://tests/features_capture.gd
godot --path . --script res://tests/style_capture.gd
```

Layout, graphics and cosmetics checks are in `tests/layout_test.gd`, `tests/graphics_test.gd` and `tests/cosmetics_test.gd`. See [verification results](verification.md) for recorded test runs and visual checks.


## Localization and player appearance

English and Italian catalogs live in `locales/en.po` and `locales/it.po`. Use English source text as the translation key. Translate UI templates before formatting arguments. For messages sent over the network, use `CatanI18n.message()` and mark resource terms with `CatanI18n.term()`; clients render these in their own language. Leave player names as plain arguments. Language selection is saved locally under Settings → Controls.

Player colors are opaque six-digit RGB values. An empty value uses the seat palette. The host validates changes and includes them in lobby and game snapshots. Players can edit their own appearance; the room controller can also edit bots. Protocol 10 adds the color handshake and structured localized messages.

Run `python3 -m unittest discover -s tests -p 'test_localization.py'`, `tests/localization_appearance_test.gd`, and `tests/cosmetics_network_test.gd` when changing these features. Pass `-- --italian` to `tests/layout_test.gd` to check Italian at all supported window sizes. `tests/ui_localization_test.gd` checks dynamic card, resource, phase and soundtrack text, language switching, and checked-hover theme coverage. Run it with graphics to capture day/night hover states and the Italian color picker. Catalog checks cover translation calls, settings options, soundtrack metadata, tutorial content and development cards, including printf argument compatibility.

## Scenery and placement

`assets/world/layout.json` defines cottages, work areas, return paths and sleeping places. Both `scripts/world_layout.gd` and the Blender generator read it. Keep the numbered tiles and a 0.40-unit radius around board corners clear; cities extend beyond their circular bases. One tile unit is 25 metres: regular hexes measure 50 metres tip to tip and about 43.3 metres across their flats. Workers and sheep retain their earlier physical size while the scenery expands. Town buildings are 20% taller; settlements contain 6 animated residents and cities contain 16. Residents take independent short trips between courtyard spots, turn before walking, pause and gesture on different schedules, and disappear at night.

Rebuild scenery with `blender --background --factory-startup --python tools/build_premium_tiles.py`, then import the project in Godot. The generator writes twelve biome models and `assets/source/sculpted-tiles.blend`. Plants and small props avoid occupied areas. Extra saplings, flowers, log piles, brick drying racks, hay feeders, cargo wagons and broken columns fill clear pockets in each biome. Sheep are created only at runtime.

Run `tests/world_placement_test.gd` headlessly to check the imported meshes against worker routes, token positions, city footprints and harbors. Run `tests/world_capture.gd` with graphics to capture each biome from both sides, night pasture and the board at low detail. Captures are saved under `/tmp/catan-world-*.png`.

The surrounding archipelago is generated at runtime by `scripts/background_landscape.gd`, with one mesh per island. Keep all its geometry beyond 9.5 scenery units so boat routes remain open. `shaders/background_landscape.gdshader` adds distance haze and fades the camera-facing islands during orbiting. Run `tests/background_landscape_test.gd` and `tests/sea_traffic_test.gd` when changing it.

Audio shutdown drains pending playback commands before releasing players, then allows the mixer to finish cleanup. Test scenes that free live audio wait briefly before quitting for the same reason. Fullscreen and window-size preferences apply only to standalone windows; embedded editor sessions retain their host window.


## Diagnostic logs

Release 0.2.1 records debug breadcrumbs for startup, screen changes, settings,
board updates, gameplay actions, connections and shutdown, plus a health sample
once a minute. Engine errors include source locations and GDScript call stacks;
engine crash-handler output is captured when the process can still write it.
No player hands, names, room passwords or reconnect tokens are deliberately logged.
Standard stdout is excluded so printed dedicated-server invites stay out of logs.

Logs are in Godot's user-data `logs/diagnostics.log`, with `.1` through `.3`
rotated backups: at most four 1 MiB files. Each accepted write is flushed. Identical
messages are suppressed for 30 seconds and output is limited to 60 messages per
10 seconds, with suppression totals on the next accepted entry. The old engine
file logger is disabled; existing `godot*.log` files are left untouched.
On Linux the folder is `~/.local/share/godot/app_userdata/CATAN · Tides & Timber/logs/`.
Attach all four diagnostic files after a crash. A hard OS kill can leave only the
last completed breadcrumb; the logger cannot guarantee a native stack for every crash.

Settings → Graphics → Day/night cycle can hold the island and interface in daylight.
The preference is local and saved independently of graphics presets; the shared
world clock continues, so enabling it again restores the room's current time.
