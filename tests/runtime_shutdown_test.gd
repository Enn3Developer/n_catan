extends SceneTree
func _initialize():call_deferred("run")
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await create_timer(.4).timeout
	game._solo();game.net.start_game();game.net.paused=true
	game.audio.follow_soundtrack({"track":2,"position":1.0,"paused":false},.016)
	game.audio.play("build")
	game._open_settings();game._close_modal()
	# Exit in the same frame as starting music/effects: this previously leaked
	# playback objects and Ogg resources. The runner also checks engine stderr.
	if "--wm-close" in OS.get_cmdline_user_args():
		game.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	else:game._exit_desktop()
	assert(game.quitting,"exit request is handled by the game")
	assert(not auto_accept_quit,"window close uses the same cleanup path")
	print("RUNTIME_SHUTDOWN_TEST: exit requested")
