extends SceneTree
var player_count=3
var net: CatanNetwork
var state={}
var ready_sent=false
var busy=false
var turns=0
var test_name=""
var reported=false
func _initialize(): call_deferred("run")
func run():
	test_name=OS.get_cmdline_user_args()[0]
	if OS.get_cmdline_user_args().size()>1: player_count=int(OS.get_cmdline_user_args()[1])
	var game=Node.new()
	game.name="Catan"
	root.add_child(game)
	net=CatanNetwork.new()
	net.name="Network"
	game.add_child(net)
	net.changed.connect(lobby)
	net.received.connect(receive)
	net.notice.connect(func(message): print("NOTICE ",test_name,": ",message))
	net.join_room(OS.get_cmdline_user_args()[2],test_name,"test-room")
	create_timer(25).timeout.connect(func(): printerr("CLIENT_TIMEOUT ",test_name); quit(1))
func lobby():
	if net.seat>=0 and not ready_sent:
		ready_sent=true
		net.ready_up()
	if net.seat==0 and net.roster.size()==player_count and net.roster.all(func(row):return row.ready): net.start_game()
func receive(data: Dictionary):
	state=data
	if busy: return
	busy=true
	await create_timer(0.13).timeout
	busy=false
	if state.turn!=net.seat and not state.discards.has(str(net.seat)): return
	var r=CatanRules.new()
	r.s=state
	var action={}
	match state.phase:
		"setup_settlement":
			for v in state.vertices.size():
				if r.valid_vertex(net.seat,v,true):
					action={"type":"settlement","id":v}
					break
		"setup_road":
			for e in state.edges.size():
				if r.valid_edge(net.seat,e,true):
					action={"type":"road","id":e}
					break
		"discard":
			if not state.discards.has(str(net.seat)): return
			var count=state.discards[str(net.seat)]
			var cards=[0,0,0,0,0]
			for res in 5:
				cards[res]=mini(count,state.players[net.seat].hand[res])
				count-=cards[res]
			action={"type":"discard","cards":cards}
		"robber": action={"type":"robber","id":(state.robber+1)%state.tiles.size()}
		"steal": action={"type":"steal","id":state.victims[0]}
		"play":
			if not state.rolled: action={"type":"roll"}
			else:
				action={"type":"end"}
				turns+=1
	if not action.is_empty(): net.act(action)
	if turns>=5 and not reported:
		reported=true
		print("ONLINE_CLIENT_PASS ",test_name," seat=",net.seat," turns=",turns," private_hand=",state.players[(net.seat+1)%player_count].hand.is_empty())
		# Wait so the other client can finish its last turn.
		await create_timer(5.0).timeout
		quit()
