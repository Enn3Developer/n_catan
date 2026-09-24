class_name CatanRules
extends RefCounted

const RES = ["Timber", "Brick", "Wool", "Grain", "Ore"]
const COST = {"road": [1,1,0,0,0], "settlement": [1,1,1,1,0], "city": [0,0,0,2,3], "buy_card": [0,0,1,1,1]}
var s: Dictionary = {}
var rng = RandomNumberGenerator.new()

const ISLANDS=["random","classic"]
const TURN_TIMERS=[0,30,45,60,90,120,180]
const POINT_TARGETS=[5,15]
const DEFAULT_OPTIONS={"island":"random","points":10,"friendly_robber":false}
const LOG_LIMIT=5000
## Unshifted center distance of the classic island's outer tile rim.
const CLASSIC_EXTENT=4.4641
const AXIAL=[Vector2i(1,0),Vector2i(1,-1),Vector2i(0,-1),Vector2i(-1,0),Vector2i(-1,1),Vector2i(0,1)]

func create(names: Array, game_seed: int = 0, options: Dictionary = {}) -> Dictionary:
	var extended=names.size()>4
	var settings=DEFAULT_OPTIONS.duplicate()
	settings.merge(options,true)
	if game_seed==0: game_seed=int(Time.get_unix_time_from_system())
	rng.seed = game_seed
	s = {"tiles": [], "vertices": [], "edges": [], "players": [], "turn": 0, "phase": "setup_settlement", "setup": 0, "anchor": -1, "rolled": false, "dice": [0,0], "robber": 0, "bank": [19,19,19,19,19], "deck": [], "log": [], "winner": -1, "longest": -1, "army": -1, "discards": {}, "victims": [], "offer": {}, "free_roads": 0, "card_played": false}
	s.extension=extended
	s.primary=0
	s.paired=false
	s.seed=game_seed
	s.island=str(settings.island) if str(settings.island) in ISLANDS else "random"
	s.points_target=clampi(int(settings.points),POINT_TARGETS[0],POINT_TARGETS[1])
	s.friendly_robber=bool(settings.friendly_robber)
	s.dice_counts=[0,0,0,0,0,0,0,0,0,0,0]
	s.resource_limit=24 if extended else 19
	if extended: s.bank=[24,24,24,24,24]
	var terrain = [0,0,0,0,1,1,1,2,2,2,2,3,3,3,3,4,4,4,5]
	if extended: terrain.append_array([0,0,1,1,2,2,3,3,4,4,5])
	_shuffle(terrain)
	var numbers = [5,2,6,3,8,10,9,12,11,4,8,10,9,4,5,6,3,11]
	if extended: numbers=[2,2,3,3,3,4,4,4,5,5,5,6,6,6,8,8,8,9,9,9,10,10,10,11,11,11,12,12]
	_shuffle(numbers)
	var centers=_island_centers(terrain.size(),extended) if s.island=="random" else _classic_centers(extended)
	var keys = {}
	var edge_keys = {}
	var n = 0
	for center in centers:
		var tid = s.tiles.size()
		var kind = terrain[tid]
		var tile = {"x":center.x,"z":center.y,"kind":kind,"number":0,"corners":[]}
		if kind != 5:
			tile.number=numbers[n]
			n+=1
		else: s.robber=tid
		for c in 6:
			var a=deg_to_rad(30+60*c)
			var p=center+Vector2(cos(a),sin(a))
			var key="%d,%d" % [roundi(p.x*100),roundi(p.y*100)]
			if not keys.has(key):
				keys[key]=s.vertices.size()
				s.vertices.append({"x":p.x,"z":p.y,"owner":-1,"level":0,"tiles":[],"edges":[],"port":-2})
			var v=keys[key]
			tile.corners.append(v)
			s.vertices[v].tiles.append(tid)
		for c in 6:
			var a=int(tile.corners[c])
			var b=int(tile.corners[(c+1)%6])
			var key="%d:%d" % [mini(a,b),maxi(a,b)]
			if not edge_keys.has(key):
				edge_keys[key]=s.edges.size()
				var eid=s.edges.size()
				s.edges.append({"a":a,"b":b,"owner":-1,"tiles":0})
				s.vertices[a].edges.append(eid)
				s.vertices[b].edges.append(eid)
			s.edges[edge_keys[key]].tiles+=1
		s.tiles.append(tile)
	# Keys are built before centering so shared corners round identically.
	var middle=Vector2.ZERO
	for center in centers: middle+=center
	middle/=centers.size()
	for item in s.tiles+s.vertices:
		item.x-=middle.x
		item.z-=middle.y
	# Keep high-probability tokens apart.
	for attempt in 500:
		var valid=true
		for e in s.edges:
			var common=[]
			for t in s.vertices[e.a].tiles:
				if t in s.vertices[e.b].tiles: common.append(t)
			if common.size()==2 and s.tiles[common[0]].number in [6,8] and s.tiles[common[1]].number in [6,8]: valid=false
		if valid: break
		_shuffle(numbers)
		n=0
		for t in s.tiles:
			if t.kind!=5:
				t.number=numbers[n]
				n+=1
	var ports=[-1,0,-1,1,2,-1,3,4,-1]
	if extended: ports.append_array([2,-1])
	_shuffle(ports)
	_place_ports(ports)
	for pname in names:
		s.players.append({"name":str(pname).substr(0,20),"hand":[0,0,0,0,0],"cards":[0,0,0,0,0],"new_cards":[0,0,0,0,0],"knights":0,"points":0,"road_length":0,"stats":{"rolls":0,"produced":[0,0,0,0,0],"stolen":0,"lost":0,"discarded":0,"trades":0,"bank_trades":0,"cards_played":0}})
	for i in (20 if extended else 14): s.deck.append(0)
	for i in 5: s.deck.append(4)
	for i in (3 if extended else 2): s.deck.append_array([1,2,3])
	_shuffle(s.deck)
	_log("The island awaits. Place your first settlement.")
	return s

