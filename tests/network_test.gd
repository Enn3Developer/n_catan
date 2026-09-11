extends SceneTree
var peers=[]
var states=[{},{},{}]
var failures=0
var notices=[]
func check(condition: bool,message: String):
	if not condition:
		failures+=1
		printerr("FAIL: ",message)
func _initialize(): call_deferred("run")
func make_peer(index: int) -> CatanNetwork:
	var branch=Node.new()
	branch.name="Peer%d" % index
	root.add_child(branch)
	var api=SceneMultiplayer.new()
	set_multiplayer(api,branch.get_path())
	var peer=CatanNetwork.new()
	peer.name="Network"
	branch.add_child(peer)
	peer.received.connect(func(data): states[index]=data)
	peer.notice.connect(func(message): notices.append(message))
	peers.append(peer)
	return peer
func wait_net(): await create_timer(0.22).timeout
func run():
	var host=make_peer(0)
	var a=make_peer(1)
	var b=make_peer(2)
	check(host.host("Host","secret")==OK,"server listens")
	check(a.join_room(host.secure_invite("127.0.0.1"),"Ada","secret")==OK,"client A connects")
	check(b.join_room(host.secure_invite("127.0.0.1"),"Bo","secret")==OK,"client B connects")
	await create_timer(0.8).timeout
	check(host.roster.size()==3 and a.roster.size()==3 and b.roster.size()==3,"lobby replicated")
	check(a.seat>0 and b.seat>0 and a.seat!=b.seat,"distinct player seats")
	host.ready_up()
	a.ready_up()
	b.ready_up()
	await wait_net()
	host.start_game()
	await wait_net()
	check(host.started and a.started and b.started,"game starts on all peers")
	check(states[0].get("vertices",[]).size()==54 and states[1].get("vertices",[]).size()==54,"board synchronized")
	if states[0].is_empty():
		printerr("No state received; stopping network tests.")
		quit(1)
		return
	for index in 3:
		for p in 3:
			check(states[index].players[p].hand.size()==(5 if p==peers[index].seat else 0),"private hand filter")
	# Non-active client attempts a legal-looking placement: rejected on server.
	a.act({"type":"settlement","id":0})
	await wait_net()
	check(host.rules.s.vertices[0].owner==-1 and notices.size()>0,"server rejects out of turn")
	# Play the full founding sequence over real ENet packets.
	for step in 12:
		var p=host.rules.s.turn
		var actor=host
		for peer in peers:
			if peer.seat==p: actor=peer
		var action={}
		if host.rules.s.phase=="setup_settlement":
			for v in 54:
				if host.rules.valid_vertex(p,v,true):
					action={"type":"settlement","id":v}
					break
		else:
			for e in 72:
				if host.rules.valid_edge(p,e,true):
					action={"type":"road","id":e}
					break
		actor.act(action)
		await wait_net()
		check(states[0].vertices==states[1].vertices and states[0].edges==states[2].edges,"move replicated")
	check(host.rules.s.phase=="play","network setup complete")
	host.act({"type":"roll"})
	await wait_net()
	check(states[0].dice==states[1].dice and states[0].dice[0]>0,"server dice replicated")
	b.leave()
	await wait_net()
	check(not host.roster[b.seat if b.seat>=0 else 2].connected or host.roster.any(func(row):return not row.connected),"disconnect marked")
	b.reconnect()
	await create_timer(0.6).timeout
	check(b.started and host.roster.all(func(row): return row.connected),"disconnected seat reconnected")
	check(states[2].vertices==states[0].vertices,"reconnect restores board")
	for peer in peers: peer.leave()
	print("NETWORK_TEST: 3 ENet peers, setup, privacy, rejection, dice, disconnect; %d failures" % failures)
	quit(1 if failures else 0)
