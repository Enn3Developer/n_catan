class_name CatanRules
extends RefCounted

const RES = ["Timber", "Brick", "Wool", "Grain", "Ore"]
const COST = {"road": [1,1,0,0,0], "settlement": [1,1,1,1,0], "city": [0,0,0,2,3], "buy_card": [0,0,1,1,1], "ship": [1,0,1,0,0]}
## Pieces each player owns.
const PIECE_LIMITS={"road":15,"settlement":5,"city":4,"ship":15}
## Tile kinds past the five resources.
const DESERT=5
const TREASURE=6
## What snapshots show for a hex still under the fog.
const FOG=7
var s: Dictionary = {}
var rng = RandomNumberGenerator.new()

const ISLANDS=["random","classic","archipelago"]
const TURN_TIMERS=[0,30,45,60,90,120,180]
const POINT_TARGETS=[5,15]
const DEFAULT_OPTIONS={"island":"random","points":10,"friendly_robber":false,"random_start":false,"start_card":false,"treasure":false,"move_ships":false,"fog":false}
## House rules that are simple switches in the lobby, with their name and help.
const HOUSE_RULES=["friendly_robber","random_start","start_card","treasure","move_ships","fog"]
## House rules that only change an archipelago game.
const SEA_RULES=["move_ships","fog"]
const HOUSE_RULE_TEXT={
	"friendly_robber":["Friendly robber","The robber cannot be placed next to a player with 3 points or fewer."],
	"random_start":["Random start","Everyone's first two settlements and roads are placed for them, on good spots of similar value."],
	"start_card":["Starting card","Everyone draws a development card before the first roll and can play it on their first turn."],
	"treasure":["Treasure tile","When its number is rolled, the treasure gives each settlement on it 2 random resources (a city 4), then draws a new number. No one can start within 3 roads of it."],
	"move_ships":["Moving ships","Archipelago only. Once per turn, after rolling, you may move one ship from the open end of a line to another sea edge you could build on. A ship built this turn stays put."],
	"fog":["Fog","Archipelago only. The outer islands start hidden in fog. A road, ship or settlement that reaches a hidden hex reveals it, and a resource hex gives its finder one of that resource."]}
## Numbers the treasure tile draws from each time it pays out.
const TREASURE_NUMBERS=[2,3,4,5,6,8,9,10,11,12]
## A starting settlement must be at least this many roads from the treasure.
const TREASURE_DISTANCE=3
## Points for the first settlement on each island past the one you started on.
const ISLAND_BONUS=2
const LOG_LIMIT=5000
## The friendly robber spares players with this many public points or fewer.
const FRIENDLY_LIMIT=3
## Outcomes left in the dice deck when it is reshuffled.
const DICE_RESHUFFLE=5
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
	s.random_start=bool(settings.random_start)
	s.start_card=bool(settings.start_card)
	s.treasure=bool(settings.treasure)
	s.move_ships=bool(settings.move_ships) and s.island=="archipelago"
	s.fog=bool(settings.fog) and s.island=="archipelago"
	s.ship_moved=false
	s.new_ships=[]
	s.dice_counts=[0,0,0,0,0,0,0,0,0,0,0]
	s.resource_limit=24 if extended else 19
	if extended: s.bank=[24,24,24,24,24]
	var terrain = [0,0,0,0,1,1,1,2,2,2,2,3,3,3,3,4,4,4,5]
	if extended: terrain.append_array([0,0,1,1,2,2,3,3,4,4,5])
	var numbers = [5,2,6,3,8,10,9,12,11,4,8,10,9,4,5,6,3,11]
	if extended: numbers=[2,2,3,3,3,4,4,4,5,5,5,6,6,6,8,8,8,9,9,9,10,10,10,11,11,11,12,12]
	# The archipelago spreads a little more land over its islands.
	if s.island=="archipelago":
		terrain.append_array([0,2,3,4] if not extended else [0,1,2,3,4])
		numbers.append_array([3,4,10,11] if not extended else [3,5,9,10,11])
	_shuffle(terrain)
	_shuffle(numbers)
	var land_count=terrain.size()+(1 if s.treasure else 0)
	var centers=_island_centers(land_count,extended) if s.island=="random" else _archipelago_centers(land_count,extended) if s.island=="archipelago" else _classic_centers(extended)
	var islands=_island_ids(centers)
	if s.treasure: terrain.insert(_treasure_spot(centers,islands),TREASURE)
	var keys = {}
	var edge_keys = {}
	var n = 0
	for center in centers:
		var tid = s.tiles.size()
		var kind = terrain[tid]
		var tile = {"x":center.x,"z":center.y,"kind":kind,"number":0,"corners":[],"island":islands[tid]}
		if kind==TREASURE: tile.number=TREASURE_NUMBERS[rng.randi_range(0,TREASURE_NUMBERS.size()-1)]
		elif kind != DESERT:
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
	if s.island=="archipelago": _add_sea(centers,keys,edge_keys)
	if s.fog:
		for t in s.tiles:
			if int(t.island)>0: t.fog=true
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
			if common.size()==2 and s.tiles[common[0]].kind<DESERT and s.tiles[common[1]].kind<DESERT and s.tiles[common[0]].number in [6,8] and s.tiles[common[1]].number in [6,8]: valid=false
		if valid: break
		_shuffle(numbers)
		n=0
		for t in s.tiles:
			if t.kind<DESERT:
				t.number=numbers[n]
				n+=1
	var ports=[-1,0,-1,1,2,-1,3,4,-1]
	if extended: ports.append_array([2,-1])
	_shuffle(ports)
	_place_ports(ports)
	for pname in names:
		s.players.append({"name":str(pname).substr(0,20),"hand":[0,0,0,0,0],"cards":[0,0,0,0,0],"new_cards":[0,0,0,0,0],"knights":0,"points":0,"road_length":0,"islands":[],"island_bonus":0,"stats":{"rolls":0,"produced":[0,0,0,0,0],"stolen":0,"lost":0,"discarded":0,"trades":0,"bank_trades":0,"cards_played":0}})
	for i in (20 if extended else 14): s.deck.append(0)
	for i in 5: s.deck.append(4)
	for i in (3 if extended else 2): s.deck.append_array([1,2,3])
	_shuffle(s.deck)
	s.treasure_near=_treasure_near()
	s.home_island=0
	_log("The island awaits. Place your first settlement.")
	if s.random_start: _random_setup()
	return s

