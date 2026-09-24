class_name CatanBot
extends RefCounted
## Bots receive the same private snapshot as a human player, never other hands or the deck.
const LEVELS=["Easy","Normal","Hard"]
var random=RandomNumberGenerator.new()
func _init(seed_value: int=0):
	if seed_value: random.seed=seed_value
	else: random.randomize()

func choose(data: Dictionary,p: int,difficulty: int=1) -> Dictionary:
	var r=CatanRules.new()
	r.s=data
	var player=data.players[p]
	if data.winner!=-1: return {}
	if data.phase=="discard" and data.discards.has(str(p)):
		var hand=player.hand.duplicate()
		var cards=[0,0,0,0,0]
		for i in int(data.discards[str(p)]):
			var largest=0
			for res in 5:
				if hand[res]>hand[largest]: largest=res
			cards[largest]+=1
			hand[largest]-=1
		return {"type":"discard","cards":cards}
	# Every bot answers an open offer once, so the offering player is not left waiting.
	if not data.offer.is_empty() and data.offer.from!=p and not data.offer.get("responses",{}).has(str(p)):
		var incoming=r.total(data.offer.give)
		var outgoing=r.total(data.offer.receive)
		if r.can_pay(p,data.offer.receive) and incoming>=outgoing and (difficulty==0 or _trade_value(data,p,data.offer.give)>=_trade_value(data,p,data.offer.receive)):
			return {"type":"accept_trade"}
		return {"type":"decline_trade"}
	if p!=data.turn: return {}
	if data.phase=="setup_settlement":
		var candidates=[]
		for v in data.vertices.size():
			if r.valid_vertex(p,v,true): candidates.append({"id":v,"value":_site(data,p,v,difficulty)})
		return {"type":"settlement","id":_best(candidates,difficulty)}
	if data.phase=="setup_road":
		var candidates=[]
		for eid in data.vertices[data.anchor].edges:
			if r.valid_edge(p,eid,true):
				var e=data.edges[eid]
				var other=e.b if e.a==data.anchor else e.a
				var value=0.0
				for next_id in data.vertices[other].edges:
					var next=data.edges[next_id]
					var dest=next.b if next.a==other else next.a
					if r.valid_vertex(p,dest,true): value=maxf(value,_site(data,p,dest,difficulty))
				candidates.append({"id":eid,"value":value})
		return {"type":"road","id":_best(candidates,difficulty)}
	if data.phase=="robber":
		var candidates=[]
		for t in r.robber_sites(p):
			var value=0.0
			for v in data.tiles[t].corners:
				var owner=data.vertices[v].owner
				if owner>=0:
					value+=(-3.0 if owner==p else 1.0+data.players[owner].points*0.15)*data.vertices[v].level*_pips(data.tiles[t].number)
			candidates.append({"id":t,"value":value})
		return {"type":"robber","id":_best(candidates,difficulty)}
	if data.phase=="steal":
		var victim=data.victims[0]
		for other in data.victims:
			if data.players[other].points>data.players[victim].points: victim=other
		return {"type":"steal","id":victim}
	if data.phase in ["discard","steal"]: return {}
	var plan=_expansion(r,p,difficulty)
	if data.phase=="free_roads":
		var edge=_road(r,p,plan)
		return {"type":"road","id":edge} if edge>=0 and r.pieces(p,"road")<15 else {"type":"finish_roads"}
	if data.phase!="play": return {}
	if not data.rolled: return {"type":"roll"}
	var settlements=[]
	var cities=[]
	for v in data.vertices.size():
		if r.valid_vertex(p,v): settlements.append({"id":v,"value":_site(data,p,v,difficulty)})
		if data.vertices[v].owner==p and data.vertices[v].level==1: cities.append({"id":v,"value":_site(data,p,v,difficulty)})
	if not cities.is_empty() and r.pieces(p,"city")<4 and r.can_pay(p,CatanRules.COST.city):
		return {"type":"city","id":_best(cities,difficulty)}
	if not settlements.is_empty() and r.pieces(p,"settlement")<5 and r.can_pay(p,CatanRules.COST.settlement):
		return {"type":"settlement","id":_best(settlements,difficulty)}
	var goal="settlement" if not settlements.is_empty() and r.pieces(p,"settlement")<5 else "road"
	if (not cities.is_empty() and (r.pieces(p,"settlement")>=4 or player.hand[4]>=2 or plan.is_empty())): goal="city"
	if r.pieces(p,"road")>=15 or plan.is_empty(): goal="city" if not cities.is_empty() and r.pieces(p,"city")<4 else "buy_card"
	var cost=CatanRules.COST[goal]
	if not data.card_played:
		if player.cards[0]>0: return {"type":"play_card","id":0}
		if player.cards[1]>0 and r.pieces(p,"road")<15 and _road(r,p,plan)>=0: return {"type":"play_card","id":1}
		if player.cards[2]>0:
			var available=data.bank.duplicate()
			var hand=player.hand.duplicate()
			var picked=[0,0,0,0,0]
			for i in 2:
				var best=-1
				var value=-INF
				for res in 5:
					if available[res]>0:
						var score=float(cost[res]-hand[res])*4.0+1.0/(1.0+hand[res])
						if score>value: best=res; value=score
				if best<0: break
				picked[best]+=1
				hand[best]+=1
				available[best]-=1
			if r.total(picked)==2: return {"type":"play_card","id":2,"cards":picked}
		if player.cards[3]>0:
			var resource=0
			var highest=-INF
			for res in 5:
				var production=0.0
				for v in data.vertices:
					if v.owner>=0 and v.owner!=p:
						for t in v.tiles:
							if data.tiles[t].kind==res: production+=_pips(data.tiles[t].number)*v.level
				var value=production+maxi(0,cost[res]-player.hand[res])*2
				if value>highest: highest=value; resource=res
			return {"type":"play_card","id":3,"resource":resource}
	if goal=="road" and r.can_pay(p,CatanRules.COST.road):
		var edge=_road(r,p,plan)
		if edge>=0 and r.pieces(p,"road")<15: return {"type":"road","id":edge}
	if r.can_pay(p,CatanRules.COST.buy_card) and int(data.get("deck_count",0))>0 and (goal=="buy_card" or r.total(player.hand)>8 or player.points>=7): return {"type":"buy_card"}
	# Turn surplus into precisely what the next build needs. Easy bots trade less often.
	if difficulty>0 or random.randf()<0.5:
		for receive in 5:
			if player.hand[receive]>=cost[receive] or data.bank[receive]<1: continue
			var give=-1
			var surplus=-1
			for res in 5:
				if res==receive: continue
				var extra=player.hand[res]-cost[res]
				if extra>=r.rate(p,res) and extra>surplus: give=res; surplus=extra
			if give>=0: return {"type":"bank_trade","give":give,"receive":receive}
	if r.can_pay(p,CatanRules.COST.buy_card) and int(data.get("deck_count",0))>0: return {"type":"buy_card"}
	return {"type":"end"}