## The original hexagon, or the six-player board with its offset rows.
func _classic_centers(extended: bool) -> Array:
	var centers=[]
	var radius=3 if extended else 2
	for q in range(-radius,radius+1):
		for r in range(-radius,radius+1):
			if abs(q+r)>radius: continue
			if extended and q==mini(radius,radius-r): continue
			centers.append(Vector2(sqrt(3.0)*(q+r*0.5+(0.5 if extended else 0.0)),1.5*r))
	return centers

## Grows a seeded island one hex at a time. A hex with more land around it is
## likelier to join, which keeps the coast ragged without long thin spits, and
## shapes that enclose a lagoon are thrown back.
func _island_centers(count: int,extended: bool) -> Array:
	var reach=4 if extended else 3
	for attempt in 40:
		var land={Vector2i.ZERO:true}
		while land.size()<count:
			var frontier={}
			for hex in land:
				for step in AXIAL:
					var next: Vector2i=hex+step
					if land.has(next) or _ring(next)>reach: continue
					frontier[next]=0
			var choices=[]
			var total_weight=0.0
			for hex in frontier:
				var around=0
				for step in AXIAL:
					if land.has(hex+step): around+=1
				var weight=pow(float(around),2.2)*(0.55 if _ring(hex)==reach else 1.0)
				choices.append([hex,weight])
				total_weight+=weight
			var pick=rng.randf()*total_weight
			for choice in choices:
				pick-=choice[1]
				if pick<=0.0 or choice==choices[-1]:
					land[choice[0]]=true
					break
		if _has_lagoon(land,reach): continue
		var hexes=land.keys()
		hexes.sort_custom(func(a,b): return a.y<b.y or (a.y==b.y and a.x<b.x))
		var centers=[]
		for hex in hexes: centers.append(Vector2(sqrt(3.0)*(hex.x+hex.y*0.5),1.5*hex.y))
		return centers
	return _classic_centers(extended)

func _ring(hex: Vector2i) -> int:
	return maxi(absi(hex.x),maxi(absi(hex.y),absi(hex.x+hex.y)))

