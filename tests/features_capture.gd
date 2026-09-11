extends SceneTree
func _initialize(): call_deferred("run")
func shot(name_value: String):
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("/tmp/catan-v2-%s.png" % name_value)
func run():
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(1).timeout
	await shot("home")
	game._solo()
	await shot("lobby")
	game._open_settings()
	await shot("settings")
	game._close_modal()
	game._tutorial_start()
	await shot("tutorial")
	game.guide.step=3
	game.guide.load_lesson(game.net,"Voyager")
	await shot("practice")
	print("FEATURE_CAPTURE_DONE audio_playing=",game.audio.music.playing," position=",game.audio.music.get_playback_position())
	quit()
