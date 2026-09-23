extends SceneTree
var failures=0
func check(condition: bool,message: String):
	if not condition:
		failures+=1
		printerr("FAIL: ",message)
func _initialize(): call_deferred("run")
func click(button: Button):
	var point=button.get_global_rect().get_center()
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion)
	for pressed in [true,false]:
		var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=point;event.global_position=point;root.push_input(event)
		await process_frame
	await create_timer(0.15).timeout
func run():
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.5).timeout
	# A seat saved by an earlier run would open the online form already.
	game.net.reconnect_token="";game._home()
	game.name_field.text="Host"
	await click(game._node("ShowOnline"))
	await click(game.screen.find_child("HostOnline",true,false))
	check(game.net.online and game.net.seat==0,"host button creates lobby")
	var branch=Node.new()
	branch.name="Client"
	root.add_child(branch)
	var api=SceneMultiplayer.new()
	set_multiplayer(api,branch.get_path())
	var peer_root=Node.new()
	peer_root.name="Catan"
	branch.add_child(peer_root)
	var client=CatanNetwork.new()
	client.name="Network"
	peer_root.add_child(client)
	client.join_room(game.net.invite("127.0.0.1"),"Guest")
	await create_timer(0.5).timeout
	check(game.net.roster.size()==2,"guest appears in lobby")
	await click(game.screen.find_child("ReadyButton",true,false))
	client.ready_up()
	await create_timer(0.2).timeout
	check(game._node("StartGame").disabled,"two ready humans cannot start")
	game.net.start_game()
	check(not game.net.started,"server rejects two-player start")
	await click(game._node("AddBot"))
	await click(game.screen.find_child("StartGame",true,false))
	check(game.state.get("phase","")=="setup_settlement","start button enters game")
	check(game.board.targets.size()==54,"legal placement markers visible")
	var target=game.board.targets[0]
	var point=game.board.camera.unproject_position(target.pos)
	# Feed pointer input through the viewport to exercise hover and picking.
	var motion=InputEventMouseMotion.new()
	motion.position=point
	motion.global_position=point
	root.push_input(motion)
	await process_frame
	game.board.hover=0 # Stable even if the desktop pointer is outside the test window.
	var press=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT
	press.pressed=true
	press.position=point
	game.board._unhandled_input(press)
	await create_timer(0.2).timeout
	check(game.state.phase=="setup_road" and game.state.vertices[target.id].owner==0,"3D click places settlement")
	check(game.board.targets.size() in [2,3],"connected road markers")
	game.board.hover=0
	game.board._unhandled_input(press)
	await create_timer(0.2).timeout
	check(game.state.turn==1 and game.state.phase=="setup_settlement","3D road click advances turn")
	game._help()
	await process_frame
	check(is_instance_valid(game.modal),"guide dialog opens")
	game.net._sync()
	await process_frame
	check(is_instance_valid(game.modal) and game.modal.name=="Guide","guide survives game updates")
	game._close_modal()
	client.leave()
	game.net.leave()
	print("UI_TEST: lobby buttons, board picking, turn change, guide; %d failures" % failures)
	quit(1 if failures else 0)