func _has_lagoon(land: Dictionary,reach: int) -> bool:
	var edge=reach+1
	var start=Vector2i(edge,0)
	var sea={start:true}
	var queue=[start]
	while not queue.is_empty():
		var hex: Vector2i=queue.pop_back()
		for step in AXIAL:
			var next: Vector2i=hex+step
			if _ring(next)>edge or land.has(next) or sea.has(next): continue
			sea[next]=true
			queue.append(next)
	for q in range(-edge,edge+1):
		for r in range(-edge,edge+1):
			var hex=Vector2i(q,r)
			if _ring(hex)<=edge and not land.has(hex) and not sea.has(hex): return true
	return false

## Spreads the harbors evenly around the coast, starting at a seeded point.
## Edges that face a narrow bay are skipped so the moored boat has open water.
func _place_ports(ports: Array):
	var coast=_coast_loop()
	if coast.is_empty(): return
	var start=rng.randi_range(0,coast.size()-1)
	for i in ports.size():
		var slot=start+int(i*float(coast.size())/ports.size())
		for offset in [0,1,-1,2,-2,3,-3]:
			var e=s.edges[coast[posmod(slot+offset,coast.size())]]
			if s.vertices[e.a].port!=-2 or s.vertices[e.b].port!=-2 or not _open_water(e): continue
			s.vertices[e.a].port=ports[i]
			s.vertices[e.b].port=ports[i]
			break

## Coast edges in order around the island. Without lagoons they form one loop.
func _coast_loop() -> Array:
	var by_vertex={}
	var first=-1
	for i in s.edges.size():
		if s.edges[i].tiles!=1: continue
		if first<0: first=i
		for v in [s.edges[i].a,s.edges[i].b]:
			if not by_vertex.has(v): by_vertex[v]=[]
			by_vertex[v].append(i)
	var loop=[]
	var edge=first
	var vertex=s.edges[first].b if first>=0 else -1
	while edge>=0 and loop.size()<=s.edges.size():
		loop.append(edge)
		var next=-1
		for candidate in by_vertex.get(vertex,[]):
			if candidate!=edge: next=candidate
		if next<0 or next==first: break
		var e=s.edges[next]
		vertex=e.b if e.a==vertex else e.a
		edge=next
	return loop

func _open_water(e: Dictionary) -> bool:
	var a=s.vertices[e.a]
	var b=s.vertices[e.b]
	var owner={}
	for t in a.tiles:
		if t in b.tiles: owner=s.tiles[t]
	# The sea hex across the edge mirrors the tile that owns it.
	var sea=Vector2(a.x+b.x-owner.x,a.z+b.z-owner.z)
	var neighbors=0
	for t in s.tiles:
		if sea.distance_to(Vector2(t.x,t.z))<1.9: neighbors+=1
	return neighbors<=2

## Scale the scenery ring (rocks, lighthouse, mainland) needs to clear this island.
static func island_scale(data: Dictionary) -> float:
	var extent=0.0
	for t in data.get("tiles",[]): extent=maxf(extent,Vector2(t.x,t.z).length()+1.0)
	return maxf(1.32 if data.get("extension",false) else 1.0,extent/CLASSIC_EXTENT)

func _shuffle(a: Array):
	for i in range(a.size()-1,0,-1):
		var j=rng.randi_range(0,i)
		var x=a[i]
		a[i]=a[j]
		a[j]=x

func _trade_event(kind: String,actor: int,other: int=-1):
	var previous=s.get("trade_event",{})
	s.trade_event={"id":int(previous.get("id",0))+1,"kind":kind,"actor":actor,"other":other}

func _log(message: String):
	s.log.append(message)
	if s.log.size()>LOG_LIMIT: s.log.pop_front()

func total(hand: Array) -> int:
	var count=0
	for x in hand: count+=int(x)
	return count

func can_pay(p: int, cost: Array) -> bool:
	for r in 5:
		if s.players[p].hand[r]<cost[r]: return false
	return true

func pay(p: int,cost: Array):
	for r in 5:
		s.players[p].hand[r]-=cost[r]
		s.bank[r]+=cost[r]

