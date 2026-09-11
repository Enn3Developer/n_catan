extends SceneTree
var game
var checks=0
var failures=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func settle():await create_timer(.3).timeout
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await settle()
	game._solo();game.net.start_game();game.net.paused=true;await settle()
	check(game._node("EmptyCards")!=null,"empty hand has no zero-count card placeholders")
	var s=game.net.rules.s
	s.phase="play";s.rolled=true;s.turn=0;s.card_played=false
	s.players[0].cards=[2,1,1,1,1];s.players[0].new_cards=[0,0,1,0,0];s.players[0].hand=[4,4,4,4,4]
	game.net._sync();await settle()
	game.turn_banner.hide()
	check(not game._node("Bottom").is_ancestor_of(game._node("CardsBody")),"cards are outside bottom panel")
	check(game._node("CardsBody").get_child_count()==5,"all owned card types visible")
	check(game._node("Card4").disabled,"victory card cannot be played")
	for dimensions in [Vector2i(800,600),Vector2i(1440,900)]:
		root.size=dimensions;game._queue_layout();await settle()
		var bounds=Rect2(Vector2.ZERO,Vector2(dimensions))
		check(absf(game._node("Bottom").get_global_rect().get_center().x-dimensions.x*.5)<1,"bottom panel is centered on window")
		var resources=game._node("HandBody").get_child(0)
		check(absf(resources.get_global_rect().get_center().x-game._node("Bottom").get_global_rect().get_center().x)<1,"resource group is centered within bottom panel")
		check(not game._node("Bottom").get_global_rect().intersects(game._node("CardsRail").get_global_rect()),"cards stay clear of bottom controls")
		for i in 5:
			var card=game._node("Card%d" % i)
			check(bounds.encloses(card.get_global_rect()),"card fits "+str(dimensions))
			check(card.size.y>=76,"compact card retains title and illustration")
			if i<4:check(game._node("Card%d" % (i+1)).position.y-card.position.y>=30,"each stacked card title remains visible")
		check(game.board.view_region.end.x<game._node("CardsRail").get_global_rect().position.x,"board camera leaves space for hand")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/catan-card-hand-%d.png" % dimensions.x)
	var knight=game._node("Card0")
	knight.mouse_entered.emit();await settle()
	check(knight.z_index==2 and knight.position.x<0,"hover reveals full card face")
	knight.mouse_exited.emit();await settle()
	check(knight.z_index==0 and knight.position.x==0,"card returns to hand after hover")
	game._node("Card0").pressed.emit();await settle()
	check(game.net.rules.s.card_played and game.net.rules.s.players[0].cards[0]==1,"card face plays a knight")
	game.net.leave();game.queue_free();await process_frame;await process_frame
	print("CARDS_UI_TEST: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
