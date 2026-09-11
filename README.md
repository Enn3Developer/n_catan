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

Choose **Play online**, create a room and share the lobby's host address. Friends can paste it into the join form. The host needs UDP port 24567 reachable through their router and firewall. There is no hosted relay, so hosting behind carrier-grade NAT requires a public server.

Closing the host closes the room. Disconnected players can reconnect while the host remains running.

## Updates

The game checks for stable releases at startup. Open **Game updates**, download the update, then leave your room and choose **Restart to update**. Updates use signed packages, delta downloads where available, and rollback if the new build fails to start. Dedicated servers need manual updates.

## Run from source

Install Git LFS and Godot 4.7.2. After cloning, run:

```bash
git lfs pull
```

Open `project.godot`, let Godot import the assets, then press F5. You can also launch with `./run.sh`. Set `GODOT_BIN` if the launcher cannot find your Godot executable.

See the [development guide](docs/development.md) for exports, release publishing, source layout and tests. To run a dedicated server:

```bash
./run.sh --server --address=your-public-hostname:24567 --password=your-room-password
```

Open UDP 24567 and share the printed `CATAN_SECURE_INVITE` with guests.

## Asset credits

Textures use [Poly Haven CC0 maps](https://polyhaven.com/license), with sources recorded in [sources.json](assets/materials/sources.json). Fira Sans uses the [SIL Open Font License](assets/fonts/LICENSE.txt). Editable Blender models are in `assets/source/`.

## License

The project uses [GPLv3](LICENSE). Third-party assets retain the licenses listed above.