func valid_vertex(p: int,v: int,setup: bool=false) -> bool:
	if v<0 or v>=s.vertices.size() or s.vertices[v].owner!=-1: return false
	for eid in s.vertices[v].edges:
		var e=s.edges[eid]
		if s.vertices[e.b if e.a==v else e.a].owner!=-1: return false
	if setup: return true
	for eid in s.vertices[v].edges:
		if s.edges[eid].owner==p: return true
	return false

func valid_edge(p: int,eid: int,setup: bool=false) -> bool:
	if eid<0 or eid>=s.edges.size() or s.edges[eid].owner!=-1: return false
	var e=s.edges[eid]
	if setup: return s.anchor in [e.a,e.b]
	for v in [e.a,e.b]:
		if s.vertices[v].owner==p: return true
		if s.vertices[v].owner!=-1: continue
		for adjacent in s.vertices[v].edges:
			if s.edges[adjacent].owner==p: return true
	return false

func pieces(p: int,kind: String) -> int:
	var count=0
	if kind=="road":
		for e in s.edges:
			if e.owner==p: count+=1
	else:
		for v in s.vertices:
			if v.owner==p and v.level==(1 if kind=="settlement" else 2): count+=1
	return count

# Shared by the HUD and placement flow; affordability alone is not enough.
func build_sites(p: int,kind: String) -> Array:
	var result=[]
	if p<0 or p>=s.players.size(): return result
	if pieces(p,kind)>={"road":15,"settlement":5,"city":4}.get(kind,0): return result
	if kind=="road":
		for e in s.edges.size():
			if valid_edge(p,e): result.append(e)
	else:
		for v in s.vertices.size():
			if kind=="settlement" and valid_vertex(p,v): result.append(v)
			elif kind=="city" and s.vertices[v].owner==p and s.vertices[v].level==1: result.append(v)
	return result

func visible_points(p: int) -> int:
	var player=s.players[p]
	return int(player.points)+(int(player.cards[4])+int(player.new_cards[4]) if player.cards.size()==5 else 0)

func rate(p: int,r: int) -> int:
	var result=4
	for v in s.vertices:
		if v.owner==p:
			if v.port==-1: result=mini(result,3)
			if v.port==r: result=2
	return result

