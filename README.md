# CATAN · Tides & Timber

A playable 3D Catan-style game with **singleplayer and 3–6 participant online rooms**, built in Godot 4 with original Blender scenery. Fill empty seats with adjustable bots in either mode. Textured terrain, animated water, boats, seabirds, a lighthouse, forests, fields, sheep, rocky mountains, and detailed settlements form a miniature island world.

## Run

Open `project.godot` in Godot 4 and press **F5**, or run:

```bash
./run.sh
```

Tested with Godot 4.7.2 on Linux using Forward+ (Vulkan). Forward+ is the default and enables screen-space lighting, reflections, SDFGI and cinematic depth of field. The launcher finds `godot`, `godot4`, or the Godot executable installed on this machine. Set `GODOT_BIN` to use another executable. Import the project in the editor once when opening a fresh checkout so the GLB assets are imported.

## Compact Linux build

The current standalone executable is **220.77 MiB**, compared with **490.88 MiB** for the older build: **55.0% smaller**. Run `build/linux/N Catan.x86_64`; the source project and Godot editor are not required. A compressed copy is available at `build/N-Catan-linux-x86_64.tar.xz`.

Rebuild with matching Godot export templates installed:

```bash
./tools/export_linux.sh
```

Set `GODOT_BIN` if needed. The script stages a release export, verifies every packed file checksum, rejects builds over 250 MiB, replaces the local executable, writes `build/linux-size-report.json`, and creates the archive. This size guard catches accidentally cleared exclusion filters before overwriting the previous release. To inspect any subsequent build:

```bash
python3 tools/audit_build_size.py 'build/linux/N Catan.x86_64' --verify
```

The Linux preset excludes authoring textures, old models, tests, build output and unused material maps. Dynamic game resources remain included. Every retained texture and audio payload is unchanged, including all 512/1024/2048 texture tiers and full-quality PCM loops. Original assets and Blender sources remain available in the project. Font licensing and texture provenance are included in the package. See [size measurements and validation](docs/build-size.md).

## Solo, bots, and the tutorial

Choose **Play solo** to open an offline lobby with two Normal bots. Solo games require 2–5 bots; all matches require 3–6 total participants. Adding a fifth or sixth participant automatically enables the extension. Add or remove bots, select **Easy / Normal / Hard** for each, then begin. Solo play opens no network socket. You can also add bots to online rooms; only the host (or first human on a dedicated server) can modify them.

- **Easy:** exploratory placement and less consistent trading.
- **Normal:** values production and builds toward reachable settlement sites.
- **Hard:** also weighs resource diversity, existing income, ports, and expansion costs.

All difficulties use normal rules and the same private information available to a human. They build, upgrade, trade with the bank, accept worthwhile player offers, discard, move the robber, and use development cards. Bots never see opponents' private hands or the development deck.

Choose **Learn to play** for ten guided lessons. Practice settlement and road placement, production, city upgrades, bank trading, the robber, and development cards on the actual board. The tutorial explains scoring and then opens the solo lobby. Later lessons use clearly identified practice resources. Previous, retry, and skip controls let you learn at your own pace; the in-game Guide remains available afterward.

## 5–6 player extension

Add players or bots until the lobby has five or six participants. The room summary switches to **30 hexes · Paired turns**. Three or four participants still use the base board. The same rules apply in solo, hosted online, and dedicated-server games.

The extension includes 30 terrain hexes (two deserts), 28 number tokens, 11 ports, 24 cards of each resource, and 34 development cards (20 knights, 5 victory points, and 3 of each progress card). Each of the six colors has the normal 15 roads, 5 settlements, and 4 cities. Terrain and number tokens are randomized, with adjacent 6/8 tokens separated, matching this game's existing randomized setup style.

