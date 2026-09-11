# Expansion verification

Verified in Godot 4.7.2 on Linux, September 8, 2026.

| Requested feature | Delivered implementation | Evidence |
|---|---|---|
| Tutorial | Ten guided lessons, real placement/roll/city/trade/robber/card actions, retry/previous/skip, solo graduation | `feature_test.gd` completed all ten lessons and checked continuation and graduation; tutorial screenshot inspected |
| Better lobby | Native lobby and player-card scenes; ready states, four seats, per-bot difficulty/removal, invite address controls, distinct solo/online flow | UI feature test, base UI test, mixed online test, rendered lobby inspection |
| Crisper text | Shared Fira Sans MSDF font, readable minimum sizes, native UI-layer board labels, no screen-space AA on text | Font and label-layer assertions; menu, HUD, tutorial and world captures inspected at 1440×900 |
| Adjustable bots | Easy / Normal / Hard policies, normal resource rules and private snapshots | Twelve completed matches, 4,117 legal actions; mixed online privacy/authority test |
| Singleplayer | Offline lobby with configurable bot seats; live authoritative bot scheduler | Socket-free solo assertion, live setup with all difficulties, complete live solo match to victory (314 scheduler ticks, zero rejected actions) |
| Better graphics | Layered cliff texture, wind-driven foliage, chimney smoke, production highlights, construction animation, 4× MSAA high preset | In-engine world captures and graphics/reduced-motion preference assertions |
| Sound and music | Original 46.8-second instrumental loop, ocean ambience, eight gameplay/UI cues, independent buses | Real Godot playback advancement, all effect voices playing, master/music/effects/ambience gains verified; PCM assets have nonzero signal and non-clipping peaks |
| Settings | Persisted audio, fullscreen, VSync, quality, reduced motion, larger small text, camera sensitivity, bot speed; restore defaults | Feature suite toggled every control, reloaded preferences from disk, verified runtime effects and reset; solo pause/resume checked |
| Multiple scene files | Main instances Network, Board and Audio; six separate editable UI scenes; shared editor-visible theme | Godot MCP created/instanced nodes and validated all ten scenes and seven changed scripts |

Final checks:

- `rules_test.gd`: **1,331 checks, 0 failures**.
- `bot_test.gd`: **12 complete matches, 4,117 actions, 0 failures**.
- `feature_test.gd`: **69 checks, 0 failures**.
- `ui_test.gd`: lobby buttons, 3D picking, turn advancement and guide passed without runtime errors.
- `bot_network_test.gd`: mixed human/bot room, private bot state, guest restrictions and dedicated-server authority passed.
- `network_test.gd`: three ENet peers, setup, privacy, invalid-move rejection, dice, disconnect and reconnection passed.
- `run_online_test.py`: an independent dedicated server plus two client processes played multiple turns successfully.
- `solo_match_test.gd`: actual solo bot scheduler reached a winner without rejected actions.
- All targeted scripts and scenes passed Godot MCP validation.
- Menu, lobby, settings, tutorial, HUD, card dialog and world views were rendered and inspected.

Network transport tests used loopback. Public internet hosts still need UDP 24567 reachable, as documented in the README. No hosted matchmaking or relay service was added.

## 5–6 player extension verification

- `extension_test.gd`: 3,106 checks, 0 failures across five- and six-player boards. Covers geometry, terrain/token/port/deck inventories, red-token spacing, paired turn order and restrictions, resource limits, extension-area robber/city actions, and victory precedence.
- `extension_bot_test.gd`: six complete five/six-player games across Easy, Normal and Hard; 2,203 legal actions, 0 failures, with resource conservation checked throughout.
- `run_online_test.py 6`: dedicated server and six independent ENet clients each completed five turn portions; private hands remained filtered.
- `extension_ui_test.gd`: six-seat lobby, board markers, camera scaling, six-player scores, paired controls and bank-only trade dialog passed. Lobby and board renders inspected at 1440×900.
- Existing base rules: 1,331 checks, 0 failures. Updated feature suite: 72 checks, 0 failures.

Extension activation is automatic at five participants; three/four participants keep the base game. Online protocol is now 4. Network verification uses loopback, not public internet routing. Some test processes report Godot object cleanup warnings at exit; gameplay assertions pass.
- `extension_solo_test.gd`: real solo network node and bot scheduler completed a six-player match; winner seat 3 after 1,725 scheduler ticks, zero rejected actions.

## Detailed graphics and audio update