func apply(p: int,a: Dictionary) -> String:
	if p<0 or p>=s.players.size(): return "Your seat is unavailable. Please reconnect to the game."
	if s.winner!=-1: return "The game has finished."
	var action=str(a.get("type",""))
	var id=int(a.get("id",-1))
	if action=="discard":
		if s.phase!="discard" or not s.discards.has(str(p)): return "You do not need to discard any resources."
		var cards=a.get("cards",[])
		if not _resource_array(cards) or total(cards)!=int(s.discards[str(p)]): return CatanI18n.message("Choose exactly %d resources to discard.",[int(s.discards[str(p)])])
		if not can_pay(p,cards): return "You can only discard resources you have."
		pay(p,cards)
		_stat(p,"discarded",total(cards))
		_log(CatanI18n.message("%s discarded %d resources.",[s.players[p].name,total(cards)]))
		s.discards.erase(str(p))
		if s.discards.is_empty(): s.phase="robber"
		return ""
	if action in ["accept_trade","decline_trade","counter_trade"]: return _respond(p,action,a)
	if p!=s.turn: return "It is another player’s turn. You can act when yours begins."
	var player=s.players[p]
	if action=="cancel_trade":
		if not s.offer.is_empty():_trade_event("withdrawn",p)
		s.offer={}
		return ""
	if s.phase=="setup_settlement":
		if action!="settlement" or not valid_vertex(p,id,true): return "Choose an empty corner at least two edges from another settlement."
		s.vertices[id].owner=p
		s.vertices[id].level=1
		s.anchor=id
		if s.setup>=s.players.size():
			for t in s.vertices[id].tiles:
				var r=s.tiles[t].kind
				if r<5 and s.bank[r]>0:
					player.hand[r]+=1
					s.bank[r]-=1
		s.phase="setup_road"
	elif s.phase=="setup_road":
		if action!="road" or not valid_edge(p,id,true): return "Place a road beside your new settlement."
		s.edges[id].owner=p
		s.setup+=1
		var count=s.players.size()
		if s.setup==2*count:
			s.turn=0
			s.phase="play"
			_log("All settlements placed. Roll the dice to begin.")
		else:
			s.turn=s.setup if s.setup<count else 2*count-1-s.setup
			s.phase="setup_settlement"
	elif s.phase=="discard": return "Wait for all players to discard."
	elif s.phase=="robber":
		if action!="robber" or id<0 or id>=s.tiles.size() or id==s.robber: return "Move the robber to a different hex."
		if id not in robber_sites(p): return "The friendly robber spares players with 2 points or fewer. Choose another hex."
		s.robber=id
		_log(CatanI18n.message("%s moved the robber.",[player.name]))
		s.victims=[]
		for v in s.tiles[id].corners:
			var owner=s.vertices[v].owner
			if owner>=0 and owner!=p and total(s.players[owner].hand)>0 and owner not in s.victims: s.victims.append(owner)
		if s.victims.is_empty(): s.phase="play"
		else: s.phase="steal"
	elif s.phase=="steal":
		if action!="steal" or id not in s.victims: return "Choose a neighboring player to steal from."
		var bag=[]
		for r in 5:
			for j in s.players[id].hand[r]: bag.append(r)
		var r=bag[rng.randi_range(0,bag.size()-1)]
		s.players[id].hand[r]-=1
		player.hand[r]+=1
		_stat(p,"stolen",1)
		_stat(id,"lost",1)
		s.phase="play"
		_log(CatanI18n.message("%s stole a resource from %s.",[player.name,s.players[id].name]))
	elif s.phase=="free_roads":
		if action=="finish_roads":
			s.free_roads=0
			s.phase="play"
		elif action=="road" and valid_edge(p,id) and pieces(p,"road")<15:
			s.edges[id].owner=p
			s.free_roads-=1
			if s.free_roads==0 or pieces(p,"road")==15: s.phase="play"
		else: return "Choose a connected road, or finish building."
	elif s.phase=="play":
		if action=="roll":
			if s.rolled: return "You already rolled this turn."
			s.rolled=true
			s.dice=[rng.randi_range(1,6),rng.randi_range(1,6)]
			var roll=total(s.dice)
			_stat(p,"rolls",1)
			if s.has("dice_counts"): s.dice_counts[roll-2]+=1
			_log(CatanI18n.message("%s rolled %d.",[player.name,roll]))
			if roll==7:
				for i in s.players.size():
					var count=total(s.players[i].hand)
					if count>7: s.discards[str(i)]=floori(count/2.0)
				s.phase="discard" if not s.discards.is_empty() else "robber"
			else: produce(roll)
		elif action=="play_card":
			var card=id
			if card<0 or card>3: return "Choose a development card to play. Victory point cards count automatically."
			if s.card_played: return "You have played a development card this turn. You can play another next turn."
			if player.cards[card]<1:
				if player.new_cards[card]>0: return "You bought this card this turn. You can play it on your next turn."
				return "You do not have this development card."
			if card==1 and pieces(p,"road")>=15: return "All 15 of your roads are on the board. You have none left to place."
			if card==2:
				var selected=a.get("cards",[])
				if not _resource_array(selected) or total(selected)!=2: return "Choose two resources."
				for r in 5:
					if s.bank[r]<selected[r]: return CatanI18n.message("The bank has only %d %s. Choose a different resource.",[s.bank[r],CatanI18n.term(RES[r])])
				for r in 5:
					s.bank[r]-=selected[r]
					player.hand[r]+=selected[r]
			if card==3:
				var r=int(a.get("resource",-1))
				if r<0 or r>=5: return "Choose a resource."
				for i in s.players.size():
					if i!=p:
						player.hand[r]+=s.players[i].hand[r]
						s.players[i].hand[r]=0
			player.cards[card]-=1
			s.card_played=true
			_stat(p,"cards_played",1)
			if card==0:
				player.knights+=1
				s.phase="robber"
			if card==1:
				s.free_roads=2
				s.phase="free_roads"
			_log(CatanI18n.message("%s played a development card.",[player.name]))
		else:
			if not s.rolled: return "Roll the dice first."
			if action in COST:
				if not can_pay(p,COST[action]): return cost_error(p,action)
				if action=="road":
					if pieces(p,"road")>=15: return "All 15 of your roads are on the board. You have none left to place."
					if not valid_edge(p,id): return "Choose an empty edge connected to your road or building. Another player’s building blocks the route."
					s.edges[id].owner=p
				elif action=="settlement":
					if pieces(p,"settlement")>=5: return "All 5 of your settlements are on the board. Upgrade one to a city to free a settlement piece."
					if not valid_vertex(p,id): return "Choose an empty corner on your road, at least two edges from every settlement or city."
					s.vertices[id].owner=p
					s.vertices[id].level=1
				elif action=="city":
					if pieces(p,"city")>=4: return "All 4 of your cities are on the board. You have none left to place."
					if id<0 or id>=s.vertices.size() or s.vertices[id].owner!=p or s.vertices[id].level!=1: return "Choose one of your settlements to upgrade to a city."
					s.vertices[id].level=2
				else:
					if s.deck.is_empty(): return "No development cards remain."
					player.new_cards[s.deck.pop_back()]+=1
				pay(p,COST[action])
				_log(CatanI18n.message("%s: %s.",[player.name,CatanI18n.term(action.replace("_"," "))]))
			elif action=="bank_trade":
				var give=int(a.get("give",-1))
				var receive=int(a.get("receive",-1))
				if give<0 or give>4 or receive<0 or receive>4 or give==receive: return "Choose two different resources."
				var amount=rate(p,give)
				if player.hand[give]<amount: return CatanI18n.message("You need %d more %s for this bank trade.",[amount-player.hand[give],CatanI18n.term(RES[give])])
				if s.bank[receive]<1: return CatanI18n.message("The bank has no %s left. Choose a different resource.",[CatanI18n.term(RES[receive])])
				player.hand[give]-=amount
				s.bank[give]+=amount
				player.hand[receive]+=1
				s.bank[receive]-=1
				_stat(p,"bank_trades",1)
				_log(CatanI18n.message("%s traded with the bank.",[player.name]))
				_trade_event("bank",p)
			elif action=="offer_trade":
				if s.get("paired",false): return "The paired player may trade only with the bank."
				var give=a.get("give",[])
				var receive=a.get("receive",[])
				if not _resource_array(give) or not _resource_array(receive) or total(give)==0 or total(receive)==0: return "Choose at least one resource to give and one to receive."
				if not can_pay(p,give): return CatanI18n.message("You need %s more to make this offer.",[_missing(p,give)])
				for r in 5:
					if give[r]>0 and receive[r]>0: return "Offer and request different resources."
				_trade_event("offered",p)
				s.offer={"id":s.trade_event.id,"from":p,"give":give.duplicate(),"receive":receive.duplicate(),"responses":{},"waiting":true}
			elif action=="confirm_trade": return _confirm(p,id)
			elif action=="end":
				_score()
				if s.winner!=-1: return ""
				for i in 5:
					player.cards[i]+=player.new_cards[i]
					player.new_cards[i]=0
				if s.get("extension",false) and not s.paired:
					s.primary=p
					s.turn=(p+3)%s.players.size()
					s.paired=true
					s.rolled=true
					_log(CatanI18n.message("%s takes the paired turn: build, cards and bank trades.",[s.players[s.turn].name]))
				else:
					s.turn=(int(s.get("primary",p))+1)%s.players.size() if s.get("extension",false) else (p+1)%s.players.size()
					s.primary=s.turn
					s.paired=false
					s.rolled=false
				s.card_played=false
				s.offer={}
			else: return "This action is unavailable. Please choose an action from the game controls."
	else: return "This action is unavailable at this stage of the turn."
	_score()
	return ""