func _pips(number: int) -> int:
	return maxi(0,6-absi(7-number)) if number>0 else 0

func _site(data: Dictionary,p: int,v: int,difficulty: int) -> float:
	var income=[0,0,0,0,0]
	for owned in data.vertices:
		if owned.owner==p:
			for t in owned.tiles:
				if data.tiles[t].kind<5: income[data.tiles[t].kind]+=_pips(data.tiles[t].number)*owned.level
	var value=0.0
	var types={}
	for t in data.vertices[v].tiles:
		var tile=data.tiles[t]
		if tile.kind==5: continue
		var weight=1.0
		if difficulty==2: weight=1.0+2.5/(1.0+income[tile.kind])
		value+=_pips(tile.number)*weight
		types[tile.kind]=true
	if difficulty==2:
		value+=types.size()*1.4
		if data.vertices[v].port!=-2: value+=1.5
	return value

func _best(candidates: Array,difficulty: int) -> int:
	if candidates.is_empty(): return -1
	if difficulty==0: return candidates[random.randi_range(0,candidates.size()-1)].id
	candidates.sort_custom(func(a,b):return a.value>b.value)
	return candidates[0].id

func _expansion(r: CatanRules,p: int,difficulty: int) -> Array:
	var data=r.s
	var distances={}
	var paths={}
	var open=[]
	for v in data.vertices.size():
		if data.vertices[v].owner==p:
			distances[v]=0
			paths[v]=[]
			open.append(v)
	var visited={}
	while not open.is_empty():
		open.sort_custom(func(a,b):return distances[a]<distances[b])
		var v=open.pop_front()
		if visited.has(v): continue
		visited[v]=true
		if data.vertices[v].owner>=0 and data.vertices[v].owner!=p: continue
		for eid in data.vertices[v].edges:
			var edge=data.edges[eid]
			if edge.owner>=0 and edge.owner!=p: continue
			var other=edge.b if edge.a==v else edge.a
			var distance=distances[v]+(0 if edge.owner==p else 1)
			if distance<int(distances.get(other,999)):
				distances[other]=distance
				paths[other]=paths[v].duplicate()
				if edge.owner==-1: paths[other].append(eid)
				open.append(other)
	var best=[]
	var value=-INF
	for v in distances:
		if not r.valid_vertex(p,v,true) or paths[v].is_empty(): continue
		var score=_site(data,p,v,difficulty)/pow(float(distances[v])+0.5,1.6)
		if difficulty==0: score+=random.randf()*5
		if score>value: value=score; best=paths[v]
	return best

func _road(r: CatanRules,p: int,plan: Array) -> int:
	for edge in plan:
		if r.valid_edge(p,edge): return edge
	for edge in r.s.edges.size():
		if r.valid_edge(p,edge): return edge
	return -1

func _trade_value(data: Dictionary,p: int,resources: Array) -> float:
	var value=0.0
	for res in 5: value+=float(resources[res])*(1.0+2.0/(data.players[p].hand[res]+1.0))
	return value