Verified on Godot 4.7.2, Forward+ Vulkan, NVIDIA RTX 4060 at 1440×900.

- `graphics_test.gd`: **208 checks, 0 failures**. Tests actual texture widths and mipmaps, scenery texture rebinding, increasing ground geometry and foliage density, six AA modes, AO, SSIL, two SDFGI resolutions, SSR, shadows, water tessellation/shader levels, effects, exposure, render scale/FSR, frame limits, anisotropy, preset/Custom state, persistence, reset, sanitization, migration, camera zoom/pan/reset and inspection pause/resume.
- `feature_test.gd`: **74 checks, 0 failures**, including audio controls, fullscreen/VSync, live solo setup and all tutorial lessons.
- `ui_test.gd`: **0 failures**; lobby, scaled world-space placement clicks, road placement and turn change.
- `extension_ui_test.gd`: **0 failures**; six seats, 30 enlarged tiles, 80 placement targets and paired-turn controls.
- `rules_test.gd`: **1,331 checks, 0 failures**.
- `audio_test.gd`: **10 checks, 0 failures**; 44.1 kHz lossless PCM, full source loop duration, frame counts and playback wrapping. Corrected the former compressed-byte-count loop calculation. Music lasts 46.829 seconds; ambience lasts 16 seconds. Both source loops have zero endpoint sample jump and zero clipped samples; peak amplitudes are 0.65 and 0.105 or below. Ocean noise now uses a smooth spectral low-pass instead of a box filter.
- Base and extension boards, six biome closeups and graphics/lighting/world settings rendered in-engine. Settings layout and board framing were visually inspected.

Short High-preset capture samples showed roughly 100–160 FPS and 614 MB reported video memory on this GPU. These are preview observations, not a controlled performance benchmark or minimum hardware guarantee. SDFGI and Ultra costs vary with resolution and scene. Rendering tests produced no script or shader errors; the isolated headless audio test reports a small ObjectDB cleanup warning on exit.

Final views: `premium-board.png`, `premium-world.png`, `premium-forest.png`, `premium-fields.png`, `premium-mountains.png`, and `premium-settings.png`.

## Player piece cosmetics

- Four coordinated sets: Voyager, Harbor, Citadel and Wildwood. Roads, settlements and cities use the same model builder in the preview and the game. Player colors remain on trim, roofs and bases.
- **Piece cosmetics** is a direct main-menu button below Learn to play, with an additional lobby entry. Native preview supports drag rotation, preview-before-equip and a player/bot selector.
- `cosmetics_test.gd`: **35 checks, 0 failures**, including the main-menu button, saved home selection, six-player selector, all sets, bot selection, in-match rendering and unchanged rule state. Final main menu, four set previews and six-seat lobby were rendered and inspected.
- `cosmetics_network_test.gd`: **12 checks, 0 failures**, covering handshake selection, peer replication, rejection of other-human/bot/invalid changes by guests, host bot control, snapshots, live updates, private hands and reconnection.
- `feature_test.gd`: **74 checks, 0 failures** after cosmetics integration.
- Protocol is now 5; all peers must run this project version.

## Art and responsive UI rework — September 9, 2026

The current artwork supersedes the earlier photographic-detail pass. All twelve terrain assets were rebuilt in Blender as sculpted miniatures, with welded normals, closed roof slabs, broad foliage forms, rounded animals and a shared matte palette. Player pieces and harbor props use shared beveled geometry. Original vector resource/action icons are authored in `tools/create_icons.py`.

Fixed visible rendering defects: the ocean no longer casts shadows onto itself; directional shadow bias removes terrain acne; material shading preserves the actual mesh normals instead of combining incompatible triplanar normals; probability pips no longer overlap number text; port labels use icons; roads and the robber sit at the correct ground height. The scenery now includes a shaped boat hull, curved sail, rounded birds and a continuous lighthouse taper.

The menu, lobby, HUD, settings, cosmetics and tutorial use anchors and containers. Standard dialogs constrain their width and scroll vertically. The HUD uses player chips, resource badges and a bottom action bar; detailed player statistics, build explanations and logs are available on demand. Bank and player trading are separate modes, with visible exchange quantities and affordability checks. The guide remains open across game updates.

Validation on Godot 4.7.2, Forward+, NVIDIA RTX 4060:

- `layout_test.gd`: **3,846 checks, 0 failures**. Renders native Controls into independently sized viewports at **800×600, 1024×768, 1280×720, 1440×900, 1920×1080, 2560×1080 and 900×1100**. Checks panel/container bounds, all 80 extension placement targets, long player names, all five settings tabs, cosmetics, dialogs, tutorial and enlarged text. Offscreen viewports allow sizes beyond the desktop monitor's 1920×1020 usable window area. Real desktop resizing was also exercised up to that limit.
- `graphics_test.gd`: **201 checks, 0 failures**, covering graphics controls, actual texture tiers, geometry/foliage quality, anti-aliasing, lighting, water, particles, camera controls and ocean shadow behavior.
- `ui_test.gd`: **0 failures** using pointer press/release input on the real native menu/lobby, an ENet guest, 3D settlement/road placement, turn advancement and guide persistence.
- `trade_ui_test.gd`: **9 checks, 0 failures**. Resource icons, fixed bank quantities, port rates, same-resource and unaffordable trade prevention, editable player offers, an actual bank exchange and paired-turn restrictions.
- `feature_test.gd`: **72 checks, 0 failures** headless, including all ten tutorial lessons and settings integration.
- `cosmetics_test.gd`: **35 checks, 0 failures**; saved style, bot selection, preview/equip and actual board pieces.
- `extension_ui_test.gd`: **0 failures**; six-seat lobby and paired controls.
- `rules_test.gd`: **1,331 checks, 0 failures**.
- Godot MCP validated the changed scripts and native scenes. Blender exports were inspected to ensure only the intended biome meshes were included.
- Populated board, all six biome closeups, main menu, six-seat HUD/lobby, settings, cosmetics and trade dialog were rendered and visually inspected. Some isolated headless test exits report small ObjectDB cleanup warnings; the graphical runs report no script/shader errors.

Current previews: `sculpted-board.png`, `sculpted-world.png`, `sculpted-forest.png`, `sculpted-trade.png`, `responsive-hud-800.png`, `responsive-settings-800.png` and `responsive-cosmetics-800.png`.

Authoring sources: `assets/source/sculpted-tiles.blend`, `tools/build_premium_tiles.py`, `tools/create_ui_scenes.py`, `scripts/miniature_mesh.gd` and `scripts/ui_icons.gd`. Older `.blend` sources remain as archives; the runtime uses the new GLB exports.


## Linux package optimization — September 9, 2026

Reduced the existing 490.88 MiB executable to 220.76 MiB (55.03% smaller). Removed unused export resources and material map loads; the retained texture/audio payloads are byte-identical. The current 12 sculpted biomes and all graphics tiers remain included. Verified all 271 packed-file checksums, 201 graphics checks on the GPU, 72 feature checks, 35 cosmetics checks, 10 audio checks, and the three-peer ENet network suite using the exported resource pack. The actual release also completed a 240-frame GPU launch test with no errors or warnings. [Full breakdown and reproducible export instructions](build-size.md).


## Timber and grain icons — September 9, 2026

Redrew timber as stacked round logs with end-grain rings and grain as two wheat ears with paired kernels and awns. Updated both SVG assets and their authoring generator. Inspected the shared icon set at 18/22/28/38/64/96 px and in actual build-cost rows. The exported preview is pixel-identical to the source render; the rebuilt pack differs only in the timber and grain icon payloads. All 271 packed-file checksums pass. [Preview](resource-icons.png).

## Linux rebuild after export filter reset — September 9, 2026

Restored the Linux preset's missing exclusion filters after an export grew to 431.50 MiB. The rebuilt executable is 220.77 MiB and its 146.52 MiB archive extracts to the same executable with launch permissions. Verified all 271 packed-file checksums and both distribution SHA-256 hashes; the resource inventory matches the prior compact release, retaining the updated timber/grain icons. The actual release completed 240 frames on Forward+ without errors or warnings. Added a 250 MiB limit to the export script and verified that it rejects the bloated build before replacing release files. No game scripts or runtime assets changed in this rebuild.


## September 11: gameplay UX, world motion, reconnection, Windows