func _resource_array(a: Variant) -> bool:
	if not a is Array or a.size()!=5: return false
	for n in a:
		if not (n is int or n is float) or n<0 or n>int(s.get("resource_limit",19)) or n!=int(n): return false
	return true

## Other players answer an offer; the offering player then picks one partner.
## A counter keeps the offer's orientation: "give" is still what the offering
## player hands over and "receive" what they get back.
func _respond(p: int,action: String,a: Dictionary) -> String:
	if s.get("paired",false): return "During a paired turn, trades are only available with the bank."
	if s.phase!="play" or s.offer.is_empty(): return "This offer is no longer available. Wait for a new offer."
	var offer=s.offer
	if p==int(offer.from): return "Other players can accept your offer. You can withdraw it to make a new one."
	var response={"answer":"decline"}
	if action=="accept_trade":
		if not can_pay(p,offer.receive): return CatanI18n.message("You need %s more to accept this offer.",[_missing(p,offer.receive)])
		response={"answer":"accept"}
	elif action=="counter_trade":
		var give=a.get("give",[])
		var receive=a.get("receive",[])
		if not _resource_array(give) or not _resource_array(receive) or total(give)==0 or total(receive)==0: return "Choose at least one resource to give and one to receive."
		for r in 5:
			if give[r]>0 and receive[r]>0: return "Offer and request different resources."
		if not can_pay(p,receive): return CatanI18n.message("You need %s more to make this offer.",[_missing(p,receive)])
		if give==offer.give and receive==offer.receive: response={"answer":"accept"}
		else: response={"answer":"counter","give":give.duplicate(),"receive":receive.duplicate()}
	offer.responses[str(p)]=response
	if offer.responses.size()>=s.players.size()-1: offer.waiting=false
	_trade_event("responded",p,int(offer.from))
	return ""