## Groups land into islands: hexes that share a side belong together. The
## largest island is 0, where everyone starts on an archipelago.
func _island_ids(centers: Array) -> Array:
	var ids=[]
	ids.resize(centers.size())
	ids.fill(-1)
	var groups=[]
	for i in centers.size():
		if ids[i]>=0: continue
		var group=[i]
		ids[i]=groups.size()
		var at=0
		while at<group.size():
			for j in centers.size():
				if ids[j]<0 and centers[group[at]].distance_to(centers[j])<1.9:
					ids[j]=ids[i]
					group.append(j)
			at+=1
		groups.append(group)
	var order=range(groups.size())
	order.sort_custom(func(a,b):return groups[a].size()>groups[b].size() or (groups[a].size()==groups[b].size() and a<b))
	var renamed=[]
	for i in centers.size(): renamed.append(order.find(ids[i]))
	return renamed

## Where the treasure lies: a coastal hex, on an outer island when there is one,
## so plenty of the board stays open for starting settlements.
func _treasure_spot(centers: Array,islands: Array) -> int:
	var best=[]
	var fewest=99
	for i in centers.size():
		var around=0
		for j in centers.size():
			if i!=j and centers[i].distance_to(centers[j])<1.9: around+=1
		if islands[i]>0: around-=10
		if around<fewest:
			fewest=around
			best=[i]
		elif around==fewest: best.append(i)
	return best[rng.randi_range(0,best.size()-1)]

## Corners closer than TREASURE_DISTANCE roads to the treasure tile.
func _treasure_near() -> Array:
	var near={}
	var frontier=[]
	for t in s.tiles:
		if t.kind==TREASURE:
			for v in t.corners:
				near[v]=true
				frontier.append(v)
	for step in TREASURE_DISTANCE-1:
		var next=[]
		for v in frontier:
			for eid in s.vertices[v].edges:
				var e=s.edges[eid]
				var other=e.b if e.a==v else e.a
				if not near.has(other):
					near[other]=true
					next.append(other)
		frontier=next
	return near.keys()

