extends SceneTree
var failures=0
var checks=0
func check(condition: bool,message: String):
	checks+=1
	if not condition:
		failures+=1
		printerr("FAIL: ",message)
func _initialize():
	call_deferred("run")
func setup(r: CatanRules,count: int=4):
	var names=[]
	for i in count: names.append("Player %d" % i)
	r.create(names,1234)
	while r.s.phase.begins_with("setup"):
		var action={}
		if r.s.phase=="setup_settlement":
			for v in 54:
				if r.valid_vertex(r.s.turn,v,true):
					action={"type":"settlement","id":v}
					break
		else:
			for e in 72:
				if r.valid_edge(r.s.turn,e,true):
					action={"type":"road","id":e}
					break
		check(r.apply(r.s.turn,action)=="","setup action")
func run():
	var r=CatanRules.new()
	setup(r)
	check(r.s.vertices.size()==54,"54 shared corners")
	check(r.s.edges.size()==72,"72 shared edges")
	check(r.s.tiles.size()==19,"19 hexes")
	check(r.s.deck.size()==25,"25 development cards")
	for p in 4:
		check(r.pieces(p,"settlement")==2 and r.pieces(p,"road")==2,"snake setup pieces")
		check(r.s.players[p].points==2,"setup points")
	check(r.s.turn==0 and r.s.phase=="play","first player starts")
	var before=r.s.duplicate(true)
	check(r.apply(1,{"type":"roll"})!="","out-of-turn denied")
	check(r.s==before,"invalid move does not change state")
	check(r.apply(0,{"type":"city","id":0})!="","must roll before building")
	var view=r.snapshot(0)
	check(view.players[0].hand.size()==5 and view.players[1].hand.is_empty(),"private resources")
	check(not view.has("deck") and view.players[1].cards.is_empty(),"private cards")
	# Resource conservation through hundreds of random rolls, trades and turns.
	for turn in 150:
		var p=r.s.turn
		check(r.apply(p,{"type":"roll"})=="","roll succeeds")
		check(r.apply(p,{"type":"roll"})!="","double roll rejected")
		if r.s.phase=="discard":
			for key in r.s.discards.keys():
				var count=r.s.discards[key]
				var cards=[0,0,0,0,0]
				for res in 5:
					cards[res]=mini(count,r.s.players[int(key)].hand[res])
					count-=cards[res]
				check(r.apply(int(key),{"type":"discard","cards":cards})=="","discard accepted")
		if r.s.phase=="robber": check(r.apply(p,{"type":"robber","id":(r.s.robber+1)%19})=="","robber move")
		if r.s.phase=="steal": check(r.apply(p,{"type":"steal","id":r.s.victims[0]})=="","steal")
		for res in 5:
			var total=r.s.bank[res]
			for player in r.s.players: total+=player.hand[res]
			check(total==19,"resource conservation")
		check(r.apply(p,{"type":"end"})=="","end turn")
	# Specific economy and card checks.
	r.s.players[0].hand=[5,5,5,5,5]
	r.s.bank=[14,14,14,14,14]
	r.s.turn=0
	r.s.rolled=true
	for p in range(1,4): r.s.players[p].hand=[0,0,0,0,0]
	check(r.apply(0,{"type":"bank_trade","give":0,"receive":1})=="","bank trade")
	check(r.apply(0,{"type":"bank_trade","give":-1,"receive":3})!="","bad bank index")
	check(r.apply(0,{"type":"buy_card"})=="","buy development")
	check(r.total(r.s.players[0].new_cards)==1,"new card locked")
	r.s.players[0].cards=[1,1,1,1,0]
	check(r.apply(0,{"type":"play_card","id":2,"cards":[1,0,0,1,0]})=="","year of plenty")
	check(r.apply(0,{"type":"play_card","id":0})!="","one card per turn")
	r.s.players[1].hand=[0,2,0,0,0]
	check(r.apply(0,{"type":"offer_trade","give":[0,0,1,0,0],"receive":[0,1,0,0,0]})=="","offer trade")
	check(r.apply(1,{"type":"accept_trade"})=="","accept out-of-turn trade")
	check(r.s.players[1].hand==[0,1,1,0,0],"trade transferred resources")
	check(r.apply(0,{"type":"settlement","id":999})!="","bad vertex rejected")
	check(r.apply(0,{"type":"road","id":-1})!="","bad edge rejected")
	# Longest road is an edge-simple trail and an enemy settlement blocks it.
	var road_rules=CatanRules.new()
	road_rules.create(["A","B"],91)
	var path=[]
	var visited={0:true}
	_find_path(road_rules,0,visited,path,6)
	check(path.size()==6,"six-edge test path")
	for eid in path: road_rules.s.edges[eid].owner=0
	road_rules._score()
	check(road_rules.s.players[0].road_length==6 and road_rules.s.longest==0,"longest road scoring")
	var middle=road_rules.s.edges[path[2]]
	var next=road_rules.s.edges[path[3]]
	var vertex=middle.a if middle.a in [next.a,next.b] else middle.b
	road_rules.s.vertices[vertex].owner=1
	road_rules.s.vertices[vertex].level=1
	road_rules._score()
	check(road_rules.s.players[0].road_length==3 and road_rules.s.longest==-1,"opponent interrupts road")
	road_rules.s.players[0].knights=3
	road_rules._score()
	check(road_rules.s.army==0,"largest army")
	road_rules.s.players[0].cards[4]=8
	road_rules._score()
	check(road_rules.s.winner==0,"hidden VP victory")
	# Construction must charge exact costs and enforce the distance rule.
	var build=CatanRules.new()
	build.create(["Builder","Neighbor"],881)
	build.s.phase="play"
	build.s.rolled=true
	build.s.vertices[0].owner=0
	build.s.vertices[0].level=1
	build.s.players[0].hand=[8,8,8,8,8]
	var route=[]
	_find_path(build,0,{0:true},route,2)
	check(build.apply(0,{"type":"road","id":route[0]})=="","first connected road")
	var first_edge=build.s.edges[route[0]]
	var adjacent=first_edge.b if first_edge.a==0 else first_edge.a
	check(build.apply(0,{"type":"settlement","id":adjacent})!="","distance rule rejects adjacent settlement")
	check(build.apply(0,{"type":"road","id":route[1]})=="","second connected road")
	var second_edge=build.s.edges[route[1]]
	var destination=second_edge.b if second_edge.a==adjacent else second_edge.a
	check(build.apply(0,{"type":"settlement","id":destination})=="","new settlement connected at distance two")
	check(build.s.players[0].hand==[5,5,7,7,8],"exact construction costs")
	check(build.apply(0,{"type":"city","id":destination})=="","city upgrade")
	check(build.s.players[0].hand==[5,5,7,5,5],"exact city cost")
	check(build.s.vertices[destination].level==2 and build.s.players[0].points==3,"city score replaces settlement")
	build.s.players[0].cards=[1,1,1,1,0]
	build.s.players[1].hand=[0,0,3,0,0]
	check(build.apply(0,{"type":"play_card","id":3,"resource":2})=="","monopoly card")
	check(build.s.players[0].hand[2]==10 and build.s.players[1].hand[2]==0,"monopoly transfers all chosen resources")
	build.s.card_played=false
	build.s.rolled=false
	check(build.apply(0,{"type":"play_card","id":0})=="" and build.s.phase=="robber","knight before roll")
	check(build.s.players[0].knights==1,"knight increments army")
	print("RULES_TEST: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func _find_path(r: CatanRules,v: int,visited: Dictionary,path: Array,length: int) -> bool:
	if path.size()==length: return true
	for eid in r.s.vertices[v].edges:
		var e=r.s.edges[eid]
		var other=e.b if e.a==v else e.a
		if visited.has(other): continue
		visited[other]=true
		path.append(eid)
		if _find_path(r,other,visited,path,length): return true
		path.pop_back()
		visited.erase(other)
	return false
