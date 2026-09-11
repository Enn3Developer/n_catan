extends SceneTree
var peers=[]
var states=[{},{},{}]
var failures=0
func check(value: bool,message: String):
	if not value: failures+=1; printerr("FAIL: ",message)
func _initialize(): call_deferred("run")
func wait_net(): await create_timer(0.15).timeout
func make_peer(index: int):
	var branch=Node.new()
	branch.name="Peer%d" % index
	root.add_child(branch)
	set_multiplayer(SceneMultiplayer.new(),branch.get_path())
	var peer=CatanNetwork.new()
	peer.name="Network"
	branch.add_child(peer)
	peer.received.connect(func(data):states[index]=data)
	peers.append(peer)
	return peer
func run():
	var host=make_peer(0)
	var a=make_peer(1)
	var b=make_peer(2)
	host.host("Host")
	a.join_room(host.invite("127.0.0.1"),"Ada")
	b.join_room(host.invite("127.0.0.1"),"Bo")
	await create_timer(0.5).timeout
	a.configure_bot("add")
	await wait_net()
	check(host.roster.size()==3,"guest cannot add bots")
	host.configure_bot("add",-1,2)
	await wait_net()
	check(a.roster.size()==4 and a.roster[3].bot and a.roster[3].difficulty==2,"bot difficulty replicated")
	for peer in peers: peer.ready_up()
	await wait_net()
	host.start_game()
	host.bot_delay=0.1
	await wait_net()
	var helper=CatanBot.new(710)
	for iteration in 100:
		if host.rules.s.phase=="play": break
		var p=host.rules.s.turn
		if not host.roster[p].bot:
			for actor in peers:
				if actor.seat==p: actor.act(helper.choose(host.rules.snapshot(p),p,1))
		await wait_net()
	check(host.rules.s.phase=="play","online bot completes setup")
	check(host.rules.pieces(3,"settlement")==2 and host.rules.pieces(3,"road")==2,"online bot built pieces")
	check(states[1].vertices==states[2].vertices,"bot board replicated to remote peers")
	check(states[1].players[3].hand.is_empty() and states[1].players[3].cards.is_empty(),"bot private state withheld")
	for peer in peers: peer.leave()
	await wait_net()
	# The first human on a dedicated server is its lobby controller.
	host.host("Dedicated","",true)
	a.join_room(host.invite("127.0.0.1"),"Ada")
	await create_timer(0.3).timeout
	b.join_room(host.invite("127.0.0.1"),"Bo")
	await create_timer(0.3).timeout
	check(a.is_controller() and not b.is_controller(),"dedicated lobby authority")
	a.configure_bot("add",-1,0)
	await wait_net()
	check(host.roster.size()==3 and host.roster[2].difficulty==0,"dedicated controller adds bot")
	b.configure_bot("remove",2)
	await wait_net()
	check(host.roster.size()==3,"guest cannot remove bot")
	a.ready_up()
	b.ready_up()
	await wait_net()
	a.start_game()
	await wait_net()
	check(a.started and b.started and host.started,"dedicated mixed room starts")
	for peer in peers: peer.leave()
	print("BOT_NETWORK_TEST: online mix, private bot state, guest restrictions, dedicated control; ",failures," failures")
	quit(1 if failures else 0)
