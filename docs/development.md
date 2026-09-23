# Development

Build and release reference for contributors.

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

Export presets exclude authoring textures, old models, generated releases and unused material maps. They retain the game's texture tiers, audio, font license and texture source information. The original assets and Blender sources remain in the repository. See [build size measurements](build-size.md) for the earlier size reduction and validation results.

## Releases and updates

The game checks [GitHub Releases](https://github.com/Enn3Developer/n_catan/releases) for the latest stable version at startup. Open **Game updates** on the home screen or **Updates** in Settings, choose **Download update**, then **Restart to update**. You can keep playing while it downloads, but must leave the room before installing. Dedicated servers do not update automatically.

The exact Git tag sets the application and manifest version. Multiplayer uses a separate protocol number, currently 14. Releases with the same protocol can play together. A protocol mismatch rejects the join and identifies both versions. If a release changes the protocol, the group should update together.

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

The main scene, `scenes/main.tscn`, contains the Network, Board and Audio scenes, the updater, the interface day/night driver and the interface layer. `scripts/main.gd` shows one screen at a time, presents dialogs and routes their signals to the network and board.

The interface lives in `scenes/ui/`. The home, lobby and in-game screens extend `CatanScreen`, every dialog inherits `dialog.tscn`, and repeated widgets such as player chips, development cards, preference rows and resource rows are scenes of their own. Screens and dialogs report intent through signals. Buttons that should click join the `ui_click` group. `assets/ui_theme.tres` supplies the shared theme, including the `PrimaryButton`, `MusicIconButton`, `HeadingLabel` and `ErrorLabel` variations. Regenerate it with `tools/build_ui_theme.py`.

The board scene contains the camera, sun, sky environment, ocean, terrain, buildings and scenery, including the lighthouse, sailboats and offshore rocks. Number tokens, placement markers, production rings, chimney smoke, dice and weather are scenes in `scenes/world/`; the model-backed ones inherit their Blender model. The board still arranges tiles, pieces, towns, harbors and actors at runtime, but every model comes from Blender (see [Models](#models)). Audio buses are defined in `default_bus_layout.tres`.

| Path | Purpose |
| --- | --- |
| `scripts/rules.gd` | Board topology, rules, resources, scoring and private snapshots |
| `scripts/network.gd` | ENet host, lobby, passwords, replication, reconnection and UPnP |
| `scripts/board.gd` | Terrain, buildings, picking, camera and animations |
| `scripts/main.gd` | Screen and dialog routing, preferences and session flow |
| `scripts/*_screen.gd`, `scripts/*_dialog.gd` | Home, lobby and HUD screens; dialogs |
| `scripts/bot.gd` | Bot decisions and difficulty settings |
| `scripts/tutorial.gd` | Guided practice scenarios |
| `scripts/settings.gd`, `scripts/audio.gd` | Preferences and audio buses |
| `scripts/cosmetics.gd`, `scripts/cosmetics_menu.gd` | Piece models and cosmetics screen |
| `scripts/tile_art.gd` | Terrain materials, model detail and texture tiers |
| `assets/premium/` | Twelve Blender biome variants |
| `assets/materials/` | Texture sources and runtime maps |
| `assets/models/` | Blender exports: pieces, actors, settlements, props, terrain and the mainland |
| `assets/source/` | Editable Blender models |
| `tools/prepare_tile_textures.py` | Texture preparation |
| `shaders/` | Ground, cliffs, foliage and water |
| `scripts/build_info.gd`, `scripts/updater.gd` | Version metadata and update interface |
| `updater/` | Native update verification and installation helper |

The server owns dice rolls, the deck, hands, resources and action validation. Clients receive other players' public counts, not private cards.

Each turn has a 60-second limit, held by the host in `CatanNetwork.turn_seconds`. One clock covers the whole turn, including the setup settlement and its road, the robber move and the steal that follows. It restarts when the turn passes to the next seat, and also when a seven hands the wait to the players who must discard, since they have had none of that turn's time. It pauses while the room is paused or a player is reconnecting. Solo games and tutorial lessons have no limit. When the clock runs out, the host plays the stalling seat out along the shortest legal exit: it rolls if the seat has not rolled, places the settlements, roads, robber and steal the rules demand, discards down to the limit, then ends the turn. Every snapshot carries `turn_limit` and `turn_seconds`, and clients run the countdown in the HUD between snapshots.

Online rooms use ENet over authenticated DTLS. The `NC1-` invite carries the endpoint, a 128-bit SHA-256 certificate fingerprint and a two-byte typo checksum, encoded as canonical base64url. IPv4 with the default port takes 35 characters; custom ports and DNS names take more. The host generates a fresh RSA certificate for each room. Clients retrieve that public certificate automatically and check its fingerprint before starting a standard DTLS handshake. Only that certificate is trusted, and room passwords and reconnect tokens are sent after the handshake succeeds. The invite authenticates the host; a room password still controls admission.

A public UDP socket on 24567 serves certificate discovery and forwards encrypted datagrams to an ENet listener bound to loopback on an ephemeral port. This local forwarding needs no extra public port or external lookup service. Certificate responses are no larger than the padded requests, and relay allocations are bounded. Godot/mbedTLS handles encryption and separate session keys for each client. The public certificate and endpoint remain visible on the wire. Share invites through a trusted channel: replacing an invite replaces the host identity the client trusts.

Protocol 14 adds the turn timer; protocol 13 rejected bare addresses and older certificate invites, with no plaintext fallback. Saved reconnect invites remain valid while the original room runs; restarting the host requires a new invite. The certificate is valid for 30 days, so rooms left running longer must restart. Clients must update together. Update downloads retain signature and hash verification.

## Verification

CI runs the updater's Go tests with the race detector, vets it, compiles the Windows updater and imports the Godot project.

```bash
go -C updater test -race ./...
```

## Localization and player appearance

English and Italian catalogs live in `locales/en.po` and `locales/it.po`. Use English source text as the translation key. Translate UI templates before formatting arguments. For messages sent over the network, use `CatanI18n.message()` and mark resource terms with `CatanI18n.term()`; clients render these in their own language. Leave player names as plain arguments. Language selection is saved locally under Settings → Controls.

Player colors are opaque six-digit RGB values. An empty value uses the seat palette. The host validates changes and includes them in lobby and game snapshots. Players can edit their own appearance; the room controller can also edit bots. Protocol 10 adds the color handshake and structured localized messages.


## Models

Every mesh in the game is modeled in Blender. Only shader and particle carriers stay Godot primitives: the ocean plane, rain, lightning, pollen and chimney smoke. The lighthouse beam is its spot light scattering in a night-only `FogVolume` of sea haze; it needs Forward+ with Atmosphere enabled, and other renderers still get the sweeping light on the water. Each group has an editable source in `assets/source/` and one `.glb` per model in `assets/models/<group>/`:

| Source | Models |
| --- | --- |
| `pieces.blend` | Road, road joint, settlement and city for each piece set; the cosmetics pedestal |
| `actors.blend` | Sheep, woodcutter, quarry worker, farmer, outlaw and town dweller |
| `settlements.blend` | Village, city, cottage, harbor, robber camp and worksites |
| `props.blend` | Sailboat, lighthouse, number token, die, markers, production halo and offshore rocks |
| `terrain.blend` | The ground of each biome and the cliff skirt |
| `mainland.blend` | The backdrop mainland |

Export each model's collection with the glTF exporter, using **+Y Up**, **Apply Modifiers**, **Custom Properties** and, for models with lamps, **Punctual Lights**. The code relies on these conventions:

- **Pivots.** Animated parts hang from empties with an identity rest rotation, such as `Body/Leg0/Knee0` on the sheep and `Torso/UpperArm0/Forearm0` or `Torso/Tool` on workers. `scripts/living_world.gd` drives them by name.
- **Recolored surfaces.** A material named after a role, optionally with a signed percentage, takes its color at runtime: `Player`, `Player-16` (darkened 16%), `Player+07` (lightened 7%). Roles are `Player` (owner color), `Wall` (piece-set wall color), `Shirt` and `Skin`. `CatanCosmetics.paint()` applies them.
- **Textured surfaces.** Materials named `PBR_Rock`, `PBR_Wood` and similar take that surface's texture tier from `CatanTileArt.surface()`.
- **Night lights.** Meshes named `NightWindow`, `NightLantern` or `Campfire` glow at night, lit by the `NightLight` point light that shares their pivot. Each light's `local_range` and `night_energy` custom properties become Godot metadata.
- **Ground.** Workers, cottages and the robber camp stand on `CatanTileArt.height_at()`, which samples the exported ground mesh. Sculpt it freely, but keep the rim at 0.20 units so tiles meet the cliffs. Godot generates the ground's LODs; Model Detail sets their `lod_bias`.

## Scenery and placement

`assets/world/layout.json` defines cottages, work areas, return paths and sleeping places. Both `scripts/world_layout.gd` and the Blender generator read it. Keep the numbered tiles and a 0.40-unit radius around board corners clear; cities extend beyond their circular bases. One tile unit is 25 metres: regular hexes measure 50 metres tip to tip and about 43.3 metres across their flats. Workers and sheep retain their earlier physical size while the scenery expands. Town buildings are 20% taller; settlements contain 6 animated residents and cities contain 16. Residents take independent short trips between courtyard spots, turn before walking, pause and gesture on different schedules, and disappear at night.

Rebuild scenery with `blender --background --factory-startup --python tools/build_premium_tiles.py`, then import the project in Godot. The generator writes twelve biome models and `assets/source/sculpted-tiles.blend`. Plants and small props avoid occupied areas. Extra saplings, flowers, log piles, brick drying racks, hay feeders, cargo wagons and broken columns fill clear pockets in each biome. Sheep are created only at runtime.

The surrounding mainland is `assets/models/world/mainland.glb`, twelve vertex-colored sectors that `scripts/background_landscape.gd` loads on clients. Keep all its geometry beyond 9.5 scenery units so boat routes remain open. `shaders/background_landscape.gdshader` adds distance haze.

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
The interface does not follow the sun gradually. `scripts/ui_day_night.gd` switches
to the night palette when daylight drops below 0.4 and back above 0.6, crossing
in a 0.6-second fade. The two palettes invert light and dark, so an interface
parked between them would put lettering and surfaces on the same grey.

Roads use a 30% vertical profile above the terrain; `CatanCosmetics.road_deck_height()` supplies the matching pedestrian surface. `scripts/road_travel.gd` assigns occasional journeys to existing residents along disjoint, same-owner road paths between towns. Visitors stop at town entrances, rest between trips, hide at night, and obey reduced motion.

Weather follows the synchronized 600-second world clock. `scripts/weather.gd` blends clear, cloudy, rainy and stormy conditions; the local Weather setting can hold any one condition. Clouds drift through a procedural sky shader and affect ambient lighting. Clear weather retains a few scattered clouds and sunlight. Cloudy, rainy and stormy weather disable direct sunlight and directional shadows, with bounded rain particles and an offshore lightning effect. Rain/thunder audio goes through the Ambience bus. Reduced motion stops moving clouds and suppresses rain particles, water ripples and lightning flashes. Water uses four Gerstner swells, shore attenuation, filtered surface ripples and a narrow sun glitter reflection. The mesh concentrates vertices around the island. Boats sample the same wave parameters as the shader. See NVIDIA’s [water model](https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-1-effective-water-simulation-physical-models) and Godot’s [sky shader documentation](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/sky_shader.html). Original weather audio can be regenerated with `python3 tools/generate_weather_audio.py`.

Seagulls use the original Blender model in `assets/premium/seagull.glb`, with its editable source in `assets/source/seagull.blend`. `tools/build_seagull.py` builds a separate scene through Blender MCP or Blender Python in a fresh session. Seven meshes share a matte palette, shoulder/wrist pivots animate wingbeats, and four folded morph targets tuck the feathers against the body on landing. `scripts/seagulls.gd` reuses six visitors, with at most five active in fair weather, independent offshore arrivals, gliding and flapping, skimming, reserved harbour posts, rests and departures. Night and storms trigger a retreat; reduced motion shows static perched gulls. Perch positions refresh when the board is rebuilt, including six-player scale.