- Rules suite: 1,331 checks pass. Trade UI: 9 checks pass. Responsive UI: 4,340 checks pass across seven sizes, including six players and large text.
- New `tests/ux_world_test.gd`: 17 checks pass for visible/hidden victory points, legal building space, card availability, exact 600-second lighting period, solo pause, authoritative dice faces, and reduced motion.
- Three-peer ENet test passes. `python3 tests/run_reconnect_test.py` passes with independent server/client processes: restores persisted token and private cards, replaces a still-connected old peer, resumes after abrupt client termination, and accepts a game action after reconnect. Uses temporary per-client profiles and localhost.
- Rendered HUD, resource selection, airborne/landed dice, and nighttime at 1440×900 and 800×600. Evidence: `september-hud.png`, `september-night.png`, `september-trade-small.png`, `september-dice-land.png`.
- Linux release: 220.78 MiB, 275 packed resources. Windows: 254.86 MiB, 275 resources. All retained asset payloads match between platforms; every PCK checksum, archive binary, and SHA-256 manifest verified. Linux launches with Vulkan; Windows launches and exits with code zero under Wine headless. Native Windows GPU rendering was not tested.
- Godot can report audio playback/resource cleanup warnings when these short-lived processes exit; no gameplay assertions failed. The Wine profile also emits Mesa initialization warnings before the headless game starts.
- Reconnection requires the original running host. Room passwords are kept in memory, not written to the reconnect file; enter the password again after restarting a password-protected client. All peers must use protocol 6.


## September 11: expanded, synchronized soundtrack

Added four original stereo Vorbis arrangements alongside Harbor at Dawn. Generation source and measured durations/levels are in `tools/generate_soundtrack.py` and `docs/soundtrack-generation.json`. The runtime playlist uses verified source durations and levels, with short crossfades. The Music library is available from the main menu/lobby and a persistent in-game music row. Track transport is host-controlled (first player on dedicated servers); mute and volume remain personal.

Validation:
- Original audio loop suite: 10 checks pass. New music suite: 23 checks pass, including all five imported durations/codecs, track changes, pause, mute without losing position, and drift correction. The same suite passes against the exported Windows resource pack.
- Three-peer music network suite: 45 checks pass for initial join, track change, shared pause, server-side rejection of guest controls, automatic playlist wrap, stale-packet rejection, reconnect, and dedicated-server controller permissions.
- Independent host/two-client playback test: 182–184 playback samples per process; maximum measured drift from the room clock was 40.7 / 83.5 / 84.6 ms on localhost with headless audio. This checks network/application timing, not all physical audio devices or public-internet paths.
- Music UI: 13 checks pass. Complete responsive layout suite: 4,475 checks pass, including the music library at 800×600. Visual evidence: `music-library-small.png`, `music-library.png`, `music-hud-small.png`.
- Existing client-process termination/restart/reconnection regression passes with protocol 7.
- Linux executable launches with Vulkan; Windows executable launches under Wine headless. Both archives match the shipped binaries, all packed checksums pass, and their asset payloads match across platforms. Some short-lived Godot audio tests still emit engine audio-resource cleanup warnings at exit; gameplay assertions pass.


## September 11: explicit hosting password controls

Separated Play online into Host and Join forms. Hosting has its own labeled password field and Create room button; the lobby confirms whether a password is required. Reconnecting clients see the Join form with their saved address and any password still held in memory. Passwords are not written to the reconnect file.

`tests/host_password_test.gd`: 11 checks pass, including distinct host/join passwords, wrong-password rejection, matching-password admission, open rooms, and restoring the reconnect form. Responsive layout suite: 4,643 checks pass across Host and Join forms and the existing UI. Visual evidence: `host-password.png`.

This change does not alter protocol 7 or add transport encryption. Room passwords still gate admission over the existing unencrypted ENet connection. A future encrypted transport should authenticate the server and use per-client session keys, rather than exposing every player's private state under a room-wide key.

### Verified DTLS transport (protocol 8)

Online rooms now require DTLS with a certificate supplied by the host's secure invite. The private RSA key remains in memory; the invite contains only the public certificate and endpoint. Each host session generates a new identity. Clients configure certificate and hostname verification before connecting, then attach the verified ENet connection as a single-server mesh peer. SceneMultiplayer relay is disabled because all application RPCs go through the authoritative host. ENet range compression reduces snapshot packet bursts before encryption. No unsafe TLS options or plaintext fallback exist.

- `dtls_test.gd`: wrong certificate and plaintext ENet rejected, valid invite recovers, host disconnect exits cleanly.
- `network_test.gd`: three-player setup, actions, private hands and reconnect pass.
- `host_password_test.gd`: 11 checks pass, including incorrect password rejection and password-free encrypted rooms.
- `run_online_test.py 6`: dedicated server plus six clients each complete five turns; private hands remain filtered, no packet-buffer warnings after compression.
- `run_reconnect_test.py`: persisted invite/token restores a seat after restart and replaces a live stale connection.
- `run_music_process_test.py`: independent host and two clients pass track/pause checks; maximum measured drift below 87 ms.