## A main island and two or three smaller ones, each a sea hex apart. The
## islands grow like the random coastline, but never touch one another.
func _archipelago_centers(count: int,extended: bool) -> Array:
	var sizes=[13,4,3,3] if not extended else [19,6,5,5]
	var extra=count-_sum(sizes)
	sizes[0]+=extra
	var reach=5 if not extended else 6
	for attempt in 60:
		var owner={}
		var islands=[]
		var turn=rng.randf()*TAU
		islands.append([Vector2i.ZERO])
		owner[Vector2i.ZERO]=0
		for i in range(1,sizes.size()):
			var angle=turn+TAU*i/(sizes.size()-1)+rng.randf_range(-.3,.3)
			# World units: neighboring hexes are about 1.73 apart.
			var distance=rng.randf_range(6.6,7.4) if not extended else rng.randf_range(8.4,9.2)
			var seed_hex=_nearest_hex(Vector2(cos(angle),sin(angle))*distance)
			islands.append([seed_hex])
			owner[seed_hex]=i
		var ok=true
		var grown=true
		while grown:
			grown=false
			for i in sizes.size():
				if islands[i].size()>=sizes[i]: continue
				var choices=[]
				var total_weight=0.0
				for hex in islands[i]:
					for step in AXIAL:
						var next: Vector2i=hex+step
						if owner.has(next) or _ring(next)>reach: continue
						var touches=false
						var around=0
						for side in AXIAL:
							var near: Vector2i=next+side
							if owner.has(near):
								if owner[near]!=i: touches=true
								else: around+=1
						if touches: continue
						var weight=pow(float(around),2.2)
						choices.append([next,weight])
						total_weight+=weight
				if choices.is_empty():
					ok=false
					continue
				var pick=rng.randf()*total_weight
				for choice in choices:
					pick-=choice[1]
					if pick<=0.0 or choice==choices[-1]:
						islands[i].append(choice[0])
						owner[choice[0]]=i
						break
				grown=true
		if not ok or _has_lagoon(owner,reach): continue
		var hexes=owner.keys()
		hexes.sort_custom(func(a,b): return a.y<b.y or (a.y==b.y and a.x<b.x))
		var centers=[]
		for hex in hexes: centers.append(Vector2(sqrt(3.0)*(hex.x+hex.y*0.5),1.5*hex.y))
		return centers
	return _island_centers(count,extended)

func _nearest_hex(p: Vector2) -> Vector2i:
	var r=p.y/1.5
	var q=p.x/sqrt(3.0)-r*.5
	var s3=-q-r
	var rq=roundi(q);var rr=roundi(r);var rs=roundi(s3)
	var dq=absf(rq-q);var dr=absf(rr-r);var ds=absf(rs-s3)
	if dq>dr and dq>ds: rq=-rr-rs
	elif dr>ds: rr=-rq-rs
	return Vector2i(rq,rr)

func _sum(values: Array) -> int:
	var result=0
	for v in values: result+=int(v)
	return result

## Sea hexes near the archipelago's coasts get corners and edges too, so
## ships can sail between the islands. Their edges touch no land tile.
func _add_sea(centers: Array,keys: Dictionary,edge_keys: Dictionary):
	var land={}
	for c in centers: land[_nearest_hex(c)]=true
	var sea={}
	for hex in land:
		for a in AXIAL:
			for b in AXIAL:
				var near: Vector2i=hex+a+b
				if not land.has(near): sea[near]=true
				if not land.has(hex+a): sea[hex+a]=true
	for hex in sea:
		var center=Vector2(sqrt(3.0)*(hex.x+hex.y*0.5),1.5*hex.y)
		var corners=[]
		for c in 6:
			var angle=deg_to_rad(30+60*c)
			var p=center+Vector2(cos(angle),sin(angle))
			var key="%d,%d" % [roundi(p.x*100),roundi(p.y*100)]
			if not keys.has(key):
				keys[key]=s.vertices.size()
				s.vertices.append({"x":p.x,"z":p.y,"owner":-1,"level":0,"tiles":[],"edges":[],"port":-2})
			corners.append(keys[key])
		for c in 6:
			var a=int(corners[c])
			var b=int(corners[(c+1)%6])
			var key="%d:%d" % [mini(a,b),maxi(a,b)]
			if not edge_keys.has(key):
				edge_keys[key]=s.edges.size()
				var eid=s.edges.size()
				s.edges.append({"a":a,"b":b,"owner":-1,"tiles":0})
				s.vertices[a].edges.append(eid)
				s.vertices[b].edges.append(eid)

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
	var coast=_coast_loops()
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

## Every island's coast, one loop after another.
func _coast_loops() -> Array:
	var all=[]
	var seen={}
	while true:
		var loop=_coast_loop(seen)
		if loop.is_empty(): break
		for e in loop: seen[e]=true
		all.append_array(loop)
	return all

## Coast edges in order around the island. Without lagoons they form one loop.
func _coast_loop(skip: Dictionary={}) -> Array:
	var by_vertex={}
	var first=-1
	for i in s.edges.size():
		if s.edges[i].tiles!=1: continue
		if first<0 and not skip.has(i): first=i
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

func _log(message: Variant):
	s.log.append(message)
	if s.log.size()>LOG_LIMIT: s.log.pop_front()

