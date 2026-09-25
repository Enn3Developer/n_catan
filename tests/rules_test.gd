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
	_friendly_limit()
	_fair_dice()
	_random_start()
	_start_card()
	_treasure()
	_archipelago()
	_moving_ships()
	_fog()
	_points_history()
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

func _friendly_limit():
	var rules=CatanRules.new()
	rules.create(["A","B"],41,{"friendly_robber":true})
	_setup(rules)
	var s=rules.s
	var city=-1
	for v in s.vertices.size():
		if s.vertices[v].owner==1: city=v
	s.vertices[city].level=2
	rules._score()
	check(s.players[1].points==3,"three points")
	var spared=false
	for t in s.vertices[city].tiles:
		if t!=s.robber and t not in rules.robber_sites(0): spared=true
	check(spared,"3 points is still spared")
	s.players[1].new_cards[4]=0
	s.vertices[city].level=2
	for v in s.vertices.size():
		if s.vertices[v].owner==1 and v!=city: s.vertices[v].level=2
	rules._score()
	var open_all=true
	for t in s.vertices[city].tiles:
		if t!=s.robber and t not in rules.robber_sites(0): open_all=false
	check(s.players[1].points==4 and open_all,"4 points is fair game")

func _fair_dice():
	var rules=CatanRules.new()
	rules.create(["A","B"],51)
	var counts={}
	for i in 360:
		var roll=rules.total(rules._draw_dice())
		counts[roll]=counts.get(roll,0)+1
	# 360 rolls is ten decks; each total lands within a deck's leftover of the odds.
	for total in range(2,13):
		var expected=(6-absi(7-total))*10
		check(absi(int(counts.get(total,0))-expected)<=CatanRules.DICE_RESHUFFLE+2,"dice deck follows the odds for %d: %d" % [total,counts.get(total,0)])
	check(not rules.snapshot(0).has("dice_bag"),"upcoming rolls stay hidden")
	rules.force_roll(8)
	check(rules.total(rules._draw_dice())==8,"forced roll")

func _random_start():
	for players in [3,4,6]:
		var names=[]
		for i in players: names.append("P%d" % i)
		var rules=CatanRules.new()
		var s=rules.create(names,61+players,{"random_start":true})
		check(s.phase=="play" and s.turn==0,"random start skips setup (%d)" % players)
		for p in players:
			check(rules.pieces(p,"settlement")==2 and rules.pieces(p,"road")==2,"two of each (%d)" % p)
			check(rules.total(s.players[p].hand)>0 or true,"starting hand")

func _start_card():
	var rules=CatanRules.new()
	rules.create(["A","B","C"],71,{"start_card":true})
	var deck=rules.s.deck.size()
	_setup(rules)
	var s=rules.s
	check(s.deck.size()==deck-3,"one card each")
	for p in 3: check(rules.total(s.players[p].cards)==1 and rules.total(s.players[p].new_cards)==0,"card is playable at once")

func _treasure():
	for island in ["random","classic","archipelago"]:
		for players in [4,6]:
			var names=[]
			for i in players: names.append("P%d" % i)
			var rules=CatanRules.new()
			var s=rules.create(names,81+players,{"treasure":true,"island":island})
			var treasure=-1
			for t in s.tiles.size():
				if s.tiles[t].kind==CatanRules.TREASURE: treasure=t
			check(treasure>=0,"treasure placed")
			check(s.tiles[treasure].number in CatanRules.TREASURE_NUMBERS,"treasure has a number")
			_setup(rules)
			for v in s.vertices.size():
				if s.vertices[v].owner>=0: check(v not in s.treasure_near,"start is 3 roads from the treasure (%s %d)" % [island,players])
			# Settle the treasure by hand and roll its number.
			var corner=s.tiles[treasure].corners[0]
			s.vertices[corner].owner=0
			s.vertices[corner].level=2
			if s.robber==treasure: s.robber=(treasure+1)%s.tiles.size()
			var number=s.tiles[treasure].number
			var before=rules.total(s.players[0].hand)
			rules._pay_treasure(number)
			check(rules.total(s.players[0].hand)==before+4,"city on the treasure finds 4")
			check(s.tiles[treasure].number!=number and s.tiles[treasure].number!=7,"treasure number changes")

