extends SceneTree
func _initialize():call_deferred("run")
func shot(label):
	await create_timer(.8).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/catan-water-"+label+".png")
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await create_timer(1).timeout
	game.ui.visible=false
	var board=game.board;board.view_region=Rect2();board.show_labels=false
	board.camera_focus=Vector3.ZERO;board.camera_zoom=.8;board._update_camera()
	for time in [150,300,450]:
		board.day_seconds=time;board.advance_day(0)
		await shot(str(time))
	board.day_seconds=150;board.advance_day(0)
	var harbor=board.harbors[0]
	board.camera_focus=harbor.global_position+Vector3.UP;board.camera_zoom=.24;board.pitch=.48;board._update_camera()
	for quality in [0,2,3]:
		game.preferences.set_value("water_quality",quality);game._apply_preferences()
		await shot("coast-"+str(quality))
	game.preferences.set_value("reduce_motion",true);game._apply_preferences()
	await shot("still")
	print("WATER_VISUAL_TEST: day, dusk, night, low/high/ultra coast and reduced motion rendered")
	game.queue_free();await process_frame;quit()