## A log line with more detail for some seats: they read the private line and
## everyone else the public one. A robbery tells only the two players involved
## what was taken.
func _log_private(public: String,private: String,seen: Array):
	_log({"public":public,"private":private,"seen":seen})

## The log as one seat reads it.
static func log_for(viewer: int,entries: Array) -> Array:
	var result=[]
	for entry in entries:
		if entry is Dictionary:result.append(entry.private if viewer in entry.get("seen",[]) else entry.public)
		else:result.append(entry)
	return result

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
	if not _open_corner(v): return false
	if setup: return not _setup_restricted(v)
	for eid in s.vertices[v].edges:
		if s.edges[eid].owner==p: return true
	return false

## An empty land corner with no building on a neighboring corner.
func _open_corner(v: int) -> bool:
	if v<0 or v>=s.vertices.size() or s.vertices[v].owner!=-1 or s.vertices[v].tiles.is_empty(): return false
	for eid in s.vertices[v].edges:
		var e=s.edges[eid]
		if s.vertices[e.b if e.a==v else e.a].owner!=-1: return false
	return true

## Starting settlements keep off the treasure and, on an archipelago, stay on
## the main island, unless no such corner is left anywhere.
func _setup_restricted(v: int) -> bool:
	if not _setup_preferred(v): 
		for other in s.vertices.size():
			if _setup_preferred(other) and _open_corner(other): return true
	return false

func _setup_preferred(v: int) -> bool:
	if v in s.get("treasure_near",[]): return false
	if s.get("island","")=="archipelago" and not _on_island(v,int(s.get("home_island",0))): return false
	return true

func _on_island(v: int,island: int) -> bool:
	for t in s.vertices[v].tiles:
		if int(s.tiles[t].get("island",0))==island: return true
	return false

func is_ship(eid: int) -> bool:
	return bool(s.edges[eid].get("ship",false))

func valid_edge(p: int,eid: int,setup: bool=false) -> bool:
	if eid<0 or eid>=s.edges.size() or s.edges[eid].owner!=-1: return false
	var e=s.edges[eid]
	# Roads need land on at least one side.
	if int(e.tiles)==0: return false
	if setup: return s.anchor in [e.a,e.b]
	for v in [e.a,e.b]:
		if s.vertices[v].owner==p: return true
		if s.vertices[v].owner!=-1: continue
		for adjacent in s.vertices[v].edges:
			if s.edges[adjacent].owner==p and not is_ship(adjacent): return true
	return false

## Ships sail on edges with sea on at least one side, from your own harbor
## town or the end of your own line of ships. A road and a ship only meet at
## one of your settlements or cities.
func valid_ship(p: int,eid: int) -> bool:
	if s.get("island","")!="archipelago": return false
	if eid<0 or eid>=s.edges.size() or s.edges[eid].owner!=-1: return false
	var e=s.edges[eid]
	if int(e.tiles)>=2: return false
	for v in [e.a,e.b]:
		if s.vertices[v].owner==p: return true
		if s.vertices[v].owner!=-1: continue
		for adjacent in s.vertices[v].edges:
			if s.edges[adjacent].owner==p and is_ship(adjacent): return true
	return false

func pieces(p: int,kind: String) -> int:
	var count=0
	if kind=="road" or kind=="ship":
		for i in s.edges.size():
			if s.edges[i].owner==p and is_ship(i)==(kind=="ship"): count+=1
	else:
		for v in s.vertices:
			if v.owner==p and v.level==(1 if kind=="settlement" else 2): count+=1
	return count

