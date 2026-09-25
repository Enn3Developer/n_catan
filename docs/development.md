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

Export presets exclude authoring textures, generated releases and tooling. They retain the game's texture tiers, audio, font license and texture source information. The full resolution textures and Blender sources remain in the repository. `tools/prepare_tile_textures.py` writes only the runtime maps `tile_art.gd` samples, so unused maps never enter the project. See [build size measurements](build-size.md) for the earlier size reduction and validation results.

## Releases and updates

The game checks [GitHub Releases](https://github.com/Enn3Developer/n_catan/releases) for the latest stable version at startup. Open **Game updates** on the home screen or **Updates** in Settings, choose **Download update**, then **Restart to update**. You can keep playing while it downloads, but must leave the room before installing. Dedicated servers do not update automatically.

The exact Git tag sets the application and manifest version. Multiplayer uses a separate protocol number, currently 18. Releases with the same protocol can play together. A protocol mismatch rejects the join and identifies both versions. If a release changes the protocol, the group should update together.

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

The interface lives in `scenes/ui/`. The home, lobby and in-game screens extend `CatanScreen`, every dialog inherits `dialog.tscn`, and repeated widgets such as player chips, development cards, preference rows and resource rows are scenes of their own. Screens and dialogs report intent through signals. Buttons that should click join the `ui_click` group. `assets/ui_theme.tres` supplies the shared theme. Regenerate it with `tools/build_ui_theme.py`, and pick a variation instead of overriding colors or styles on a node (see [the interface guide](ui-art-direction.md#controls)).

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
| `scripts/piece_appearance.gd`, `scripts/piece_builder.gd`, `scripts/mesh_kit.gd` | Player piece looks and the procedural towns and roads built from them |
| `scripts/cosmetics_menu.gd`, `scripts/appearance_row.gd` | The Workshop, where players design their pieces |
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

### Room rules and the board

`CatanNetwork.room_settings` holds the room's rules: `seed`, `island` (one of `CatanRules.ISLANDS`: `random`, `classic` or `archipelago`), `turn_seconds` (one of `CatanRules.TURN_TIMERS`, 0 for off), `points` (5 to 15) and one boolean for each entry in `CatanRules.HOUSE_RULES` (`friendly_robber`, `random_start`, `start_card`, `treasure`, `move_ships`, `fog`). The rules in `CatanRules.SEA_RULES` only apply on the archipelago: the lobby hides their switches for other islands and `create()` turns them off. `CatanRules.HOUSE_RULE_TEXT` holds each rule's name and help, which the lobby, the victory screen and the Guide use. The Guide (`scripts/guide_dialog.gd`) is built from the game state when it opens, so it shows the room's points target and adds the five or six player, archipelago and house rule sections only in games that have them. The host picks a random seed when the room opens. Only the room controller can change a setting, only in the lobby, and the host validates every value before it broadcasts the roster and settings with `_lobby`. `rules.create(names, seed, options)` builds the game from them and stores `seed`, `island`, `points_target` and every house rule in the state. The seed is public, so it only sets what everyone can see: the island, its tiles and numbers, and the harbors. Once the board stands, `create()` reseeds `rng` from `Crypto` (or `options.hidden_seed`, which tests use), deals the tiles under the fog again with `_deal_fog()`, and shuffles the development cards. The dice bag and every later draw use the same secret stream. A settings change, or adding or removing a bot, clears `ready` for every human but the controller who made it. `remove_player()` lets the controller send a guest out of the lobby: the host tells the guest why with `_registration_failed` and closes the link two seconds later if the guest hasn't left. A guest in a resumed game's seat leaves the seat open for its owner. `_unique_name()` adds " 2", " 3" and so on to a name already in the room, for guests and bots alike.

Dice come from a shuffled deck of the 36 outcomes of two dice, reshuffled when 5 or fewer remain (`CatanRules.DICE_RESHUFFLE`). The deck stays on the host; `snapshot()` removes it. Tests and the tutorial pick a roll with `force_roll()`.

A random island grows outward from one hex. Each step picks a free neighbor, weighted towards hexes with more land around them, so the coast is ragged without long thin spits. Shapes that enclose water are thrown away and grown again. The finished island is centered on its average tile position. Tile and vertex keys are built before centering so shared corners round the same way. `CatanRules.island_scale()` returns how far the scenery ring (rocks, lighthouse, mainland) must scale out to clear the island, and the board uses it in place of the old fixed scale. Harbor types are shuffled with the same seed and spread evenly along the walked coastline from a seeded starting edge. Edges that face a narrow bay are skipped so moored boats have open water.

Random start skips the setup phases. `_random_setup()` ranks every open corner by pips plus new resource types and gives each player picks from the upper band, so starts are good without all being the best. Starting card deals one development card to each player when setup ends, and it can be played on the first turn. The treasure is tile kind `CatanRules.TREASURE` (6) on a coastal hex. `_treasure_near()` lists the corners within 2 steps of it, and setup refuses them. When its number is rolled and the robber is elsewhere, `_pay_treasure()` pays 2 random resources per settlement and 4 per city, then draws a new number from `TREASURE_NUMBERS` (2 to 12 without 7). The board reprints its token.

The archipelago puts a main island at the center and three smaller ones around it, never touching. Every tile stores its `island` id. Sea hexes within 2 steps of land add vertices and edges with `tiles` set to 0, so ships have water to sail on. `valid_ship()` accepts an edge with fewer than 2 land tiles that joins the player's own building or ship. Roads never chain from ships. In `_walk()`, a road and a ship link only through the player's own building. The first settlement on a new island adds `ISLAND_BONUS` (2) points through `island_bonus`. Bots plan ships with `_route_step()` and value a new island in `_site()`.

Moving ships lets a player move one ship per turn after rolling. `movable_ships()` lists ships at the open end of a line: one end touches neither another of the player's ships nor their own building. Ships built this turn are in `new_ships` and stay put, and `ship_moved` limits the move to once per turn; both reset when the turn ends. `ship_moves()` lifts the ship off its edge and lists every edge `valid_ship()` then accepts. The action is `{"type": "move_ship", "id": from, "to": edge}`. The HUD's Move a ship button puts the board in `move_ship` mode, and picking a ship switches it to `move_to`. Normal and Hard bots move a spare ship when it lands on the next edge of their planned route.

Fog marks every tile off the main island with `fog`. The host keeps the real kind and number, and `snapshot()` sends `CatanRules.FOG` (7) and number 0 for those tiles, so neither clients nor bots can see under it. Fogged tiles never produce, never pay treasure and never take the robber. Building a road, ship or settlement, or moving a ship, calls `_reveal()` on the corners it touches. Each fogged tile on those corners clears, and a resource tile gives the player one of its resource if the bank has any. The board builds a fogged tile as bare ground under `fog_bank.glb` with `shaders/fog_bank.gdshader`. When a tile's kind changes in a snapshot, `_reveal_tiles()` rebuilds that hex, lifts its fog bank away and rebuilds the shore strip. Bots value a fogged tile like an average hex.

The friendly robber refuses hexes that touch another player with 3 public points or fewer. If that leaves no legal hex, every hex is allowed again. `CatanRules.robber_sites()` is shared by the rules, the bot and the board markers.

### Trades

An offer goes to every other player. Each one answers with `accept_trade`, `decline_trade` or `counter_trade`. A counter keeps the offer's orientation: `give` is still what the offering player hands over. Answers can change until the trade happens. The offer is `waiting` for `CatanNetwork.TRADE_WINDOW` seconds, or until everyone has answered. After that the offering player sends `confirm_trade` with a partner's seat, and the rules check both hands again before swapping. Bots answer every offer once, all in the same bot tick, so none misses the window.

### Game log and stats

The host keeps the whole log. Snapshots carry the last 40 lines and `log_start`, the index of the first one. Clients append each tail to their own copy. If a client finds a gap, after joining or reconnecting mid-game, it asks the host for the full log with `request_log()`.

A log entry is usually a wire message string. `_log_private()` stores a dictionary instead, with a `public` line, a `private` line and the `seen` seats that read the private one. `CatanRules.log_for()` turns the log into one seat's view, and both `snapshot()` and the full log go through it, so the entry keeps its index for every reader. A robbery uses this: the thief and the victim read which resource was taken, and everyone else reads that a robbery happened. The state's `theft` event carries the same detail, with `resource` removed from other seats' snapshots, and the HUD shows it as a notification. Played development cards and trades are logged in full, since both are public at the table.

Each player's `stats` counts rolls, resources produced per type, resources stolen and lost, discards, player and bank trades, and development cards played. The state's `dice_counts` holds how often each total from 2 to 12 came up. Both are public and appear on the victory screen. `points_history` gets one row of every player's points, hidden victory cards included, when setup ends and after each turn. `snapshot()` holds it back until someone wins. The victory screen draws it with `CatanPointsChart` (`scripts/points_chart.gd`): one line per seat color, a dot and name with the final score at each line's end, the goal as a dashed line and a hover tooltip for each turn.

### Saved games

The host saves the game to `user://saves/solo.save` for solo play or `user://saves/room.save` for online rooms. `CatanNetwork.save_game()` runs about once a second after a change, when the host leaves and when the node exits. It writes to a `.tmp` file and renames it. The file is a `store_var` dictionary: `format` (`SAVE_FORMAT`, 1), `protocol`, `version`, `saved` (Unix time), `solo`, the full `rules` state with deck and dice stream, `rng_seed` and `rng_state`, `seats` (name, bot, difficulty, look, color, and whether it was the host's), `settings` and the world clock. A finished game deletes its save, and tutorials never save. `load_save()` refuses a file from another protocol.

In the lobby, `saved_summary()` offers the save to the host. Dedicated servers cannot resume. `resume_saved()` rebuilds the roster from `seats`. Bots come back as they were and the host takes its old seat. Every other seat becomes a `saved_seat` that waits unconnected, and `room_settings.resuming` locks the rules. A player who registers takes the waiting seat with their name, or else the first free one (`_claim_saved_seat()`). A saved seat whose player drops before the start waits again instead of disappearing. Start restores the state through `_restore()`, which clears any open offer, gives the game a new `game_id` and logs that play resumed. Solo saves start straight away. The host can also start while saved seats still wait: `_restore()` gives each one a bot stand-in (see below), and a player who later registers with that seat's name takes it over mid-game. A save from another protocol shows in the lobby as outdated, with no resume button. **New game instead** (`cancel_resume()`) drops the waiting seats and keeps whoever is present.

**Play again** calls `CatanNetwork.rematch()`. The controller starts a new game with the same seats and settings on a new seed. It needs every player connected. Each game carries a `game_id`, so clients know to rebuild the board rather than refresh it.

Each turn has a time limit, 60 seconds by default, held by the host in `CatanNetwork.turn_seconds`. One clock covers the whole turn, including the setup settlement and its road, the robber move and the steal that follows. It restarts when the turn passes to the next seat, and also when a seven hands the wait to the players who must discard, since they have had none of that turn's time. It pauses while the room is paused or a player is reconnecting. Solo games and tutorial lessons have no limit, and the room can turn the limit off. When the clock runs out, the host plays the stalling seat out along the shortest legal exit: it rolls if the seat has not rolled, places the settlements, roads, robber and steal the rules demand, discards down to the limit, then ends the turn. Every snapshot carries `turn_limit` and `turn_seconds`, and clients run the countdown in the HUD between snapshots.

A player who disconnects mid-game pauses it. After `STAND_IN_SECONDS` (60) the host marks the seat `stand_in` and a Normal bot plays it, so one lost connection can't stall the room for good. The game goes on as soon as every seat is either connected or covered (`waiting_for_player()`). Reconnecting with the seat's token, or rejoining by name for a resumed seat with no token, clears `stand_in`. The host takes actions from each player as a burst of up to eight, refilled at ten a second. A flood beyond that is refused with an error instead of dropped in silence. Refusals and failed connections reach `main.gd` through the network's `rejected` signal, which plays the error sound; plain notices use `notice`.

Online rooms use ENet over authenticated DTLS. The `NC1-` invite carries the endpoint, a 128-bit SHA-256 certificate fingerprint and a two-byte typo checksum, encoded as canonical base64url. IPv4 with the default port takes 35 characters; custom ports and DNS names take more. The host generates a fresh RSA certificate for each room. Clients retrieve that public certificate automatically and check its fingerprint before starting a standard DTLS handshake. Only that certificate is trusted, and room passwords and reconnect tokens are sent after the handshake succeeds. The invite authenticates the host; a room password still controls admission.

A public UDP socket on 24567 serves certificate discovery and forwards encrypted datagrams to an ENet listener bound to loopback on an ephemeral port. This local forwarding needs no extra public port or external lookup service. Certificate responses are no larger than the padded requests, and relay allocations are bounded. Godot/mbedTLS handles encryption and separate session keys for each client. The public certificate and endpoint remain visible on the wire. Share invites through a trusted channel: replacing an invite replaces the host identity the client trusts.

Protocol 18 adds house rules, ships, the archipelago, moving ships, fog, the points history, the weather day counter, private log lines with the theft event and bot stand-ins; protocol 16 added room rules, counter-offers and rematches; protocol 14 added the turn timer; protocol 13 rejected bare addresses and older certificate invites, with no plaintext fallback. Saved reconnect invites remain valid while the original room runs; restarting the host requires a new invite. The certificate is valid for 30 days, so rooms left running longer must restart. Clients must update together. Update downloads retain signature and hash verification.

## Verification

CI runs the updater's Go tests with the race detector, vets it, compiles the Windows updater, imports the Godot project and runs the headless rules tests.

```bash
go -C updater test -race ./...
godot --headless --path . --script tests/rules_test.gd
```

## Localization and player appearance

English and Italian catalogs live in `locales/en.po` and `locales/it.po`. Use English source text as the translation key. Translate UI templates before formatting arguments. For messages sent over the network, use `CatanI18n.message()` and mark resource terms with `CatanI18n.term()`; clients render these in their own language. Leave player names as plain arguments. Language selection is saved locally under Settings → Game.

Player colors are opaque six-digit RGB values. An empty value uses the seat palette. The host validates changes and includes them in lobby and game snapshots. Players can edit their own appearance; the room controller can also edit bots. Protocol 10 adds the color handshake and structured localized messages.


## Player pieces

Roads, settlements and cities are not models. Each player designs them in the Workshop (Home or lobby → Workshop), and `scripts/piece_builder.gd` builds the geometry from that design: houses with their walls, framing, windows, doors, chimneys and roofs, the town square and its centerpiece, the city wall, towers and landmark, and the roads. Everything is flat-shaded, vertex-colored triangles from `CatanMeshKit`, one draw call for the body and one for the windows that glow at night. Results are cached per design, so the board builds each look once. Model Detail set to Low drops the individual tiles, stones and cobbles.

A design is a `CatanAppearance`: about fifty fields, each packed into one byte and colors into three, 70 bytes in all. Any byte string decodes to a valid design, so the host re-encodes whatever a client sends before storing it in the roster and replicating it with the game state. Adding, removing or reordering fields changes the encoding: bump `CatanAppearance.VERSION` and the multiplayer protocol together.

Ownership stays readable whatever players choose. Banners, the town rim and the edge strips of every road always use the seat's player color; only the banner's shape and emblem are up to the player. The four presets (Voyager, Harbor, Citadel, Wildwood) are ordinary designs that fill the sliders. Bots wear a preset with their own variation seed.

## Models

Every mesh in the game is modeled in Blender except the player pieces, which are generated (see [Player pieces](#player-pieces)). Shader and particle carriers also stay Godot primitives: the ocean plane, the sea bed, rain, lightning, pollen and chimney smoke. The lighthouse beam is its spot light scattering in a night-only `FogVolume` of sea haze; it needs Forward+ with Atmosphere enabled, and other renderers still get the sweeping light on the water. Each group has an editable source in `assets/source/` and one `.glb` per model in `assets/models/<group>/`:

| Source | Models |
| --- | --- |
| `actors.blend` | Sheep, woodcutter, quarry worker, farmer, outlaw and town dweller, built by `tools/build_actors.py` |
| `settlements.blend` | Cottage, harbor, robber camp and worksites, built by `tools/build_settlements.py` |
| `sea_props.blend` | Lighthouse, sailboat and offshore rocks, built by `tools/build_sea_props.py` |
| `props.blend` | Number token, die, markers and production halo (it still holds the old lighthouse, sailboat and rocks, which are no longer exported) |
| `seafaring.blend` | The player's ship, the treasure chest and the fog bank, built by `tools/build_seafaring.py` |
| `sealife.blend` | Shore boulders, three fish, kelp, seagrass, red coral, a sea fan, sponges and a starfish, built by `tools/build_sealife.py` |
| `terrain.blend` | The ground of each biome and the cliff skirt |
| `mainland.blend` | The backdrop mainland |

The `tools/build_*.py` scripts for actors, settlements, sea props, seafaring and sea life build their models from code with Blender's Python module, sharing helpers in `tools/blender_kit.py`. The newer ones sculpt with `tools/model_kit.py`: a `Part` gathers rounded shapes (lathes, tubes, bevelled boxes, chiselled crags, sweeps) into one mesh per part, each face tagged with a material and flat or smooth shading. Run them with `python3` and the `bpy` package installed, or with `blender --background --python`. Each saves its `.blend` and exports each glTF itself. Sea life models are single joined meshes in metres, because the board draws them in MultiMeshes and colors them in its own shaders. Keep the hull's faces pointing outward; the script asserts it, because the textured wood shader culls back faces.

Export each model's collection with the glTF exporter, using **+Y Up**, **Apply Modifiers**, **Custom Properties** and, for models with lamps, **Punctual Lights**. The code relies on these conventions:

- **Pivots.** Animated parts hang from empties with an identity rest rotation, such as `Body/Leg0/Knee0` on the sheep and `Torso/UpperArm0/Forearm0` or `Torso/Tool` on workers. `scripts/living_world.gd` drives them by name. Pivots are top-level objects in their collection, with no wrapper root. The sheep's `Body` rests at .070; workers' thighs hang from .079.
- **Sea props.** Offshore rocks stand upright in `board.tscn` with z 0 at the water line. The lighthouse's water line is at z .175, and its `Lamp` is centred at z 1.0, where the scene hangs the beam. Its `Rowboat` origin is its own water line: `lighthouse.gd` rests it on the calm sea and the board adds the swell, like the harbor boats. Sailboat hulls float with their water line at z -.07 and their bow towards Blender -Y.
- **Recolored surfaces.** A material named after a role, optionally with a signed percentage, takes its color at runtime: `Shirt`, `Shirt-16` (darkened 16%), `Shirt+07` (lightened 7%). Roles are `Shirt` and `Skin` on actors and `Owner` on player pieces such as the ship. A surface whose glTF material is double sided, like a sail, stays double sided after recoloring. `CatanModelTint.paint()` applies them.
- **Textured surfaces.** Materials named `PBR_Rock`, `PBR_Wood` and similar take that surface's texture tier from `CatanTileArt.surface()`. `PBR_SeaRock` (offshore rocks, the lighthouse islet) and `PBR_Crag` (mountain peaks) are a darker, warmer stone, because the tile rock tint washes out to near white in full sun.
- **Night lights.** Meshes named `NightWindow`, `NightLantern` or `Campfire` glow at night, lit by the `NightLight` point light that shares their pivot. Each light's `local_range` and `night_energy` custom properties become Godot metadata.
- **Ground.** Workers, cottages and the robber camp stand on `CatanTileArt.height_at()`, which samples the exported ground mesh. Sculpt it freely, but keep the rim at 0.20 units so tiles meet the cliffs. Godot generates the ground's LODs; Model Detail sets their `lod_bias`.

## Weather, water and camera

Weather follows the synchronized world clock. Each ten-minute day uses one of the outlines in `weather.gd`'s `DAYS`, picked by `day_outline()` from the map seed and `world_days`, the number of whole days since the game began. Every client reaches the same sky. Keys drift by up to 20 seconds per day. Every outline opens and closes clear, so days join without a jump. Lightning strikes come in 24-second slots; about half the slots in a storm get one, at a hashed time, bearing and distance. Far strikes flash dimmer and rumble later, softer and lower. Overcast keeps a third of the sun as shadowless light and raises the ambient fill, so cloudy days stay readable.

Rain and thunder play on a `Weather` bus that `audio.gd` creates at startup, with its own **Rain and thunder** volume. A low-pass filter on that bus opens from 1.4 kHz for drizzle to 7 kHz for a downpour. `tools/generate_weather_audio.py` writes the stereo rain loop and three thunder claps from near to far.

The water is see-through. `shaders/water.gdshader` reads the depth buffer to find how far light travels underwater and absorbs red fastest, so the shallows are turquoise and deep water dark blue. The sea bed is a plane that `board.gd` sizes to each board. `shaders/seabed.gdshader` sinks it to the depth given by `seabed_depth()` in `shaders/sea_floor.gdshaderinc`: a sandy shelf near the coast, a step to a reef, then deep water between islands. Both shaders share the tile list through that include. Caustics on the bed fade with depth. The bed ends 170 metres beyond the outermost tile, where the water is too deep to see through.

Shores come from `scripts/coast.gd` when a board is built. It walks every coastline (edges with one land tile), mitres the strip at each corner, and lays eight rows from the cliff foot out to an underwater toe that dips below the sea bed. Each sample blends sand, shingle and rock from the tile's biome (`BIOME_SHORE`) plus seeded noise along the coast; harbor edges are shingle. The mix sets the strip's width and height profile and goes to `shaders/shore.gdshader` as vertex color, which draws sand grain, pebbles, rock strata with lichen, weed at rocky waterlines and a wet band. Boulders scatter on rocky stretches, and rocky headlands sometimes get a sea stack 16 to 20 metres out, beyond the ship lane. Ships sit 0.36 tile units off the coast to clear the beach. The water draws foam wherever it is shallow over anything, using the same depth read as its color.

`scripts/sea_life.gd` scatters plants by depth band from the map seed: seagrass and starfish on the shelf, kelp deeper, corals, sea fans, sponges and reef rocks on the reef. Foliage quality scales the counts. `shaders/sea_plant.gdshader` lowers each instance from the waterline to `bed_height()` under its origin, so plants sit on the same dunes the bed shader draws, and sways the tall ones. Fish swim in schools as boids: they keep apart, match heading, hold together, head for a wandering goal in open water, and turn away from the coast and the bed. They also scatter from the pointer: each frame `board.gd` casts the mouse ray onto the water plane, and when it lands on open water (not land, a beach or the HUD) fish within 11 m dart sideways and down, faster than their cruising speed. A fright fades over a second or so, and the school picks a new goal away from the cursor. `CatanSeaFloor` in `scripts/sea_floor.gd` mirrors the shader's shore distance and depth for this. `shaders/fish.gdshader` bends each body in a wave that grows towards the tail. Fish run on each client alone; Reduce motion stops them.

Camera input moves goals (`goal_focus`, `goal_zoom`, `goal_yaw`, `goal_pitch`), and `_steer_camera()` eases the camera toward them each frame; Reduce motion snaps instead. The wheel zooms about the ground under the pointer. Dragging and orbiting follow the hand directly. `_fit_home()` frames the tiles' bounding box, so the archipelago fills the view. Code that moves the camera should set the goals.

## Scenery and placement

`assets/world/layout.json` defines cottages, work areas, return paths and sleeping places. Both `scripts/world_layout.gd` and the Blender generator read it. Keep the numbered tiles and a 0.40-unit radius around board corners clear; cities extend beyond their circular bases. One tile unit is 25 metres: regular hexes measure 50 metres tip to tip and about 43.3 metres across their flats. Workers and sheep retain their earlier physical size while the scenery expands. Town buildings are 20% taller; settlements contain 6 animated residents and cities contain 16. Residents take independent short trips between courtyard spots, turn before walking, pause and gesture on different schedules, and disappear at night.

Rebuild scenery with `blender --background --factory-startup --python tools/build_premium_tiles.py`, then import the project in Godot. The generator writes twelve biome models and `assets/source/sculpted-tiles.blend`. Plants and small props avoid occupied areas. Extra saplings, flowers, log piles, brick drying racks, hay feeders, cargo wagons and broken columns fill clear pockets in each biome. Sheep are created only at runtime. The treasure tile reuses the desert ground and sets its chest at (-0.34, -0.22), so the desert keeps that spot clear.

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

Roads sit on the terrain surface; `CatanPieceBuilder.road_deck()` supplies the matching pedestrian surface for each road style. `scripts/road_travel.gd` assigns occasional journeys to existing residents along disjoint, same-owner road paths between towns. Visitors stop at town entrances, rest between trips, hide at night, and obey reduced motion.

Weather follows the synchronized 600-second world clock. `scripts/weather.gd` blends clear, cloudy, rainy and stormy conditions; the local Weather setting can hold any one condition. Clouds drift through a procedural sky shader and affect ambient lighting. Clear weather retains a few scattered clouds and sunlight. Cloudy, rainy and stormy weather disable direct sunlight and directional shadows, with bounded rain particles and an offshore lightning effect. Rain/thunder audio goes through the Ambience bus. Reduced motion stops moving clouds and suppresses rain particles, water ripples and lightning flashes. Water uses four Gerstner swells, shore attenuation, filtered surface ripples and a narrow sun glitter reflection. The mesh concentrates vertices around the island. Boats sample the same wave parameters as the shader. See NVIDIA’s [water model](https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-1-effective-water-simulation-physical-models) and Godot’s [sky shader documentation](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/sky_shader.html). Original weather audio can be regenerated with `python3 tools/generate_weather_audio.py`.

Seagulls use the original Blender model in `assets/premium/seagull.glb`, with its editable source in `assets/source/seagull.blend`. `tools/build_seagull.py` builds a separate scene through Blender MCP or Blender Python in a fresh session. Seven meshes share a matte palette, shoulder/wrist pivots animate wingbeats, and four folded morph targets tuck the feathers against the body on landing. `scripts/seagulls.gd` reuses six visitors, with at most five active in fair weather, independent offshore arrivals, gliding and flapping, skimming, reserved harbour posts, rests and departures. Night and storms trigger a retreat; reduced motion shows static perched gulls. Perch positions refresh when the board is rebuilt, including six-player scale.