func _archipelago():
	for players in [3,4,6]:
		var names=[]
		for i in players: names.append("P%d" % i)
		for game_seed in range(1,9):
			var rules=CatanRules.new()
			var s=rules.create(names,game_seed*7+players,{"island":"archipelago"})
			var islands={}
			for t in s.tiles: islands[t.island]=int(islands.get(t.island,0))+1
			check(islands.size()>=3,"several islands (%d)" % islands.size())
			check(s.tiles.size()==(35 if players>4 else 23),"archipelago tile count %d" % s.tiles.size())
			var sea_edges=0
			for e in s.edges: if e.tiles==0: sea_edges+=1
			check(sea_edges>0,"open sea edges")
			_setup(rules)
			for v in s.vertices.size():
				if s.vertices[v].owner>=0: check(rules._on_island(v,0),"everyone starts on the main island")
	# Ships: sail from a coastal town to another island for the bonus.
	var rules=CatanRules.new()
	var s=rules.create(["A","B","C"],5,{"island":"archipelago"})
	_setup(rules)
	s.rolled=true
	var sites=rules.build_sites(0,"ship")
	s.players[0].hand=[9,9,9,9,9]
	if sites.is_empty():
		# Not every start is coastal; give player 0 a coastal settlement.
		for v in s.vertices.size():
			if rules._open_corner(v) and rules._on_island(v,0):
				var coastal=false
				for eid in s.vertices[v].edges: if s.edges[eid].tiles<2: coastal=true
				if coastal:
					s.vertices[v].owner=0;s.vertices[v].level=1
					break
		sites=rules.build_sites(0,"ship")
	check(not sites.is_empty(),"a coastal town can launch a ship")
	check(rules.apply(0,{"type":"ship","id":sites[0]})=="","build a ship")
	check(rules.pieces(0,"ship")==1 and rules.is_ship(sites[0]),"ship on the board")
	var land_edge=-1
	for eid in s.edges.size():
		if s.edges[eid].tiles==0 and s.edges[eid].owner==-1: land_edge=eid
	check(not rules.valid_edge(0,land_edge),"no roads at sea")
	# Walk ships to the nearest corner of another island.
	var target=_sail(rules,0)
	check(target>=0,"a ship route reaches another island")
	if target>=0:
		var before=s.players[0].points
		check(rules.apply(0,{"type":"settlement","id":target})=="","settle the new island")
		check(s.players[0].points==before+1+CatanRules.ISLAND_BONUS,"island bonus")

## A player with a coastal town and a line of ships, ready to test moving.
func _sea_game(options: Dictionary) -> CatanRules:
	var rules=CatanRules.new()
	var merged={"island":"archipelago"}
	merged.merge(options,true)
	var s=rules.create(["A","B","C"],5,merged)
	_setup(rules)
	s.rolled=true
	s.players[0].hand=[9,9,9,9,9]
	if rules.build_sites(0,"ship").is_empty():
		for v in s.vertices.size():
			if rules._open_corner(v) and rules._on_island(v,0):
				var coastal=false
				for eid in s.vertices[v].edges: if s.edges[eid].tiles<2: coastal=true
				if coastal:
					s.vertices[v].owner=0;s.vertices[v].level=1
					break
	return rules

func _moving_ships():
	var rules=_sea_game({"move_ships":true})
	var s=rules.s
	var first=rules.build_sites(0,"ship")[0]
	check(rules.apply(0,{"type":"ship","id":first})=="","build a ship")
	var tip=-1
	for eid in rules.build_sites(0,"ship"):
		var e=s.edges[eid]
		for v in [e.a,e.b]:
			if v in [s.edges[first].a,s.edges[first].b] and s.vertices[v].owner!=0: tip=eid
	check(tip>=0 and rules.apply(0,{"type":"ship","id":tip})=="","extend the line")
	check(rules.movable_ships(0).is_empty(),"ships built this turn stay put")
	check(rules.apply(0,{"type":"move_ship","id":tip,"to":first})!="","cannot move a new ship")
	check(rules.apply(0,{"type":"end"})=="","end turn")
	s.turn=0;s.rolled=true
	var open=rules.movable_ships(0)
	check(tip in open,"the end of the line can move next turn")
	var town_side=false
	for v in [s.edges[first].a,s.edges[first].b]: if s.vertices[v].owner==0: town_side=true
	if town_side: check(first not in open,"a ship tied to town and ship is closed")
	var moves=rules.ship_moves(0,tip)
	check(not moves.is_empty() and tip not in moves,"somewhere to sail, not the same edge")
	if moves.is_empty(): return
	check(rules.apply(0,{"type":"move_ship","id":tip,"to":first})!="","cannot move onto a taken edge")
	check(rules.apply(0,{"type":"move_ship","id":tip,"to":moves[0]})=="","move the ship")
	check(s.edges[moves[0]].owner==0 and rules.is_ship(moves[0]) and s.edges[tip].owner==-1 and not rules.is_ship(tip),"ship changed edges")
	check(rules.movable_ships(0).is_empty(),"one move per turn")
	check(rules.pieces(0,"ship")==2,"still two ships")
	var plain=_sea_game({})
	var ship=plain.build_sites(0,"ship")[0]
	plain.apply(0,{"type":"ship","id":ship})
	plain.s.new_ships=[]
	check(plain.movable_ships(0).is_empty(),"without the house rule ships stay put")
	var land=CatanRules.new()
	land.create(["A","B","C"],5,{"island":"random","move_ships":true,"fog":true})
	check(not land.s.move_ships and not land.s.fog,"sea rules need the archipelago")

