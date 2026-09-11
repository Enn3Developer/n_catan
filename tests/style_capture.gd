extends SceneTree
var game
func _initialize():call_deferred("run")
func shot(label: String):
	await create_timer(.7).timeout
	root.get_texture().get_image().save_png("/tmp/catan-style-"+label+".png")
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await create_timer(2).timeout
	game.preferences.reset();game._apply_preferences()
	await shot("home")
	game._solo();game.net.roster[0].name="Avery";game.net.roster[1].name="Morgan";game.net.roster[2].name="Rowan"
	game.net.start_game();game.net.paused=true
	var rules=game.net.rules
	var bot=CatanBot.new(713)
	while rules.s.phase.begins_with("setup"):
		rules.apply(rules.s.turn,bot.choose(rules.snapshot(rules.s.turn),rules.s.turn,2))
	# Explicit visual fixture: representative buildings, hands and dice.
	rules.s.rolled=true;rules.s.dice=[3,5];rules.s.players[0].hand=[4,3,2,5,3]
	for v in rules.s.vertices:
		if v.owner==0:v.level=2
	rules._score();game.net._sync()
	await shot("board")
	game._trade();await shot("trade");game._close_modal();game.net.paused=true
	game._toggle_inspection()
	await shot("world")
	for kind in 6:
		for tile in game.state.tiles:
			if tile.kind!=kind:continue
			game.board.camera_focus=Vector3(tile.x*CatanBoard.TILE_SIZE,.65,tile.z*CatanBoard.TILE_SIZE)
			game.board.camera_zoom=.25;game.board.pitch=.65;game.board.yaw=.15;game.board._update_camera()
			await shot(CatanTileArt.BIOMES[kind]);break
	game.board.reset_camera()
	print("STYLE_RENDER: FPS=",Engine.get_frames_per_second()," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)," draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	game.net.leave();game.queue_free();await process_frame;quit()
