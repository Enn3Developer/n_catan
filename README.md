# CATAN · Tides & Timber

## AI usage disclaimer

This game was made 100% by AI, GPT-6 Astra, mainly for me and my friends. If this project's existence bothers you because you're anti-AI or for any other reason, you can close the tab. If you want to try it out and play with your friends, keep reading.

## About the game

A 3D Catan-style game built in Godot 4, with solo play and online rooms for 3 to 6 participants. Bots can fill empty seats in either mode. The board has animated water, boats, sheep and workers, with a day/night cycle that changes their activity.

This is an independent fan project, not an official Catan product. Texture maps come from Poly Haven. Asset sources and licenses are listed below.

## Run the game

Download a ZIP from [GitHub Releases](https://github.com/Enn3Developer/n_catan/releases) when a release is available. Extract it into a writable folder and launch `N Catan.x86_64` on Linux or `N Catan.exe` on Windows. Keep the updater beside the game executable.

To run from source, install Git LFS and run `git lfs pull` after cloning. Open `project.godot` in Godot 4, let it import the assets, then press F5. You can also use:

```bash
./run.sh
```

The project has been tested with Godot 4.7.2 on Linux. It uses the Forward+ renderer and requires a Vulkan-capable GPU. The launcher looks for `godot`, `godot4`, or the local Godot installation. Set `GODOT_BIN` to use another executable.

## Solo play and bots

Choose **Play solo** to open an offline lobby with two Normal bots. Solo games need 2 to 5 bots. All matches need 3 to 6 participants, and adding a fifth or sixth enables the extension board. Add or remove bots, choose their difficulty, then start the game. Solo play opens no network socket.

Online hosts can add bots too. On a dedicated server, the first human player controls them.

- Easy bots explore placement options and trade less consistently.
- Normal bots value production and build toward reachable settlement sites.
- Hard bots also account for resource diversity, existing income, ports and expansion costs.

Bots follow the same rules as humans. They build, upgrade, trade with the bank, accept player offers, discard, move the robber and use development cards. They cannot see opponents' private hands or the development deck.

Choose **Learn to play** for ten guided lessons on the game board. The lessons cover placement, production, upgrades, trading, the robber, development cards and scoring. Later lessons identify the extra resources supplied for practice. You can revisit, retry or skip lessons, and the in-game Guide remains available afterward.

## Play over the internet

1. Choose **Play online**, select **Host**, enter an optional room password, then choose **Create room**.
2. Make UDP port 24567 reachable on the host. Use **Enable automatic router mapping** if the router supports UPnP. Otherwise, forward UDP 24567 to the host computer and allow it through the firewall.
3. Enter the host's public IP address or DNS name in the lobby, then choose **Copy invite**. Share the complete invite through a trusted channel.
4. Friends choose **Play online**, select **Join**, paste the invite and enter the room password, then choose **Join room**.
5. Everyone chooses **I'm ready**, then the host starts the game.

The game uses ENet with DTLS certificate verification. It has no hosted relay, accounts, public matchmaking or NAT hole punching. A host behind carrier-grade NAT needs a public dedicated server. The address `127.0.0.1` works only for testing on the same machine.

Automatic router mapping requests a one-hour lease. For longer sessions, use a persistent forwarding rule or a public server.

### Dedicated server

On a machine with a public address, run:

```bash
./run.sh --server --address=your-public-hostname:24567 --password=your-room-password
```

The server needs no graphics or local player. Open UDP 24567 in its firewall. Each process hosts one room, and the first connected player can start the game once everyone is ready.

On startup, the server prints `CATAN_SERVER_READY port=24567` and a `CATAN_SECURE_INVITE`. Share the invite with guests. The `--address` argument sets the public address included in it.

### Disconnects and reconnection

A disconnected client pauses the match. Choose **Reconnect to expedition** on that client's menu to reclaim its seat and private hand. The saved session token and certificate invite survive client restarts. Re-enter the room password after restarting.

The host must still be running. Closing the host closes the room. Persistent match saves and server migration are not implemented.

## Rules and controls

- Place two settlements and adjoining roads in snake order. The second settlement grants resources from its adjacent hexes.
- Roll each turn. Settlements collect one resource from matching adjacent hexes, and cities collect two. The robber blocks production on its hex.
- Build connected roads and keep settlements at least two edges apart. Upgrade settlements into cities. Each player has 15 roads, 5 settlements and 4 cities.
- Trade with other players or with the bank at 4:1. Ports improve the rate to 3:1 or a resource-specific 2:1. The trade screen supports one resource type for another, with adjustable quantities.
- On a seven, players holding more than seven resources choose half to discard. The active player then moves the robber and chooses a neighboring victim.
- Development cards include knights, road building, year of plenty, monopoly and hidden victory points. New action cards wait until the next turn, and players may use only one per turn.
- Longest road requires at least five edges. Largest army requires at least three played knights. Each awards two points. Enemy settlements break road paths, and ties leave the award with its current holder.
- Reach ten points on your turn to win.

Development cards appear below the action bar. Hover for their effects and ready or newly purchased counts. Your score tooltip includes hidden victory-point cards. Other players' hidden points appear only when the game ends. Build buttons require enough resources, an available piece and a legal location.

The bank trade screen shows port rates, bank stock and a preview of the exchange. It stays open after a trade. Dice animations finish on the values rolled by the server. Reduced motion shows the result immediately.

| Control | Action |
| --- | --- |
| Click a glowing marker | Build or move the robber |
| Right-drag | Orbit and tilt |
| Middle-drag | Pan |
| Scroll | Zoom toward the pointer |
| F | Focus the tile under the pointer |
| H or Inspect | Hide the interface and inspect the board. This pauses solo play. |
| H or Esc | Leave inspection |
| Home | Fit the board in view |

Hover over buttons to see costs. The in-game Guide explains the turn sequence.

## Five- and six-player extension

A lobby with five or six participants uses 30 hexes and paired turns. Three or four participants use the base board. These rules apply to solo, hosted and dedicated-server games.

The extension has 30 terrain hexes, including two deserts, 28 number tokens, 11 ports and 24 cards of each resource. Its 34 development cards comprise 20 knights, 5 victory points and 3 of each progress card. Each player keeps the usual piece limits. Terrain and number tokens are randomized, with adjacent 6 and 8 tokens kept apart.

Paired turns follow the [official extension rules](https://www.catan.com/sites/default/files/2024-03/Catan%20Game%205-6%20Rules%202022%20240313.pdf):

- The main player rolls, resolves production or the robber, then trades and builds.
- The player three seats ahead takes the paired turn next. They can build, buy or play development cards, and trade with the bank or ports. They cannot roll or trade with other players.
- The next main player receives the dice after the paired turn. Both roles advance one seat.
- Each player may play one eligible development card during their part of the turn. Cards bought during that part become available once it ends. Either player can win at ten points, but the main player has priority before the paired turn starts.

The interface identifies paired turns and disables unavailable actions. The server enforces the restrictions for humans and bots. Six-player rooms support private hands and reconnection.

## Settings and interface

Open **Settings** from the main menu, lobby or game. Graphics, Controls and Audio have separate tabs. Changes apply immediately and persist in `user://settings.cfg`. Settings pause a solo match, while online matches continue.

Graphics options include window size, fullscreen, VSync, frame limits, render scale, bilinear or FSR 1 upscaling, and a performance overlay. Low, Medium, High, Ultra and Custom presets control model detail, texture resolution, vegetation, particles, shadows, lighting, reflections and water.

You can choose FXAA, MSAA or TAA, anisotropic filtering up to 16×, screen-space indirect lighting or SDFGI, bloom, haze, exposure and depth of field. Texture tiers use 512-, 1024- or 2048-pixel maps. Controls include reduced motion, larger small text, camera sensitivity and bot turn speed. Audio has separate master, music, effects and ocean ambience volumes.

The default window is 1440×900, with a minimum of 800×600. Menus and dialogs scroll where needed. The camera fits the board above the action bar. Text uses Fira Sans, and board numbers and port labels appear in a 2D layer to stay readable.

Hover over player badges to see public card counts, road length and awards. Hover over resource icons for their names. The book opens the game log, the question mark opens the Guide, the eye opens inspection, and the gear opens Settings.

**Exit to desktop** closes the current connection. If you are hosting, it also closes the room.

## Piece cosmetics

Open **Piece cosmetics** from the main menu or lobby. Four sets are available:

- Voyager uses timber and tiled roofs.
- Harbor uses docks and lighthouse cities.
- Citadel uses stonework and battlements.
- Wildwood uses log cabins and treehouse cities.

Drag the 3D preview to rotate the pieces, then choose **Equip set**. Previewing a set does not equip it.

Each set contains roads, settlements and cities. Roofs, trim and bases retain the player's color. The game saves your choice locally and shares it with online players. The host or dedicated-room controller can choose bot sets. Each human controls their own set, and reconnection restores the server's equipped choice. Cosmetics do not affect rules, costs or scoring.

## Island graphics

Each hex spans 20 metres from point to point, or about 17.3 metres across its flats. All six biomes have two Blender model variants. Forests have solid tree crowns, pastures have sheep and ponds, fields have crops and cottages, clay tiles have terraced hills and kilns, and mountains have ridges and mine entrances.

Settlements are three-house villages with wells. Cities have six houses, streets, a keep, walls and towers. Player colors appear on roofs and banners. Harbors have stone quays, steps, timber docks, warehouses and sailboats. A group of four hooded outlaws represents the robber.

A ten-minute day/night cycle runs during play and stops when the match pauses. Workers return to cottages at dusk, sheep gather by their fences, and birds roost. Windows and lanterns light up at night. Reduced motion freezes movement while preserving the time-of-day appearance.

Water has long swells, shoreline wash and ripples around boats. Higher Water detail adds boat ripples and foam. The sea responds to day/night lighting and harbor lamps, with direct sun specular disabled to avoid white glare. Screen-space reflections can show only what the camera sees.

The editable biome source is `assets/source/sculpted-tiles.blend`. The script `tools/build_premium_tiles.py` generates it. Earlier Blender sources remain in the repository.

Textures use [Poly Haven CC0 maps](https://polyhaven.com/license). Their sources, URLs and hashes are in `assets/materials/sources.json`. The project contains its geometry, UI icons and synthesized audio, and bundles the Fira Sans license. Art and audio load locally at runtime.

## Sound and shared music

The soundtrack has five instrumental tracks, about six and a half minutes in total. Harbor at Dawn, Sunlit Fields, Trade Winds, Lanterns on the Water and Voyager's Waltz play in a repeating playlist.

Open **Music** on the main menu or lobby, or **Tracks** below your cards. You can view the playlist and playback progress. The host controls playback in an online room. On a dedicated server, the first player controls it. Volume and mute affect only your device.

The host supplies the playlist clock. Clients estimate network delay every two seconds and correct playback drift. Joining or reconnecting players seek to the current track and position. Track changes crossfade, and muting does not stop the local clock. Music continues during a gameplay pause unless the host pauses playback. Device latency and uneven network delays can cause small differences between players.

The game also has ocean ambience and sound cues for actions and events. The scripts `tools/generate_audio.py` and `tools/generate_soundtrack.py` synthesize the audio without downloaded music or samples. The original harbor theme and ocean ambience use 44.1 kHz stereo PCM loops. The four additional tracks use stereo Vorbis and occupy about 4 MiB combined.

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

Export presets exclude authoring textures, old models, tests, generated releases and unused material maps. They retain the game's texture tiers, audio, font license and texture source information. The original assets and Blender sources remain in the repository. See [build size measurements](docs/build-size.md) for the earlier size reduction and validation results.

## Releases and updates

The game checks [GitHub Releases](https://github.com/Enn3Developer/n_catan/releases) for the latest stable version at startup. Open **Game updates** on the home screen or **Updates** in Settings, choose **Download update**, then **Restart to update**. You can keep playing while it downloads, but must leave the room before installing. Dedicated servers do not update automatically.

The exact Git tag sets the application and manifest version. Multiplayer uses a separate protocol number, currently 9. Releases with the same protocol can play together. A protocol mismatch rejects the join and identifies both versions. If a release changes the protocol, the group should update together.

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

Secure invites contain the room's public certificate, never its private key or password. Share invites through a trusted channel. A substituted invite can authenticate a different host. The client sends the room password only after certificate verification. The server rejects bare addresses and plaintext connections. Each hosted room creates a new certificate, and reconnection uses its original invite while the host stays running. Play with a host you trust.

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

Layout, graphics and cosmetics checks are in `tests/layout_test.gd`, `tests/graphics_test.gd` and `tests/cosmetics_test.gd`. See [verification results](docs/verification.md) for recorded test runs and visual checks.
