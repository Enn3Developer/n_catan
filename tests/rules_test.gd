extends SceneTree
## Headless checks for board generation and the rules that changed with room
## settings. Run: godot --headless --path . --script tests/rules_test.gd

var failures=0

func _init():
	_island_shapes()
	_ports()
	_trade_flow()
	_friendly_robber()
	_points_target()
	_log_tail()
	print("rules_test: %s" % ("FAILED (%d)" % failures if failures else "ok"))
	quit(1 if failures else 0)

func check(condition: bool,message: String):
	if not condition:
		failures+=1
		push_error(message)

func _island_shapes():
	for players in [3,6]:
		var names=[]
		for i in players: names.append("P%d" % i)
		var shapes={}
		for game_seed in range(1,41):
			var rules=CatanRules.new()
			var s=rules.create(names,game_seed)
			check(s.tiles.size()==(30 if players>4 else 19),"tile count")
			var shape=[]
			for t in s.tiles: shape.append("%d,%d" % [roundi(t.x*10),roundi(t.z*10)])
			shape.sort()
			shapes[",".join(shape)]=true
			check(CatanRules.island_scale(s)<2.0,"island stays compact: %f" % CatanRules.island_scale(s))
			var coast=rules._coast_loop()
			var coastal=0
			for e in s.edges: if e.tiles==1: coastal+=1
			check(coast.size()==coastal,"coast forms a single loop (seed %d)" % game_seed)
			var again=CatanRules.new().create(names,game_seed)
			check(again.tiles==s.tiles and again.vertices==s.vertices,"same seed, same board")
		check(shapes.size()>30,"seeds give different shapes: %d" % shapes.size())
	var classic=CatanRules.new().create(["A","B","C"],5,{"island":"classic"})
	check(is_equal_approx(CatanRules.island_scale(classic),1.0),"classic scale")

func _ports():
	var layouts={}
	for game_seed in range(1,21):
		var rules=CatanRules.new()
		var s=rules.create(["A","B","C"],game_seed,{"island":"classic"})
		var kinds={}
		var ported=[]
		for e in s.edges:
			var a=s.vertices[e.a]
			var b=s.vertices[e.b]
			if e.tiles==1 and a.port!=-2 and a.port==b.port:
				kinds[a.port]=kinds.get(a.port,0)+1
				ported.append(str(a.port))
		check(kinds.get(-1,0)==4 and kinds.size()==6,"nine harbors: %s" % kinds)
		layouts[",".join(ported)]=true
	check(layouts.size()>10,"ports shuffle with the seed")

func _setup(rules: CatanRules):
	var bot=CatanBot.new(3)
	while str(rules.s.phase).begins_with("setup"):
		var p=rules.s.turn
		check(rules.apply(p,bot.choose(rules.snapshot(p),p,1))=="","setup move")

func _trade_flow():
	var rules=CatanRules.new()
	rules.create(["A","B","C","D"],11)
	_setup(rules)
	var s=rules.s
	s.rolled=true
	s.players[0].hand=[2,0,0,0,0]
	s.players[1].hand=[0,2,0,0,0]
	s.players[2].hand=[0,0,3,0,0]
	s.players[3].hand=[0,1,0,0,0]
	check(rules.apply(0,{"type":"offer_trade","give":[1,0,0,0,0],"receive":[0,1,0,0,0]})=="","offer")
	check(rules.apply(1,{"type":"accept_trade"})=="","B accepts")
	check(s.players[0].hand==[2,0,0,0,0],"accepting does not trade on the spot")
	check(rules.apply(0,{"type":"confirm_trade","id":1})!="","offerer waits for answers")
	check(rules.apply(2,{"type":"accept_trade"})!="","C cannot afford")
	check(rules.apply(2,{"type":"counter_trade","give":[2,0,0,0,0],"receive":[0,0,1,0,0]})=="","C counters")
	check(rules.apply(3,{"type":"decline_trade"})=="","D declines")
	check(not s.offer.waiting,"everyone answered")
	check(rules.apply(0,{"type":"confirm_trade","id":3})!="","cannot pick a decliner")
	check(rules.apply(0,{"type":"confirm_trade","id":2})=="","take the counter")
	check(s.players[0].hand==[0,0,1,0,0] and s.players[2].hand==[2,0,2,0,0],"counter terms applied")
	check(s.offer.is_empty(),"offer closes")
	check(s.players[0].stats.trades==1 and s.players[2].stats.trades==1,"trade stats")

func _friendly_robber():
	var rules=CatanRules.new()
	rules.create(["A","B","C"],21,{"friendly_robber":true})
	_setup(rules)
	var s=rules.s
	s.phase="robber"
	var sites=rules.robber_sites(0)
	for t in s.tiles.size():
		var touches=false
		for v in s.tiles[t].corners:
			if s.vertices[v].owner in [1,2]: touches=true
		if touches: check(t not in sites,"friendly robber spares small players")
	var blocked=-1
	for t in s.tiles.size():
		if t!=s.robber and t not in sites: blocked=t
	check(blocked>=0 and rules.apply(0,{"type":"robber","id":blocked})!="","blocked hex refused")

func _points_target():
	var rules=CatanRules.new()
	rules.create(["A","B","C"],31,{"points":5})
	_setup(rules)
	var s=rules.s
	s.rolled=true
	s.players[0].hand=[0,0,0,2,3]
	var city=-1
	for v in s.vertices.size():
		if s.vertices[v].owner==0: city=v
	check(rules.apply(0,{"type":"city","id":city})=="","city")
	check(s.winner==-1,"3 points is short of 5")
	s.players[0].new_cards[4]=2
	check(rules.apply(0,{"type":"end"})=="" and s.winner==0,"5 points wins with a target of 5")

func _log_tail():
	var rules=CatanRules.new()
	rules.create(["A","B","C"],41)
	for i in 100: rules._log("line %d" % i)
	var snap=rules.snapshot(0)
	check(snap.log.size()==40 and snap.log_start==61 and snap.log[-1]=="line 99","log tail")
	check(rules.s.log.size()==101,"host keeps the whole log")
