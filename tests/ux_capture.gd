extends SceneTree
var game
func _initialize():call_deferred("run")
func shot(label):
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/catan-sept11-"+label+".png")
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await create_timer(1).timeout
	game._solo();game.net.start_game();game.net.paused=true
	var r=game.net.rules;r.s.phase="play";r.s.rolled=true;r.s.turn=0
	r.s.players[0].hand=[4,3,2,4,3];r.s.players[0].cards=[2,1,1,0,2];r._score();game.net._sync()
	await shot("hud")
	game._trade();await shot("trade");game._close_modal()
	game.board.day_seconds=450;game.board.advance_day(0);await shot("night")
	game.board.day_seconds=150;game.board.advance_day(0)
	game.board.throw_dice([5,3]);await create_timer(.55).timeout;await shot("dice-air")
	await create_timer(1).timeout;await shot("dice-land")
	root.size=Vector2i(800,600);game._queue_layout();await shot("small")
	game._trade();await shot("trade-small");game._close_modal()
	game.net.leave();game.queue_free();await process_frame;quit()
