extends SceneTree
var latest={}
var notices=[]
func _initialize():call_deferred("run")
func run():
	var net=load("res://scenes/network.tscn").instantiate()
	root.add_child(net)
	net.received.connect(func(data):latest=data)
	net.notice.connect(func(text):notices.append(text);printerr(text))
	net.host_solo("Human test player")
	for difficulty in 5:net.configure_bot("add",-1,difficulty%3)
	net.start_game()
	net.bot_delay=0.01
	var helper=CatanBot.new(724)
	var iterations=0
	while latest.get("winner",-1)==-1 and iterations<2400:
		iterations+=1
		if latest.turn==0 or latest.discards.has("0"):
			var action=helper.choose(latest,0,1)
			if not action.is_empty():net.act(action)
		await create_timer(0.01).timeout
		if iterations%250==0:print("SOLO_MATCH_PROGRESS ticks=",iterations," points=",latest.players.map(func(p):return p.points))
	var passed=latest.winner!=-1 and notices.is_empty()
	print("EXTENSION_SOLO_MATCH_TEST: winner=",latest.winner," ticks=",iterations," rejections=",notices.size()," passed=",passed)
	net.leave()
	quit(0 if passed else 1)