# Shared by the HUD and placement flow; affordability alone is not enough.
func build_sites(p: int,kind: String) -> Array:
	var result=[]
	if p<0 or p>=s.players.size(): return result
	if pieces(p,kind)>=PIECE_LIMITS.get(kind,0): return result
	if kind=="road":
		for e in s.edges.size():
			if valid_edge(p,e): result.append(e)
	elif kind=="ship":
		for e in s.edges.size():
			if valid_ship(p,e): result.append(e)
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
		_claim_islands(p,id,false)
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
		_reveal_edge(p,id)
		s.setup+=1
		var count=s.players.size()
		if s.setup==2*count:
			s.turn=0
			s.phase="play"
			if s.get("start_card",false): _deal_start_cards()
			_log("All settlements placed. Roll the dice to begin.")
			_score()
			_record_points()
		else:
			s.turn=s.setup if s.setup<count else 2*count-1-s.setup
			s.phase="setup_settlement"
	elif s.phase=="discard": return "Wait for all players to discard."
	elif s.phase=="robber":
		if action!="robber" or id<0 or id>=s.tiles.size() or id==s.robber: return "Move the robber to a different hex."
		if s.tiles[id].get("fog",false): return "The robber can't go into the fog. Choose a hex that has been revealed."
		if id not in robber_sites(p): return "The friendly robber spares players with 3 points or fewer. Choose another hex."
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
		var public=CatanI18n.message("%s stole a resource from %s.",[player.name,s.players[id].name])
		_log_private(public,CatanI18n.message("%s stole 1 %s from %s.",[player.name,CatanI18n.term(RES[r]),s.players[id].name]),[p,id])
		s.theft={"id":int(s.get("theft",{}).get("id",0))+1,"thief":p,"victim":id,"resource":r}
	elif s.phase=="free_roads":
		if action=="finish_roads":
			s.free_roads=0
			s.phase="play"
		elif action=="road" and valid_edge(p,id) and pieces(p,"road")<15:
			s.edges[id].owner=p
			_reveal_edge(p,id)
			s.free_roads-=1
			if s.free_roads==0 or (pieces(p,"road")==15 and build_sites(p,"ship").is_empty()): s.phase="play"
		elif action=="ship" and valid_ship(p,id) and pieces(p,"ship")<PIECE_LIMITS.ship:
			s.edges[id].owner=p
			s.edges[id].ship=true
			_new_ship(p,id)
			s.free_roads-=1
			if s.free_roads==0: s.phase="play"
		else: return "Choose a connected road, or finish building."
	elif s.phase=="play":
		if action=="roll":
			if s.rolled: return "You already rolled this turn."
			s.rolled=true
			s.dice=_draw_dice()
			var roll=total(s.dice)
			_stat(p,"rolls",1)
			if s.has("dice_counts"): s.dice_counts[roll-2]+=1
			_log(CatanI18n.message("%s rolled %d.",[player.name,roll]))
			if roll==7:
				for i in s.players.size():
					var count=total(s.players[i].hand)
					if count>7: s.discards[str(i)]=floori(count/2.0)
				s.phase="discard" if not s.discards.is_empty() else "robber"
			else:
				produce(roll)
				_pay_treasure(roll)
		elif action=="play_card":
			var card=id
			if card<0 or card>3: return "Choose a development card to play. Victory point cards count automatically."
			if s.card_played: return "You have played a development card this turn. You can play another next turn."
			if player.cards[card]<1:
				if player.new_cards[card]>0: return "You bought this card this turn. You can play it on your next turn."
				return "You do not have this development card."
			if card==1 and pieces(p,"road")>=15 and build_sites(p,"ship").is_empty(): return "All 15 of your roads are on the board. You have none left to place."
			if card==2:
				var selected=a.get("cards",[])
				if not _resource_array(selected) or total(selected)!=2: return "Choose two resources."
				for r in 5:
					if s.bank[r]<selected[r]: return CatanI18n.message("The bank has only %d %s. Choose a different resource.",[s.bank[r],CatanI18n.term(RES[r])])
				for r in 5:
					s.bank[r]-=selected[r]
					player.hand[r]+=selected[r]
			var taken=0
			if card==3:
				var r=int(a.get("resource",-1))
				if r<0 or r>=5: return "Choose a resource."
				for i in s.players.size():
					if i!=p:
						taken+=s.players[i].hand[r]
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
			match card:
				0:_log(CatanI18n.message("%s played a Knight card.",[player.name]))
				1:_log(CatanI18n.message("%s played the Road building card.",[player.name]))
				2:_log(CatanI18n.message("%s played the Year of plenty card and took %s.",[player.name,_amounts(a.cards)]))
				3:_log(CatanI18n.message("%s played the Monopoly card and took %d %s.",[player.name,taken,CatanI18n.term(RES[int(a.resource)])]))
		else:
			if not s.rolled: return "Roll the dice first."
			if action in COST:
				if not can_pay(p,COST[action]): return cost_error(p,action)
				if action=="road":
					if pieces(p,"road")>=15: return "All 15 of your roads are on the board. You have none left to place."
					if not valid_edge(p,id): return "Choose an empty edge connected to your road or building. Another player’s building blocks the route."
					s.edges[id].owner=p
					_reveal_edge(p,id)
				elif action=="ship":
					if pieces(p,"ship")>=PIECE_LIMITS.ship: return "All 15 of your ships are at sea. You have none left to place."
					if not valid_ship(p,id): return "Choose a sea edge next to your harbor town or the end of your ships."
					s.edges[id].owner=p
					s.edges[id].ship=true
					_new_ship(p,id)
				elif action=="settlement":
					if pieces(p,"settlement")>=5: return "All 5 of your settlements are on the board. Upgrade one to a city to free a settlement piece."
					if not valid_vertex(p,id): return "Choose an empty corner on your road, at least two edges from every settlement or city."
					s.vertices[id].owner=p
					s.vertices[id].level=1
					_claim_islands(p,id,true)
					_reveal(p,[id])
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
				var paid=[0,0,0,0,0]
				paid[give]=amount
				var got=[0,0,0,0,0]
				got[receive]=1
				_log(CatanI18n.message("%s traded %s with the bank for %s.",[player.name,_amounts(paid),_amounts(got)]))
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
				s.offers_made=int(s.get("offers_made",0))+1
				s.offer={"id":s.trade_event.id,"from":p,"give":give.duplicate(),"receive":receive.duplicate(),"responses":{},"waiting":true}
			elif action=="confirm_trade": return _confirm(p,id)
			elif action=="move_ship":
				if not s.get("move_ships",false): return "Moving ships is a house rule this room does not use."
				if s.get("ship_moved",false): return "You have moved a ship this turn. You can move another next turn."
				if id not in movable_ships(p): return "Choose one of your ships at the open end of a line. Ships built this turn cannot move."
				var to=int(a.get("to",-1))
				if to not in ship_moves(p,id): return "Choose a sea edge you could build a ship on."
				s.edges[id].owner=-1
				s.edges[id].erase("ship")
				s.edges[to].owner=p
				s.edges[to].ship=true
				s.ship_moved=true
				_reveal_edge(p,to)
				_log(CatanI18n.message("%s moved a ship.",[player.name]))
			elif action=="end":
				_score()
				if s.winner!=-1: return ""
				_record_points()
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
				s.ship_moved=false
				s.new_ships=[]
				s.offer={}
				s.offers_made=0
			else: return "This action is unavailable. Please choose an action from the game controls."
	else: return "This action is unavailable at this stage of the turn."
	_score()
	return ""

