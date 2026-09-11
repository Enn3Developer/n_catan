extends SceneTree
var net
var role=""
var folder=""
var initialized=false
var reported=false
func _initialize():call_deferred("run")
func run():
	role=OS.get_cmdline_user_args()[0];folder=OS.get_cmdline_user_args()[1]
	var game=Node.new();game.name="Catan";root.add_child(game)
	net=CatanNetwork.new();net.name="Network";game.add_child(net)
	net.changed.connect(lobby);net.received.connect(receive)
	if role=="host":net.host("Host","test");net.ready_up();net.configure_bot("add")
	elif role=="first":net.join_room(FileAccess.get_file_as_string(folder+"/invite"),"Returner","test")
	else:
		if net.reconnect_token.is_empty():printerr("No saved token");quit(1);return
		net.reconnect_password="test";net.reconnect()
	if role=="host":
		var invite_file=FileAccess.open(folder+"/invite",FileAccess.WRITE)
		invite_file.store_string(net.invite("127.0.0.1"));invite_file.close()
	create_timer(25).timeout.connect(func():quit(1))
func lobby():
	if role=="host":
		if not net.started and net.roster.size()==3 and net.roster.all(func(row):return row.ready):
			net.start_game();net.paused=true
			var seat=2
			net.rules.s.phase="play";net.rules.s.turn=seat;net.rules.s.rolled=false
			net.rules.s.players[seat].hand=[2,3,4,5,6]
			net.rules.s.players[seat].cards=[1,0,0,0,2]
			net.rules._log("Reconnect fixture");net._sync()
	elif role=="first" and net.seat>=0 and not net.started and not initialized:
		initialized=true;net.ready_up()
func receive(data):
	if role=="host" or not data.log.has("Reconnect fixture") or reported:return
	if net.seat!=2 or data.players[2].cards!=[1,0,0,0,2] or not data.players[0].hand.is_empty():
		printerr("Wrong seat or private cards after reconnect");quit(1);return
	if role!="first" and not data.rolled:
		net.act({"type":"roll"});return
	reported=true
	var file=FileAccess.open(folder+"/"+role,FileAccess.WRITE);file.store_string("PASS");file.close()
	print("RECONNECT_PASS ",role," seat=",net.seat)
