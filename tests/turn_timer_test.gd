extends SceneTree
## The host plays a stalling seat out once its turn timer expires.
var peers=[]
var states=[{},{},{}]
var notices=[]
var forced=[]
var failures=0
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
func run():
	var host=make_peer(0)
	var a=make_peer(1)
	var b=make_peer(2)
	host.applied.connect(func(_player,action): forced.append(str(action.get("type",""))))
	check(host.host("Host","")==OK,"server listens")
	check(a.join_room(host.invite("127.0.0.1"),"Ada","")==OK,"client A connects")
	check(b.join_room(host.invite("127.0.0.1"),"Bo","")==OK,"client B connects")
	for i in 40:
		if host.roster.size()==3: break
		await create_timer(0.1).timeout
	check(host.roster.size()==3,"lobby filled")
	host.turn_seconds=0.35
	host.bot_delay=0.05
	for peer in peers: peer.ready_up()
	await create_timer(0.25).timeout
	host.start_game()
	await create_timer(0.25).timeout
	check(host.started,"game started")
	check(float(states[1].get("turn_limit",0.0))==0.35,"clients receive the turn limit")
	check(float(states[1].get("turn_seconds",-1.0))>0.0,"clients receive the countdown")
	check(host.rules.s.setup==0,"nobody has placed yet")

	# Nobody acts: every setup placement has to come from the expired timer.
	await create_timer(3.0).timeout
	check(host.rules.s.phase=="play","stalled setup completes on its own")
	check(host.rules.s.setup==6,"all six setup placements were forced")
	var settlements=0
	for v in host.rules.s.vertices:
		if v.owner!=-1: settlements+=1
	check(settlements==6,"forced placements are real settlements")
	for seat in 3:
		check(host.rules.pieces(seat,"settlement")==2 and host.rules.pieces(seat,"road")==2,"seat %d was played out fairly" % seat)
	check(notices.any(func(message): return "ran out" in message),"the stalling seat is told why")

	# A stalled play turn still rolls for production, then passes on.
	forced.clear()
	var seen={}
	var rearmed=0.0
	for i in 60:
		await create_timer(0.1).timeout
		seen[int(host.rules.s.turn)]=true
		rearmed=maxf(rearmed,host.turn_clock)
		if seen.size()>=3 and forced.has("roll") and forced.has("end"): break
	check(forced.has("roll"),"the timer rolls the dice before ending the turn")
	check(forced.has("end"),"the timer ends the stalled turn")
	check(seen.size()>=3,"the turn keeps moving between seats")
	# Each new turn starts from the full budget again.
	check(rearmed>0.0 and rearmed<=host.turn_seconds,"the clock rearms on every new turn")
	# A seven hands the wait to the discarders, who get their own budget.
	host.turn_clock=0.0
	host.turn_expired=true
	host.rules.s.phase="discard"
	host._refresh_turn_clock()
	check(host.turn_clock==host.turn_seconds and not host.turn_expired,"discarders are not played out on the roller's spent clock")

	print("turn timer failures: ",failures)
	quit(1 if failures>0 else 0)