## Fairer dice: rolls come from a shuffled deck of all 36 two-dice outcomes, so
## over a game each total turns up about as often as the odds say. The deck is
## reshuffled with a few outcomes still unseen, so the last rolls stay a surprise.
func _draw_dice() -> Array:
	if s.has("next_dice"):
		var forced: Array=s.next_dice
		s.erase("next_dice")
		return forced
	var bag: Array=s.get("dice_bag",[])
	if bag.size()<=DICE_RESHUFFLE:
		bag=[]
		for a in range(1,7):
			for b in range(1,7):bag.append([a,b])
		_shuffle(bag)
		s.dice_bag=bag
	return bag.pop_back()

## Makes the next roll come up as this total; lessons use it to show production.
func force_roll(roll: int):
	var a=clampi(roll-1,1,6)
	s.next_dice=[a,roll-a]

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
	_log(CatanI18n.message("%s traded %s to %s for %s.",[s.players[p].name,_amounts(give),s.players[partner].name,_amounts(receive)]))
	_trade_event("accepted",p,partner)
	s.offer={}
	return ""

## Hexes the robber may move to. The friendly robber stays off hexes that touch
## another player with 3 public points or fewer, unless that leaves nowhere to go.
func robber_sites(p: int) -> Array:
	var open=[]
	var friendly=[]
	for t in s.tiles.size():
		if t==s.robber or s.tiles[t].get("fog",false): continue
		open.append(t)
		var spared=false
		for v in s.tiles[t].corners:
			var owner=int(s.vertices[v].owner)
			if owner>=0 and owner!=p and int(s.players[owner].points)<=FRIENDLY_LIMIT: spared=true
		if not spared: friendly.append(t)
	return friendly if s.get("friendly_robber",false) and not friendly.is_empty() else open

## Moving ships: ships at the open end of a line, not built this turn, while
## the player has not moved one yet this turn.
func movable_ships(p: int) -> Array:
	var result=[]
	if not s.get("move_ships",false) or s.get("ship_moved",false) or p<0 or p>=s.players.size(): return result
	for eid in s.edges.size():
		if s.edges[eid].owner==p and is_ship(eid) and eid not in s.get("new_ships",[]) and _open_ship(p,eid): result.append(eid)
	return result

## A ship is open when one of its ends has neither another of the player's
## ships nor the player's own settlement or city.
func _open_ship(p: int,eid: int) -> bool:
	var e=s.edges[eid]
	for v in [e.a,e.b]:
		if s.vertices[v].owner==p: continue
		var linked=false
		for other in s.vertices[v].edges:
			if other!=eid and s.edges[other].owner==p and is_ship(other): linked=true
		if not linked: return true
	return false