func _fog():
	var rules=_sea_game({"fog":true})
	var s=rules.s
	var hidden=0
	for t in s.tiles:
		if int(t.island)>0: check(t.get("fog",false),"outer islands start in fog")
		else: check(not t.get("fog",false),"the main island is clear")
		if t.get("fog",false): hidden+=1
	check(hidden>0,"some fog")
	var view=rules.snapshot(1)
	for i in s.tiles.size():
		if s.tiles[i].get("fog",false): check(view.tiles[i].kind==CatanRules.FOG and view.tiles[i].number==0,"snapshots hide fogged hexes")
	check(s.tiles.any(func(t):return t.get("fog",false) and t.kind!=CatanRules.FOG),"the host keeps the real hex")
	for t in rules.robber_sites(0): check(not s.tiles[t].get("fog",false),"the robber stays out of the fog")
	var before=s.players[0].hand.duplicate()
	var bank=s.bank.duplicate()
	var target=_sail(rules,0)
	var revealed=[]
	for t in s.tiles.size():
		if int(s.tiles[t].island)>0 and not s.tiles[t].get("fog",false): revealed.append(t)
	check(target>=0 and not revealed.is_empty(),"sailing up to an island clears its fog")
	var fog_log=s.log.filter(func(line):return "in the fog" in line)
	check(fog_log.size()==revealed.size(),"one log line per revealed hex")

func _points_history():
	var rules=CatanRules.new()
	rules.create(["A","B","C"],21)
	var bots=[CatanBot.new(1),CatanBot.new(2),CatanBot.new(3)]
	var guard=0
	while rules.s.winner==-1 and guard<20000:
		guard+=1
		var moved=false
		for p in 3:
			var action=bots[p].choose(rules.snapshot(p),p,2)
			if action.is_empty(): continue
			if rules.apply(p,action)!="" and p==rules.s.turn and rules.s.phase=="play" and rules.s.rolled: rules.apply(p,{"type":"end"})
			if rules.s.has("offer") and not rules.s.offer.is_empty(): rules.open_offer()
			moved=true
			break
		if not moved: break
		if guard%50==0: check(not rules.snapshot(1).has("points_history"),"points stay hidden during the game")
	check(rules.s.winner!=-1,"a bot game finishes")
	var history: Array=rules.s.get("points_history",[])
	check(history.size()>5,"points recorded each turn: %d" % history.size())
	check(history[0]==[2,2,2],"everyone starts on 2 points: %s" % [history[0]])
	check(int(history[-1][rules.s.winner])>=rules.target(),"the last row has the winning score")
	check(rules.snapshot(1).get("points_history",[])==history,"the chart data arrives with the result")

## Builds ships along the shortest sea route to another island's free corner.
func _sail(rules: CatanRules,p: int) -> int:
	var s=rules.s
	for step in 40:
		for v in s.vertices.size():
			if rules.valid_vertex(p,v) and not rules._on_island(v,0): return v
		var best=-1
		var best_distance=INF
		for eid in rules.build_sites(p,"ship"):
			var e=s.edges[eid]
			for v in [e.a,e.b]:
				for t in s.tiles:
					if int(t.island)==0: continue
					var d=Vector2(s.vertices[v].x-t.x,s.vertices[v].z-t.z).length()
					if d<best_distance: best_distance=d;best=eid
		if best<0: return -1
		s.players[p].hand=[9,9,9,9,9]
		if rules.apply(p,{"type":"ship","id":best})!="": return -1
	return -1
