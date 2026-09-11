extends SceneTree
var game
func _initialize():call_deferred("run")
func shot(label):
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/catan-music-"+label+".png")
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await create_timer(1).timeout
	game._open_music();game.net.music_control("select",1);await shot("library-home")
	game._close_modal();game._solo();game.net.start_game();game.net.paused=true
	var r=game.net.rules;r.s.phase="play";r.s.rolled=true;r.s.turn=0
	r.s.players[0].hand=[4,3,2,4,3];game.net._sync()
	game.net.music_control("select",2);await shot("hud")
	game._open_music();await shot("library")
	root.size=Vector2i(800,600);game._queue_layout();await shot("library-small")
	game._close_modal();game.net.paused=true;await shot("hud-small")
	game.net.leave();game.queue_free();await process_frame;await process_frame;quit()