## Sea edges the ship could move to: anywhere the player could build a ship
## once this one has left its edge.
func ship_moves(p: int,eid: int) -> Array:
	var result=[]
	if eid<0 or eid>=s.edges.size() or s.edges[eid].owner!=p or not is_ship(eid): return result
	s.edges[eid].owner=-1
	for other in s.edges.size():
		if other!=eid and valid_ship(p,other): result.append(other)
	s.edges[eid].owner=p
	return result

func _new_ship(p: int,eid: int):
	if not s.has("new_ships"): s.new_ships=[]
	s.new_ships.append(eid)
	_reveal_edge(p,eid)

func _reveal_edge(p: int,eid: int):
	_reveal(p,[s.edges[eid].a,s.edges[eid].b])

## Fog: hexes touching these corners come out of the fog. A resource hex
## gives the player who found it one of its resource, if the bank has one.
func _reveal(p: int,corners: Array):
	if not s.get("fog",false): return
	for v in corners:
		for t in s.vertices[v].tiles:
			var tile=s.tiles[t]
			if not tile.get("fog",false): continue
			tile.erase("fog")
			var kind=int(tile.kind)
			if kind<DESERT and s.bank[kind]>0:
				s.bank[kind]-=1
				s.players[p].hand[kind]+=1
				_produced(p,kind,1)
				_log(CatanI18n.message("%s revealed a hex in the fog and found %s.",[s.players[p].name,CatanI18n.term(RES[kind])]))
			elif kind==TREASURE: _log(CatanI18n.message("%s revealed the treasure in the fog.",[s.players[p].name]))
			else: _log(CatanI18n.message("%s revealed a hex in the fog.",[s.players[p].name]))

func _stat(p: int,key: String,amount: int):
	var stats=s.players[p].get("stats",{})
	if stats.has(key): stats[key]+=amount

func produce(roll: int):
	var gains=[]
	for p in s.players: gains.append([0,0,0,0,0])
	for i in s.tiles.size():
		var t=s.tiles[i]
		if t.number!=roll or i==s.robber or t.kind>=DESERT or t.get("fog",false): continue
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

## The treasure pays 2 random resources to each settlement on it and 4 to each
## city, from what the bank holds. Then it draws a new number.
func _pay_treasure(roll: int):
	for i in s.tiles.size():
		var t=s.tiles[i]
		if t.kind!=TREASURE or t.number!=roll or t.get("fog",false): continue
		if i==s.robber:
			_log("The robber sits on the treasure. It pays nothing this time.")
			continue
		for vid in t.corners:
			var v=s.vertices[vid]
			if v.owner<0: continue
			var found=0
			for n in 2*int(v.level):
				var stocked=[]
				for r in 5:
					if s.bank[r]>0: stocked.append(r)
				if stocked.is_empty(): break
				var r=stocked[rng.randi_range(0,stocked.size()-1)]
				s.bank[r]-=1
				s.players[v.owner].hand[r]+=1
				_produced(v.owner,r,1)
				found+=1
			if found>0: _log(CatanI18n.message("%s found %d resources in the treasure.",[s.players[v.owner].name,found]))
		var choices=TREASURE_NUMBERS.duplicate()
		choices.erase(t.number)
		t.number=choices[rng.randi_range(0,choices.size()-1)]
		_log(CatanI18n.message("The treasure moves on. Its number is now %d.",[t.number]))

## Each player draws one development card to hold from the start. It can be
## played on the player's first turn.
func _deal_start_cards():
	for p in s.players.size():
		if s.deck.is_empty(): break
		s.players[p].cards[s.deck.pop_back()]+=1
	_log("Everyone drew a development card to start.")

## Records which islands a player has settled; a new island after the start earns the island bonus.
func _claim_islands(p: int,v: int,bonus: bool):
	var player=s.players[p]
	if not player.has("islands"): player.islands=[]
	for t in s.vertices[v].tiles:
		var island=int(s.tiles[t].get("island",0))
		if island in player.islands: continue
		player.islands.append(island)
		if bonus and s.get("island","")=="archipelago":
			player.island_bonus=int(player.get("island_bonus",0))+1
			_log(CatanI18n.message("%s settled a new island: +%d points.",[player.name,ISLAND_BONUS]))

