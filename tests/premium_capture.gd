extends SceneTree
var game
func _initialize():call_deferred("run")
func shot(label: String):
	await create_timer(.8).timeout
	root.get_texture().get_image().save_png("/tmp/catan-final-%s.png" % label)
	print("CAPTURE ",label," FPS=",Engine.get_frames_per_second()," draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)," vram_mb=",Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0)
func run():
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(3).timeout
	await shot("home")
	game._solo()
	game.net.start_game()
	game.net.paused=true
	await shot("board")
	game._toggle_inspection()
	await shot("world")
	for kind in 6:
		var target=-1
		for i in game.state.tiles.size():
			if game.state.tiles[i].kind==kind:target=i;break
		var tile=game.state.tiles[target]
		game.board.camera_focus=Vector3(tile.x*CatanBoard.TILE_SIZE,.65,tile.z*CatanBoard.TILE_SIZE)
		game.board.camera_zoom=.27
		game.board.pitch=.68
		game.board.yaw=.10
		game.board._update_camera()
		await shot(CatanTileArt.BIOMES[kind])
	game.board.reset_camera()
	game._toggle_inspection()
	game._open_settings()
	await shot("settings")
	game.modal.select_tab("Lighting")
	await shot("lighting")
	game.modal.select_tab("World")
	await shot("water-settings")
	game._close_modal()
	game.net.leave()
	game.queue_free()
	await process_frame
	quit()