## Closes the response window; the host calls it after a few seconds.
func open_offer():
	if not s.offer.is_empty(): s.offer.waiting=false

func _confirm(p: int,partner: int) -> String:
	if s.offer.is_empty(): return "This offer is no longer available. Wait for a new offer."
	var offer=s.offer
	if offer.get("waiting",false): return "Give the other players a moment to answer your offer."
	var response=offer.responses.get(str(partner),{})
	if partner<0 or partner>=s.players.size() or not response.get("answer","") in ["accept","counter"]: return "Choose a player who accepted your offer."
	var give: Array=response.give if response.answer=="counter" else offer.give
	var receive: Array=response.receive if response.answer=="counter" else offer.receive
	if not can_pay(p,give): return CatanI18n.message("You need %s more to make this offer.",[_missing(p,give)])
	if not can_pay(partner,receive): return CatanI18n.message("%s no longer has the resources for this trade.",[s.players[partner].name])
	for r in 5:
		s.players[partner].hand[r]+=give[r]-receive[r]
		s.players[p].hand[r]+=receive[r]-give[r]
	_stat(p,"trades",1)
	_stat(partner,"trades",1)
	_log(CatanI18n.message("%s traded with %s.",[s.players[p].name,s.players[partner].name]))
	_trade_event("accepted",p,partner)
	s.offer={}
	return ""

## Hexes the robber may move to. The friendly robber stays off hexes that touch
## another player with 2 public points or fewer, unless that leaves nowhere to go.
func robber_sites(p: int) -> Array:
	var open=[]
	var friendly=[]
	for t in s.tiles.size():
		if t==s.robber: continue
		open.append(t)
		var spared=false
		for v in s.tiles[t].corners:
			var owner=int(s.vertices[v].owner)
			if owner>=0 and owner!=p and int(s.players[owner].points)<=2: spared=true
		if not spared: friendly.append(t)
	return friendly if s.get("friendly_robber",false) and not friendly.is_empty() else open

func _stat(p: int,key: String,amount: int):
	var stats=s.players[p].get("stats",{})
	if stats.has(key): stats[key]+=amount