## Random start: every player's two settlements and roads are placed for them,
## in the usual snake order. Each pick comes from the good but not best corners
## left, so nobody is handed the prize spot.
func _random_setup():
	var guard=0
	while str(s.phase).begins_with("setup") and guard<64:
		guard+=1
		var p=int(s.turn)
		var candidates=[]
		var owned={}
		for v in s.vertices:
			if v.owner==p:
				for t in v.tiles: owned[s.tiles[t].kind]=true
		for v in s.vertices.size():
			if not valid_vertex(p,v,true): continue
			var score=0.0
			var kinds={}
			for t in s.vertices[v].tiles:
				var tile=s.tiles[t]
				if tile.kind>=DESERT: continue
				score+=maxi(0,6-absi(7-int(tile.number)))
				if not owned.has(tile.kind): kinds[tile.kind]=true
			candidates.append({"id":v,"score":score+kinds.size()*.8})
		if candidates.is_empty(): break
		candidates.sort_custom(func(a,b):return a.score>b.score)
		var low=int(candidates.size()*.1)
		var high=maxi(low+1,int(candidates.size()*.35))
		var pick=candidates[rng.randi_range(low,mini(high,candidates.size())-1)].id
		apply(p,{"type":"settlement","id":pick})
		var roads=[]
		for eid in s.vertices[pick].edges:
			if valid_edge(p,eid,true): roads.append(eid)
		if roads.is_empty(): break
		apply(p,{"type":"road","id":roads[rng.randi_range(0,roads.size()-1)]})
	_log("Starting settlements were placed at random.")

func _produced(p: int,r: int,amount: int):
	var stats=s.players[p].get("stats",{})
	if stats.has("produced"): stats.produced[r]+=amount

## Longest route: roads and ships count together, but a route only switches
## between them at one of the player's own settlements or cities.
func _walk(p: int,v: int,used: Dictionary,last: int=-1) -> int:
	if not used.is_empty() and s.vertices[v].owner>=0 and s.vertices[v].owner!=p: return 0
	var best=0
	for eid in s.vertices[v].edges:
		if s.edges[eid].owner!=p or used.has(eid): continue
		var ship=1 if is_ship(eid) else 0
		if last>=0 and ship!=last and s.vertices[v].owner!=p: continue
		used[eid]=true
		var e=s.edges[eid]
		best=maxi(best,1+_walk(p,e.b if e.a==v else e.a,used,ship))
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
		points+=ISLAND_BONUS*int(s.players[p].get("island_bonus",0))
		s.players[p].points=points
		if p==s.turn and points+s.players[p].cards[4]+s.players[p].new_cards[4]>=target():
			s.winner=p
			_record_points()
			_log(CatanI18n.message("%s wins with %d victory points!",[s.players[p].name,points+s.players[p].cards[4]+s.players[p].new_cards[4]]))

## Everyone's points with their hidden victory cards, after each turn. The
## chart on the victory screen draws them; snapshots hold them back until then.
func _record_points():
	if not s.has("points_history"): s.points_history=[]
	var row=[]
	for p in s.players.size(): row.append(int(s.players[p].points)+int(s.players[p].cards[4])+int(s.players[p].new_cards[4]))
	s.points_history.append(row)

func target() -> int:
	return int(s.get("points_target",10))

## Snapshots carry only the newest log lines; clients keep the rest as it arrives.
func snapshot(viewer: int,log_tail: int=40) -> Dictionary:
	var history: Array=s.log
	s.log=[]
	var result=s.duplicate(true)
	s.log=history
	result.log=log_for(viewer,history.slice(maxi(0,history.size()-log_tail)))
	result.log_start=history.size()-result.log.size()
	# Only the two players in a robbery learn what was taken.
	if result.has("theft") and viewer not in [int(result.theft.thief),int(result.theft.victim)]:result.theft.erase("resource")
	result.deck_count=result.deck.size()
	result.erase("deck")
	# Upcoming rolls stay with the host.
	result.erase("dice_bag")
	result.erase("next_dice")
	if s.winner==-1: result.erase("points_history")
	# Hexes under the fog keep their land and number with the host.
	for t in result.tiles:
		if t.get("fog",false):
			t.kind=FOG
			t.number=0
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
	var short=[]
	for r in 5:short.append(maxi(0,int(cost[r])-int(s.players[player].hand[r])))
	return _amounts(short)

## "2 Wool, 1 Ore" as a wire argument that each client renders in its language.
static func _amounts(amounts: Array) -> Dictionary:
	var parts=[]
	for r in 5:
		if int(amounts[r])>0:parts.append({"key":"%d %s","args":[int(amounts[r]),CatanI18n.term(RES[r])]})
	return {"list":parts}

func cost_error(player: int,kind: String) -> String:
	var keys={"ship":"To build a ship, you still need %s.","road":"To build a road, you still need %s.","settlement":"To build a settlement, you still need %s.","city":"To upgrade to a city, you still need %s.","buy_card":"To buy a development card, you still need %s."}
	return CatanI18n.message(keys[kind],[_missing(player,COST[kind])])
