extends SceneTree
var failures=0
var checks=0
func check(ok: bool, message: String):
	checks+=1
	if not ok: failures+=1; printerr("FAIL: ",message)
func _initialize(): call_deferred("run")
func run():
	for count in [5,6]:
		for seed_value in 20:
			var r=CatanRules.new()
			r.create(["A","B","C","D","E","F"].slice(0,count),seed_value+1)
			check(r.s.tiles.size()==30 and r.s.vertices.size()==80 and r.s.edges.size()==109,"extension topology")
			var kinds=[0,0,0,0,0,0]
			var numbers={}
			for tile in r.s.tiles:
				kinds[tile.kind]+=1
				numbers[tile.number]=numbers.get(tile.number,0)+1
			check(kinds==[6,5,6,6,5,2],"terrain inventory")
			check(numbers=={0:2,2:2,3:3,4:3,5:3,6:3,8:3,9:3,10:3,11:3,12:2},"number inventory")
			check(r.s.bank==[24,24,24,24,24],"24 resources each")
			check(r.s.deck.size()==34 and r.s.deck.count(0)==20 and r.s.deck.count(4)==5 and r.s.deck.count(1)==3,"development inventory")
			var ports=[0,0,0,0,0,0]
			for v in r.s.vertices:
				if v.port!=-2: ports[v.port+1]+=1
			check(ports==[10,2,2,4,2,2],"eleven nonoverlapping ports")
			for e in r.s.edges:
				var common=[]
				for t in r.s.vertices[e.a].tiles:
					if t in r.s.vertices[e.b].tiles: common.append(t)
				if common.size()==2: check(not (r.s.tiles[common[0]].number in [6,8] and r.s.tiles[common[1]].number in [6,8]),"red tokens separated")
		var r=CatanRules.new()
		r.create(["A","B","C","D","E","F"].slice(0,count),125)
		r.s.phase="play"
		r.s.rolled=true
		r.s.players[0].new_cards=[1,0,0,0,0]
		check(r.apply(0,{"type":"end"})=="" and r.s.turn==3 and r.s.paired and r.s.rolled,"primary hands off three seats ahead")
		check(r.s.players[0].cards[0]==1,"new cards become available next portion")
		check(not r.apply(3,{"type":"roll"}).is_empty(),"paired cannot roll")
		r.s.players[3].hand=[4,0,0,0,0]
		check(not r.apply(3,{"type":"offer_trade","give":[1,0,0,0,0],"receive":[0,1,0,0,0]}).is_empty(),"paired cannot offer domestic trade")
		check(r.apply(3,{"type":"bank_trade","give":0,"receive":1})=="","paired can bank trade")
		r.s.players[3].cards[0]=1
		check(r.apply(3,{"type":"play_card","id":0})=="","paired can play knight")
		check(r.apply(3,{"type":"robber","id":29 if r.s.robber!=29 else 28})=="","robber accepts extension hex")
		check(not r.apply(3,{"type":"play_card","id":0}).is_empty(),"one card per portion")
		check(r.apply(3,{"type":"end"})=="" and r.s.turn==1 and not r.s.paired and not r.s.rolled and not r.s.card_played,"next primary receives dice")
		r.s.rolled=true
		r.s.players[4].cards[4]=10
		check(r.apply(1,{"type":"end"})=="" and r.s.winner==4,"paired player can win on entry")
		var win=CatanRules.new()
		win.create(["A","B","C","D","E","F"].slice(0,count),125)
		win.s.phase="play"
		win.s.rolled=true
		win.s.players[0].cards[4]=10
		win.s.players[3].cards[4]=10
		check(win.apply(0,{"type":"end"})=="" and win.s.winner==0,"primary wins before paired player")
		var city=CatanRules.new()
		city.create(["A","B","C","D","E","F"].slice(0,count),125)
		city.s.phase="play"
		city.s.rolled=true
		city.s.vertices[79].owner=0
		city.s.vertices[79].level=1
		city.s.players[0].hand=[0,0,0,2,3]
		check(city.apply(0,{"type":"city","id":79})=="","city accepts extension vertex")
		check(city._resource_array([24,0,0,0,0]) and not city._resource_array([25,0,0,0,0]),"resource validation supports extension bank")
	print("EXTENSION_TEST: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
