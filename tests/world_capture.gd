extends SceneTree
# Visual review fixture. Does not save or change the player's preferences.
var game
func _initialize():call_deferred("run")
func shot(label: String):
	await create_timer(.35).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/catan-world-"+label+".png")
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await create_timer(.5).timeout
	root.size=Vector2i(1440,900)
	game.ui.visible=false
	var board=game.board
	board.show_labels=false;board.view_region=Rect2();board.reduce_motion=true
	var data=board.state.duplicate(true)
	var chosen=[]
	for i in data.vertices.size():
		var v=data.vertices[i];var at=Vector2(v.x,v.z)
		if chosen.any(func(p):return p.distance_to(at)<1.6):continue
		v.owner=i%3;v.level=2 if chosen.size()%2==0 else 1
		chosen.append(at)
		if chosen.size()==8:break
	for i in range(0,data.edges.size(),7):data.edges[i].owner=i%3
	board.refresh(data)
	board.day_seconds=150;board.advance_day(0)
	board.camera_focus=Vector3(0,.19*board.TILE_SIZE,0);board.camera_zoom=.85;board.pitch=.85;board.yaw=.2;board._update_camera()
	await shot("overview")
	for kind in 6:
		for tile in data.tiles:
			if tile.kind!=kind:continue
			board.camera_focus=Vector3(tile.x*board.TILE_SIZE,.27*board.TILE_SIZE,tile.z*board.TILE_SIZE)
			board.camera_zoom=.17;board.pitch=.85;board.yaw=.2;board._update_camera()
			board.living_world.animate(board.actors,5,board.art)
			await shot(CatanTileArt.BIOMES[kind])
			board.yaw=PI+.2;board._update_camera()
			await shot(CatanTileArt.BIOMES[kind]+"-reverse")
			if kind==2:
				board.day_seconds=450;board.advance_day(0)
				await shot("pasture-night")
				board.day_seconds=150;board.advance_day(0)
			break
	# Check the same board under the lowest detail settings.
	var low=CatanSettings.DEFAULTS.duplicate(true)
	low.merge(CatanSettings.PRESETS[0],true)
	board.apply_preferences(low)
	board.camera_focus=Vector3(0,.19*board.TILE_SIZE,0);board.camera_zoom=.85;board.pitch=.85;board.yaw=.2;board._update_camera()
	await shot("low-detail")
	game.queue_free();await process_frame
	print("WORLD_CAPTURE: complete");quit()