Paired turns follow the [official extension rules](https://www.catan.com/sites/default/files/2024-03/Catan%20Game%205-6%20Rules%202022%20240313.pdf):

- The main player rolls, resolves production or the robber, and trades/builds normally.
- After they end, the player three seats ahead takes a paired turn. This player can build, buy/play development cards, and trade with the bank or ports. They cannot roll or trade with other players.
- After the paired turn, the next main player receives the dice. Both roles advance one seat.
- Each player may play one eligible development card in their own portion. Newly purchased cards become available after that portion ends. Either role can win at 10 points; the main player has priority before the paired portion starts.

The HUD identifies paired turns and disables unavailable actions. The server enforces the same restrictions for humans and bots. Six-person rooms retain private hands and reconnection support. All online participants need this project version (network protocol 9).

## Sound, settings, and readability

**Settings** is available in the menu, lobby, and game. Master, music, effects, and ocean ambience have separate volume controls. The five settings tabs cover display, graphics, lighting, controls, and audio. Display options include window size, fullscreen, VSync, frame limits, render scale, bilinear/FSR 1 upscaling, and a performance overlay. Low, Medium, High, Ultra, and Custom presets coordinate model detail, real 512/1024/2048-pixel PBR textures, vegetation density, particles, shadow quality, ambient occlusion, indirect lighting, reflections and water. Choose Off/FXAA/MSAA 2×/4×/8×/TAA, anisotropic filtering up to 16×, screen-space bounce or SDFGI, bloom, haze, exposure and optional depth of field. Reduced motion, larger small text, and camera sensitivity are also adjustable. Bot turn speed is adjustable. Changes apply immediately and persist in `user://settings.cfg`; restoring defaults resets them. Opening settings pauses a solo match, while online matches continue.

The game includes an original looping instrumental score, ocean ambience, and cues for clicks, dice, construction, trades, cards, turns, errors, and victory. Source synthesis is in `tools/generate_audio.py`; no downloaded music or samples are used. The original harbor theme and ocean ambience use 44.1 kHz lossless stereo PCM, full-length sample-counted loops and silent loop boundaries. The additional soundtrack tracks use stereo Vorbis to keep exports small. Ocean noise is softly filtered to reduce hiss.

UI text uses an included MSDF Fira Sans font. Board numbers and port labels are projected into a sharp 2D layer instead of being filtered text textures in 3D. The default window is 1440×900; high graphics enables 4× MSAA on the world without applying blur to UI text. Vegetation moves in the wind, chimneys emit smoke, and producing hexes briefly highlight. Reduced motion disables those animations.

## Player piece cosmetics

Choose **Piece cosmetics** directly from the main menu, below Learn to play, or from the lobby. Preview four coordinated sets: **Voyager** (timber and tiled roofs), **Harbor** (docks and lighthouse cities), **Citadel** (stonework and battlements), and **Wildwood** (log cabins and treehouse cities). Drag the live 3D preview to rotate all three pieces, then choose **Equip set**. Previewing alone does not apply a choice.

Every set includes roads, settlements and cities, with the player's color retained on roofs, trim and bases. Your selection is saved locally, used for new games and shared with online participants. Hosts and dedicated-room controllers can also choose bot sets through the player selector; other human players control their own appearance. Reconnection restores the server's equipped style. Cosmetics do not change rules, costs or scoring.

Models are generated by `scripts/cosmetics.gd`. The separate native screen `scenes/ui/cosmetics.tscn` uses `scripts/cosmetics_menu.gd` and the same model builder as the actual board.

## Sculpted island graphics

The board, terrain scenery, harbor props and player pieces share one sculpted miniature style: smooth silhouettes, beveled edges, a restrained matte palette and subtle surface grain. All six biomes have two original Blender variants. Forests use solid tree crowns, pastures have rounded sheep and inset ponds, fields have readable grain clusters and cottages, clay tiles have terraced hills and kilns, and mountains have broad ridges and mine entrances.

The geometry uses welded surface normals and closed roof faces. Shared beveled meshes coordinate the cosmetic pieces, docks and scenery. Ocean self-shadowing is disabled to prevent repeating shadow artifacts; the sun's bias is tuned for the enlarged tiles. Number labels scale with their projected token size, probability pips are actual geometry, and ports show resource icons. The robber sits on the local ground height.

Tiles remain 2.2× larger in world space, with orbit, pan and inspection zoom. Model settings adjust terrain tessellation and imported mesh LODs; foliage density and 512/1024/2048-pixel texture tiers remain adjustable. Screen-space reflections retain their normal visibility limitations. The new editable source is `assets/source/sculpted-tiles.blend`, generated by `tools/build_premium_tiles.py`. The earlier source files are retained as archives.

Subtle texture grain uses [Poly Haven CC0 maps](https://polyhaven.com/license), with provenance in `assets/materials/sources.json`. Biome geometry, UI icons and sound synthesis are original project assets. Everything is local at runtime.

## Responsive interface

The native interface responds to the window's actual dimensions, with a minimum of **800×600**. Anchored frames, containers and scrolling keep menus, six-player lobbies, settings, cosmetics and dialogs usable in small, portrait and ultrawide layouts. The camera fits the board into the space available above the action bar.

The HUD has compact player chips and a bottom resource/action bar. Hover a player for their public card counts and awards. Resource icons are shared across the hand, build costs, ports and trade offers; hover for names. The book icon opens the game log, the question mark opens the guide, the eye enters inspection, and the gear opens settings. **Play online** expands the connection form on the main menu. The trade dialog separates bank trades from player offers and displays the bank's actual exchange quantities.

## Play over the internet

1. One player chooses **Play online → Host**, enters an optional room password, then chooses **Create room**.
2. Make **UDP 24567** reachable on that host. The lobby has an explicit **Enable automatic router mapping** button for UPnP-capable routers. Otherwise, forward UDP 24567 to the host computer and allow it through the firewall.
3. Enter the host's **public IP or DNS name** in the lobby, then choose **Copy invite**. Share that complete secure invite through a trusted channel. Friends choose **Play online → Join**, paste the invite and enter the room password, then choose **Join room**.
4. Everyone clicks **I'm ready**. The host starts the expedition.

This uses real ENet internet networking. It does not include a hosted relay, account system, public matchmaking service, or NAT hole punching. A host behind carrier-grade NAT should use a public dedicated server. `127.0.0.1` works only for testing on the same machine. Router mapping is requested for one hour; long sessions should use a persistent manual forwarding rule or a public server.

### Dedicated server

On a machine with a public address:

```bash
./run.sh --server --address=your-public-hostname:24567 --password=your-room-password
```

No graphics or local player are required. Open UDP 24567 in the server firewall. The first connected player controls starting the game after everyone is ready. Each server process hosts one room. The server writes `CATAN_SERVER_READY port=24567` and a `CATAN_SECURE_INVITE` on successful startup. Share the latter with guests; `--address` sets its public endpoint.

### Disconnects

If a client disconnects, the match pauses. **Reconnect to expedition** on that client's menu restores its seat and private hand using a saved session token and certificate invite, including after restarting the client. Re-enter the room password after a restart. Closing the host closes the room. Persistent game saves and server migration are not implemented.

## Rules and controls

- Place two settlements and adjoining roads in snake order. The second settlement grants its adjacent starting resources.
- Roll each turn. Settlements collect one resource from matching adjacent hexes; cities collect two. The robber blocks its hex.
- Build connected roads and well-spaced settlements; upgrade settlements into cities. Standard costs and 15-road/5-settlement/4-city limits apply.
- Trade with other players or with the bank at 4:1, improved by 3:1 or resource-specific 2:1 ports. The trade UI offers one resource type for another, with adjustable quantities.
- On seven, players with more than seven resources choose half to discard, then the active player moves the robber and chooses a neighboring victim.
- Development cards include knights, road building, year of plenty, monopoly, and hidden victory points. New action cards wait until the next turn, and only one may be played per turn.
- Longest road (at least five edges) and largest army (at least three knights) each award two points. Longest-road paths respect enemy settlements and incumbent ties.
- Reach ten points on your turn to win. Two-player games use the same economy and turn rules; this is not the separate official two-player variant.

**Click** glowing board markers to build or move the robber. **Right-drag** to orbit and tilt. **Middle-drag** to pan. **Scroll** to zoom toward the pointer. **F** focuses the tile under the pointer. **H** or **Inspect** hides the interface for close exploration (pauses solo play); **H/Esc** returns. **Home** fits the board. Button tooltips show costs. The in-game guide explains the flow.

## Editable scene structure

`scenes/main.tscn` instances **Network**, **Board**, and **Audio** scenes. `scenes/board.tscn` contains the camera rig, sun, environment, terrain, buildings, markers, and scenery nodes. Terrain is generated at runtime.

The editable native UI scenes are `scenes/ui/home.tscn`, `lobby.tscn`, `player_slot.tscn`, `hud.tscn`, `settings.tscn`, and `tutorial.tscn`. Their named Controls define layout in the Godot scene editor. `assets/ui_theme.tres` supplies the shared editor-visible theme. `tools/create_ui_scenes.py` is an optional authoring helper; it is never run by the game and should not be rerun over manual scene edits unless regeneration is intended.

## Implementation

- `scripts/rules.gd`: deterministic board topology, rules, economy, scoring, private snapshots.
- `scripts/network.gd`: authoritative ENet host, lobby, passwords, per-peer snapshots, rate limiting, reconnection, optional UPnP.
- `scripts/board.gd`: procedural 3D terrain, buildings, scenery, picking, camera, animations.
- `scripts/main.gd`: scene wiring and game interface.
- `scripts/bot.gd`: fair bot decisions and difficulty policies.
- `scripts/tutorial.gd`: guided practice scenarios.
- `scripts/settings.gd` and `scripts/audio.gd`: persisted preferences and audio buses.
- `assets/premium/*.glb`: twelve original sculpted Blender biome variants with imported mesh LODs.
- `scripts/tile_art.gd`: textured terrain, biome materials, mesh detail and texture tiers.
- `assets/materials/`: Poly Haven CC0 source maps and runtime PBR tiers; exact sources, URLs and hashes in `sources.json`.
- `assets/source/sculpted-tiles.blend`: editable sculpted biome models, excluded from Godot auto-import. `tools/build_premium_tiles.py` regenerates them using Blender; texture preparation is in `tools/prepare_tile_textures.py`.
- `shaders/`: textured ground/cliffs, triplanar PBR surfaces, animated foliage, and a layered ocean with shoreline foam and shallow-water tint.

The server owns dice, deck, hands, resources, and action validation. Clients receive other players' card/resource counts, not their private contents. All online ENet traffic uses DTLS with certificate verification. Secure invites contain the room’s public certificate, never its private key or password. Share invites through a trusted channel: possession of a substituted invite could authenticate a different host. The room password is sent only after DTLS verification. Bare addresses and plaintext connections are rejected. Each hosted room generates a new certificate; reconnect retains the original invite while that host stays running. Play with a trusted host.

## Verification

The current art/UI regression checks are `tests/layout_test.gd`, `tests/graphics_test.gd`, `tests/ui_test.gd`, `tests/feature_test.gd`, and `tests/cosmetics_test.gd`. Render the populated board and all biomes with `tests/style_capture.gd`. See `docs/verification.md` for results.

```bash
# Replace godot with your Godot executable as needed.
godot --headless --path . --script res://tests/rules_test.gd
godot --headless --path . --script res://tests/network_test.gd
godot --headless --path . --script res://tests/bot_test.gd
godot --headless --path . --script res://tests/bot_network_test.gd
godot --headless --path . --script res://tests/solo_match_test.gd
GODOT_BIN=/path/to/godot python3 tests/run_online_test.py

# Requires a graphical session; writes PNG captures under /tmp.
godot --path . --script res://tests/capture.gd
godot --path . --script res://tests/ui_test.gd
godot --path . --script res://tests/feature_test.gd
godot --path . --script res://tests/features_capture.gd
```

The rule suite checks topology, setup, conservation over 150 turns, legality, trades, development cards, privacy, longest road, largest army, and victory. The network suite creates three ENet peers and tests lobby replication, setup, private hands, invalid moves, dice, disconnects, and reconnection. The dedicated test runs a separate server and two separate clients through several turns. These transport tests run over loopback; connectivity through a particular internet router still depends on its forwarding/firewall configuration.

The bot suite completed twelve full games (4,117 actions) covering every difficulty and mixed opponents. The feature suite exercises the native lobby controls, bot configuration, live solo setup, all ten tutorial lessons, saved settings, audio gains and playback. A separate live solo match runs the actual bot scheduler to victory. Mixed online rooms test bot synchronization, private bot hands, guest restrictions, and dedicated-server control.

Visual captures of the menu, setup board, developed island, card dialog, and lower-angle world view were inspected in Godot. This project is an independent fan implementation with original generated art, not an official Catan product.

Extension regression commands:

```sh
godot --headless --path . --script res://tests/extension_test.gd
godot --headless --path . --script res://tests/extension_bot_test.gd
godot --headless --path . --script res://tests/extension_solo_test.gd
godot --path . --script res://tests/extension_ui_test.gd
python tests/run_online_test.py 6
```

## September gameplay update

Development cards are always visible below the action bar. Hover a card for its ready/new counts and effect. Your score tooltip includes both held and newly bought victory-point cards; opponents' hidden points are revealed only at game end. Player badges show points, resources, cards, road length, and played knights. Building buttons require an available piece and a legal location as well as resources.

Trading uses clickable resource icons, a give/receive preview, port rates, bank stock, and affordability explanations. The bank screen stays open after an exchange. A ten-minute day/night cycle runs during active play; solo pause and a disconnected participant freeze it. Dice tumble onto the map and finish on the server's rolled values. Reduced motion shows their results immediately.

Reconnect credentials survive client restarts. Use **Play online → Reconnect** to reclaim your seat. For a password-protected room, re-enter its password after restarting the app. The host must still be running. The same saved seat can replace a stale connection without waiting for its timeout. This update uses protocol 9; all participants need the updated build.

Export Windows with `bash tools/export_windows.sh`. It uses the same asset exclusions as Linux, verifies every packed resource, rejects releases above 275 MiB (Windows has a larger engine template), and creates `build/N-Catan-windows-x86_64.zip` with `build/WINDOWS-SHA256SUMS`. Linux retains its 250 MiB guard.


## Shared soundtrack

The original **Harbor at Dawn** is joined by **Sunlit Fields**, **Trade Winds**, **Lanterns on the Water**, and **Voyager's Waltz**: about six and a half minutes of original instrumental music. The playlist advances automatically and repeats. New tracks are synthesized from original arrangements by `tools/generate_soundtrack.py` and stored as 44.1 kHz stereo Vorbis; their combined compressed size is about 4 MiB. The original soundtrack and effects remain intact.

Open **Music** on the main menu or lobby, or **Tracks** in the persistent music section below your cards. View the playlist, current track, and progress. Previous, pause/resume, next, and track selection control playback; volume and mute apply only to your device. In an online room only the host controls transport; on a dedicated server the first player controls it. Solo and menu playback are fully controllable.

The host owns the playlist clock. Clients estimate one-way delay from round-trip probes every two seconds, predict track boundaries between samples, and correct local playback drift. Joining/reconnecting players seek to the room's current track and position. A short crossfade softens track changes; muting never stops your clock. Music continues while gameplay is paused unless the host pauses the soundtrack itself. This is network clock synchronization, not sample-accurate multi-speaker audio; device latency and asymmetric internet connections can introduce small differences.

All online participants need this update (protocol 9). Music checks: `tests/music_test.gd`, `tests/music_network_test.gd`, `tests/music_ui_test.gd`, and `python3 tests/run_music_process_test.py`.

## Living medieval island

Hex tiles now span 20 metres point to point (about 17.3 metres across the flats), retaining their regular hex geometry. The camera, shadows, haze and dice use the enlarged scale. Pastures have grazing, walking sheep; fields have working farmers, with woodcutters and quarry workers on other productive terrain. Reduced motion freezes their animation.

Settlements are three-house medieval villages with wells; cities contain six houses, streets, a central keep, walls and towers. Player colours remain on roofs and banners. Coastal harbors have raised stone quays, descending steps, timber docks, rope rails, warehouses and bobbing sailboats.

All display, rendering, lighting and water options share the **Graphics** tab. Controls/accessibility and audio retain their own tabs. **Exit to desktop** is available on the main menu and in settings; exiting closes the current connection (and the room if hosting).

The robber is a four-person hooded outlaw band with stolen supplies and a small camp, kept in the clearing at the front of its blocked tile. Its game rules are unchanged. The shared ten-minute day/night cycle now governs island life: workers return to cottages at dusk and reappear at dawn; sheep gather by the fence and rest overnight; birds roost after sunset. Window and lantern light fades in at dusk. Cities have six lit houses and five street lanterns, compared with one lit house and one lantern in settlements. Harbor lanterns and the outlaw camp also light up at night. Reduced motion preserves the time-of-day appearance while freezing movement.

Water uses a matte teal palette with gentle long swells, broken shoreline wash, subtle shallow-water patterns and ripples around boats. Continuous world-space normals and filtered detail avoid mesh-grid seams and distant shimmer. Direct sun specular is disabled on the sea to prevent white glare; the surface still responds to day/night lighting and harbor lamps. Higher Water detail adds boat ripples and small foam accents. Reduced motion freezes the water effects.

## Releases and updates

Public repository: https://github.com/Enn3Developer/n_catan

Release ZIPs contain the game, `n-catan-updater` (`.exe` on Windows), and a
README. Extract all files into a writable folder. The first installation is a
manual download; after that the game checks GitHub's latest stable release at
startup. **Game updates** on the home screen or **Settings → Updates** offers
**Download update**, then **Restart to update**. Leave the current room first.
The running game remains usable while downloading. Dedicated servers do not
update automatically.

The exact Git tag is the application and manifest version. Multiplayer protocol
9 is checked separately: compatible release versions can play together, while a
protocol mismatch rejects the join and identifies both versions. Releases that
change the protocol should be installed by the whole group.

The helper verifies an RSA/SHA-256 signed manifest using its embedded public key,
then verifies package and executable SHA-256 hashes. It chooses a delta only if
the installed executable exactly matches a published base and the patch is less
than 85% of the full download. Any delta failure falls back to a full package.
The release builder reuses unchanged blocks of packed resources and always uses
the exact previous published binary, never a rebuilt old tag. The first release
has full packages only; later releases can patch from the previous stable release.

Installation waits for the game to exit, retains the old executables, and rolls
back if the replacement fails to finish startup. If installation is interrupted,
launch the updater directly to recover and open the game. Keep the entire install
folder together; one previous backup is retained. Settings and saves remain in
Godot's user data folder. Pre-releases are available for manual testing and are
not offered by the stable update channel.

### Publishing

Git LFS tracks all assets and image files; clone with Git LFS installed and run
`git lfs pull`. Local `build/`, `dist/`, caches, and private keys are ignored.

The **Release** GitHub Actions workflow runs on a version tag push or a published
release. Use SemVer tags such as `v1.0.0` or `v1.1.0-rc.1`; the tag is preserved
exactly in the manifest. The workflow builds Linux x86-64 and Windows x86-64,
including their native updater helpers, using the verified Godot version pinned
in `config/release.json`. It uploads full ZIPs, useful delta ZIPs, `SHA256SUMS`,
and the signed `update-manifest.json`. A tag push creates a draft release and
publishes it after uploading the assets; publishing a release manually attaches
the same assets. Completed signed releases are not overwritten, and moving a tag
to another commit is rejected. Retry a failed run to finish an incomplete release.

The repository secret `UPDATE_SIGNING_PRIVATE_KEY` is required and has been
configured. Its matching public key is `updater/update_public.pem`. Back up the
private key securely: losing it prevents existing clients from trusting new
updates. Replacing the public key without a transition release requires a manual
installation. The private key must never be committed or included in a build.

The workflow also supports manual dispatch for an existing tag, with publishing
disabled by default, to validate the complete build and download its Actions
artifacts. CI runs updater, patch producer, and game rules tests on main and PRs.
For local builds, use `tools/export_linux.sh` and `tools/export_windows.sh` with
Godot export templates and Go installed. Release tooling lives in
`tools/release.py`; `stamp` changes version metadata only in the build checkout.