func produce(roll: int):
	var gains=[]
	for p in s.players: gains.append([0,0,0,0,0])
	for i in s.tiles.size():
		var t=s.tiles[i]
		if t.number!=roll or i==s.robber or t.kind==5: continue
		for vid in t.corners:
			var v=s.vertices[vid]
			if v.owner>=0: gains[v.owner][t.kind]+=v.level
	for r in 5:
		var demand=0
		for gain in gains: demand+=gain[r]
		if demand>s.bank[r]:
			var recipients=[]
			for p in s.players.size():
				if gains[p][r]>0: recipients.append(p)
			if recipients.size()==1:
				s.players[recipients[0]].hand[r]+=s.bank[r]
				_produced(recipients[0],r,s.bank[r])
				s.bank[r]=0
			continue
		for p in s.players.size():
			s.players[p].hand[r]+=gains[p][r]
			s.bank[r]-=gains[p][r]
			_produced(p,r,gains[p][r])

func _produced(p: int,r: int,amount: int):
	var stats=s.players[p].get("stats",{})
	if stats.has("produced"): stats.produced[r]+=amount

func _walk(p: int,v: int,used: Dictionary) -> int:
	if not used.is_empty() and s.vertices[v].owner>=0 and s.vertices[v].owner!=p: return 0
	var best=0
	for eid in s.vertices[v].edges:
		if s.edges[eid].owner!=p or used.has(eid): continue
		used[eid]=true
		var e=s.edges[eid]
		best=maxi(best,1+_walk(p,e.b if e.a==v else e.a,used))
		used.erase(eid)
	return best

func _score():
	for p in s.players.size():
		var player=s.players[p]
		player.road_length=0
		for v in s.vertices.size(): player.road_length=maxi(player.road_length,_walk(p,v,{}))
	for award in ["longest","army"]:
		var key="road_length" if award=="longest" else "knights"
		var threshold=5 if award=="longest" else 3
		var best=threshold-1
		var leaders=[]
		for p in s.players.size():
			var value=s.players[p][key]
			if value>best:
				best=value
				leaders=[p]
			elif value==best and value>=threshold: leaders.append(p)
		if leaders.size()==1: s[award]=leaders[0]
		elif s[award] not in leaders: s[award]=-1
	for p in s.players.size():
		var points=0
		for v in s.vertices:
			if v.owner==p: points+=v.level
		if s.longest==p: points+=2
		if s.army==p: points+=2
		s.players[p].points=points
		if p==s.turn and points+s.players[p].cards[4]+s.players[p].new_cards[4]>=target():
			s.winner=p
			_log(CatanI18n.message("%s wins with %d victory points!",[s.players[p].name,points+s.players[p].cards[4]+s.players[p].new_cards[4]]))

func target() -> int:
	return int(s.get("points_target",10))

## Snapshots carry only the newest log lines; clients keep the rest as it arrives.
func snapshot(viewer: int,log_tail: int=40) -> Dictionary:
	var history: Array=s.log
	s.log=[]
	var result=s.duplicate(true)
	s.log=history
	result.log=history.slice(maxi(0,history.size()-log_tail))
	result.log_start=history.size()-result.log.size()
	result.deck_count=result.deck.size()
	result.erase("deck")
	for p in result.players.size():
		var player=result.players[p]
		player.resource_count=total(player.hand)
		player.card_count=total(player.cards)+total(player.new_cards)
		if p!=viewer and s.winner==-1:
			player.hand=[]
			player.cards=[]
			player.new_cards=[]
	return result

func _missing(player: int,cost: Array) -> Dictionary:
	var parts=[]
	for r in 5:
		var amount=maxi(0,int(cost[r])-int(s.players[player].hand[r]))
		if amount>0:parts.append({"key":"%d %s","args":[amount,CatanI18n.term(RES[r])]})
	return {"list":parts}

func cost_error(player: int,kind: String) -> String:
	var keys={"road":"To build a road, you still need %s.","settlement":"To build a settlement, you still need %s.","city":"To upgrade to a city, you still need %s.","buy_card":"To buy a development card, you still need %s."}
	return CatanI18n.message(keys[kind],[_missing(player,COST[kind])])