Godot logs expected TLS errors for deliberately invalid certificates/plaintext probes. It also emits an upstream NUL conversion warning while exporting the generated public certificate and may emit a DTLS close-send warning when test peers are torn down immediately after the host; neither prevents verified joins or clean disconnect handling.

### Living medieval island and menu update

Added `living_world.gd` for deterministic cosmetic scenery: animated sheep and workers, medieval villages/cities, and coastal quays with boats. Tile diameter is 20 m, with camera range, haze, shadows, focus plane and dice adjusted to match. Old static sheep are hidden in pasture dioramas. Graphics controls consolidate into one tab; desktop exit leaves the network before quitting.

- Living-world behavior checks pass, including populated terrain, animation, reduced motion, harbor boats, city houses and consolidated settings.
- Layout suite: 4,519 checks pass across supported sizes.
- UX/world suite: 17 checks pass, including legal action controls, day cycle and dice.
- Vulkan render inspection: `docs/medieval-city.png` and `docs/living-island.png`.
- Graphics suite: 201 checks pass in both headless and Vulkan runs, including settings persistence, quality tiers, zoom and pan.

### Outlaw band and day/night life

Replaced the single robber pawn with four hooded figures, supplies, and a camp. The band follows the authoritative robber tile and remains visible at night. Workers return to small cottages; sheep gather and rest by the fence. Shared day/night state drives emissive windows and local lantern lighting, with three shadowless local lights per city versus one per settlement (five versus one visible lanterns). Lights initialize correctly after snapshots/reconnects without waiting for the next advancing frame. Motion reduction keeps the appropriate day/night pose.

- `night_world_test.gd`: 14 checks pass in a Vulkan run, covering daytime lights off, night lights on, city/settlement density, sleeping sheep, returning workers, dawn restoration, snapshot refresh, robber movement and reduced motion.
- `living_world_test.gd`: passes with the extended actor routines.
- `ux_world_test.gd`: 17 checks pass, including the ten-minute clock, pause, gameplay actions and dice.
- Visually inspected `docs/city-day.png`, `docs/city-night.png`, and `docs/robber-band-night.png`. Moved the band to the clear tile edge after catching forest occlusion in the first render.

### Water shader revision

Replaced short vertex waves on the 2,000 m ocean mesh with long, low-amplitude swells. Continuous analytic world-space normals avoid mesh/tangent seams. Rotated, warped smooth noise replaces the old axis-aligned sine caustics; screen-space derivatives filter small details. Matte diffuse water excludes direct sun specular to avoid glare. Added shoreline wash, softly broken boat ripples registered from actual boat transforms, subtle shallows and quality-dependent foam.

- `water_visual_test.gd`: Vulkan renders at noon, dusk and night, close coast views at Low/High/Ultra, and reduced motion; no shader errors.
- Compatibility OpenGL 3.3 smoke run compiles and renders the shader without errors.
- Graphics suite: 201 checks pass, including water quality tiers and reduced motion settings.
- Inspected `docs/water-day.png`, `docs/water-night.png`, `docs/water-coast.png`; softened the first pass's overly strong shallow patterns and boat rings.


### Release 0.2.1 diagnostics and transport

Protocol 12 replaces the historical DTLS transport above with plain ENet and
address-only invites. Password admission, reconnect tokens and update signatures
remain in place. Deferring disconnect/rejection teardown until after ENet polling
fixes the native disconnect crash reproduced by the new transport test.

Local Godot 4.7.2 verification:
- `diagnostics_test.gd`: byte caps, four-file rotation, repeat suppression, rate
  limiting, redaction and engine error source/stack capture pass.
- `enet_transport_test.gd`: bare/explicit-port addresses, invalid and old invites,
  wrong passwords, password-free rooms and host disconnect pass.
- Network, protocol mismatch, bot network, cosmetics network (18 checks), music
  network (141 checks), independent dedicated server plus three clients, shared
  music processes and saved-seat process reconnect tests pass.
- `sea_traffic_test.gd`: 24 checks pass, including bow-first sailing, route safety,
  centered robber group/campfire and saved day/night preference with a running clock.
- `ui_day_night_test.gd`: 14 checks pass with Vulkan/Forward+ on RTX 4060,
  including the actual settings toggle and day/night interface restoration.
- Python suite: 6 tests pass. Native crash output from the transport regression
  was captured by the bounded logger; existing user logs did not establish the
  cause of the user's earlier intermittent crashes.
