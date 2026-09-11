extends SceneTree
var failures=0
func check(ok: bool,message: String):
	if not ok: failures+=1; printerr("FAIL: ",message)
func _initialize(): call_deferred("run")
func shot(label: String):
	await process_frame
	await process_frame
	if DisplayServer.get_name()!="headless": root.get_texture().get_image().save_png("/tmp/catan-extension-%s.png" % label)
func run():
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.5).timeout
	game._solo()
	for i in 3: game.net.configure_bot("add",-1,i)
	await create_timer(0.3).timeout
	check(game.net.roster.size()==6 and game._node("PlayerSlots").get_child_count()==6,"six visible slots")
	check(game._node("RoomSummary").text.begins_with("30 hexes"),"extension identified in lobby")
	check(game._node("CrewActions").get_global_rect().end.y<=game._node("Crew").get_global_rect().end.y,"lobby actions fit panel")
	await shot("lobby")
	game.net.start_game()
	game.net.paused=true
	await create_timer(0.2).timeout
	check(game.state.tiles.size()==30 and game.board.targets.size()==80,"large board and all placement targets")
	check(game.board.board_scale>1 and CatanBoard.PLAYERS.size()==6,"camera and colors expanded")
	await shot("board")
	var r=game.net.rules
	r.s.phase="play"
	r.s.turn=0
	r.s.primary=3
	r.s.paired=true
	r.s.rolled=true
	r.s.players[0].hand=[4,3,3,3,3]
	game.net._sync()
	await create_timer(0.2).timeout
	check(game._node("PlayersBody").get_global_rect().end.y<774,"six player scores fit above hand")
	check(game._node("RollDice").disabled and not game._node("EndTurn").disabled,"paired controls skip dice")
	await shot("paired")
	game._trade()
	await process_frame
	var offer: Button
	for button in game.modal.find_children("*","Button",true,false):
		if button.text=="Offer to all players": offer=button
	check(offer!=null and offer.disabled,"paired domestic trade disabled")
	await shot("trade")
	game._close_modal()
	game.net.leave()
	game.queue_free();await create_timer(.2).timeout
	await process_frame
	print("EXTENSION_UI_TEST: ",failures," failures")
	quit(1 if failures else 0)
