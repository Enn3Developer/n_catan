# CATAN · Tides & Timber

## AI usage disclaimer

This game was made 100% by AI, GPT-6 Astra, mainly for me and my friends. If this project's existence bothers you because you're anti-AI or for any other reason, you can close the tab. If you want to try it out and play with your friends, keep reading.

## About

A 3D Catan-style game built in Godot 4 for solo play and online rooms with 3 to 6 players, including bots. It has an in-game tutorial and Guide.

This is an independent fan project, not an official Catan product.

## Download and run

Get a build from [GitHub Releases](https://github.com/Enn3Developer/n_catan/releases) when one is available. Extract the ZIP into a writable folder and launch `N Catan.x86_64` on Linux or `N Catan.exe` on Windows. Keep the updater beside the executable.

The game uses the Forward+ renderer and requires a Vulkan-capable GPU.

## Play with friends

Choose **Host a room** and create it. Enter your public IP address or hostname in the lobby, or use **Map router** to fill it in. Click **Copy invite** and share the code. Friends paste it into the invite field at the top of the main menu, which joins straight away. The password field appears only if the room asks for one. Invites are 35 characters for an IPv4 address with the default port. Connections use authenticated DTLS encryption; the certificate exchange happens automatically. The host needs UDP port 24567 reachable through their router and firewall. There is no hosted relay, so hosting behind carrier-grade NAT requires a public server.

Everyone in a room needs the same release, because room rules and the new trading flow change multiplayer compatibility. By default each turn has a 60-second limit so one player cannot hold up the room. The remaining time shows in the interface, and when it runs out the host finishes that turn: it rolls if needed, makes the placements the rules require and passes play on. Solo games and the tutorial have no limit.

The host sets the room rules in the lobby: the map seed, the island (random, classic or archipelago), the turn timer (off, or 30 seconds to 3 minutes) and the points needed to win (5 to 15). The same seed and player count always build the same island and harbors. The seed doesn't decide anything hidden: the development cards, the dice and what lies under the fog come from a secret draw on the host, so knowing the seed tells you nothing about them. Changing a rule or a seat sends every other player back to not ready, so nobody starts a game they didn't agree to. The host can remove a guest from the lobby, and a guest who joins with a name already in the room gets a number after it. Dice draw from a shuffled deck of all 36 outcomes, so every total turns up about as often as the odds say it should.

The lobby also has house rules, all off by default:

- **Friendly robber.** The robber stays away from players with 3 points or fewer.
- **Random start.** Everyone's first two settlements and roads are placed for them, on good spots of similar value.
- **Starting card.** Everyone draws a development card before the first roll and can play it on their first turn.
- **Treasure tile.** When its number comes up, each settlement on it gets 2 random resources and each city 4, then the tile draws a new number. Nobody can start within 3 roads of it.
- **Moving ships** (archipelago). Once per turn, after rolling, you can move one ship from the open end of a line to another sea edge you could build on. A ship built this turn stays put.
- **Fog** (archipelago). The outer islands start hidden. A road, ship or settlement that reaches a hidden hex reveals it, and a resource hex gives you one of its resource.

On the archipelago, smaller islands lie across the water from the main one. Ships cost 1 timber and 1 wool. They go on sea edges, chain out from your coast like roads and count toward the longest road. The first settlement you build on each new island is worth 2 extra points.

The islands have shores: sand beaches, shingle coves and rocky shelves with boulders and sea stacks at the foot of the cliffs, different on every map. Under the water are seagrass meadows, kelp, corals, sea fans and schools of fish that scatter when you move the pointer over them.

The camera eases between views. Drag the board or hold WASD to pan, right-drag or press Q and E to orbit, and scroll or press + and - to zoom. Home fits the whole board. The victory screen shows the seed, each player's rolls, resources collected, trades and steals, and a chart of everyone's points turn by turn. The host can deal a new island to the same table with **Play again**.

Trading works the way it does at a real table. Your offer goes to everyone; each player accepts, declines or sends a counter-offer. After a few seconds, or once everyone has answered, you pick who to trade with.

Closing the host closes the room. Disconnected players can reconnect while the host remains running. The game pauses while they are gone, and after a minute a bot plays their seat until they come back.

The host saves the game as it goes, so closing it does not lose the game. Solo games and online rooms each keep one save. Open the lobby again and choose **Resume saved game**. For an online room, share the new invite: friends who rejoin get their old seats back by name, and bots come back on their own. You can also start before everyone is back: a bot plays each empty seat, and a friend who joins later with the same name takes over. Starting a new game replaces the save, and a finished game clears it.

## Updates

The game checks for stable releases at startup. Open **Game updates**, download the update, then leave your room and choose **Restart to update**. Updates use signed packages, delta downloads where available, and rollback if the new build fails to start. Dedicated servers need manual updates.

## Run from source

Install Git LFS and Godot 4.7.2. After cloning, run:

```bash
git lfs pull
```

Open `project.godot`, let Godot import the assets, then press F5. You can also launch with `./run.sh`. Set `GODOT_BIN` if the launcher cannot find your Godot executable.

See the [development guide](docs/development.md) for exports, release publishing, and source layout. To run a dedicated server:

```bash
./run.sh --server --address=your-public-hostname:24567 --password=your-room-password
```

Open UDP 24567 and share the printed `CATAN_INVITE` with guests.

## Asset credits

Textures use [Poly Haven CC0 maps](https://polyhaven.com/license), with sources recorded in [sources.json](assets/materials/sources.json). Fira Sans uses the [SIL Open Font License](assets/fonts/LICENSE.txt). Editable Blender models are in `assets/source/`.

## License

The project uses [GPLv3](LICENSE). Third-party assets retain the licenses listed above.
