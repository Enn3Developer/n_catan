extends SceneTree
var game
func _initialize():call_deferred("run")
func shot(label):
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/catan-password-"+label+".png")
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await create_timer(.5).timeout
	game._node("ShowOnline").button_pressed=true
	await shot("host")
	game.screen.show_online_mode(false);await shot("join")
	root.size=Vector2i(800,600);game.screen.show_online_mode(true);game._queue_layout()
	game._node("MenuScroll").ensure_control_visible(game._node("HostOnline"));await shot("host-small")
	game.queue_free();await process_frame;await process_frame;quit()
