extends RefCounted
# Cosmetic errands only: walk the owner's road graph, never cross another town.
# One resident per disjoint route keeps the island quiet and avoids opposing traffic.
func routes(state: Dictionary) -> Array:
	var graph={}
	for e in state.edges:
		if e.owner<0:continue
		for pair in [[e.a,e.b],[e.b,e.a]]:
			if not graph.has(pair[0]):graph[pair[0]]=[]
			graph[pair[0]].append([pair[1],e.owner])
	var result=[];var used_edges={};var used_towns={}
	for start in state.vertices.size():
		var owner=state.vertices[start].owner
		if owner<0 or used_towns.has(start):continue
		var queue=[start];var previous={start:-1};var finish=-1
		while not queue.is_empty() and finish<0:
			var current=queue.pop_front()
			for neighbor in graph.get(current,[]):
				var next: int=neighbor[0]
				var edge=Vector2i(mini(current,next),maxi(current,next))
				if neighbor[1]!=owner or previous.has(next) or used_edges.has(edge):continue
				var town_owner=state.vertices[next].owner
				if town_owner>=0:
					if town_owner==owner and not used_towns.has(next):
						previous[next]=current;finish=next;break
					continue
				previous[next]=current;queue.append(next)
		if finish<0:continue
		var path=[finish]
		while path[0]!=start:path.push_front(previous[path[0]])
		for i in range(1,path.size()):used_edges[Vector2i(mini(path[i-1],path[i]),maxi(path[i-1],path[i]))]=true
		used_towns[start]=true;used_towns[finish]=true
		result.append({"owner":owner,"vertices":path})
	return result

func assign(state: Dictionary,residents: Dictionary,parent: Node3D):
	for route in routes(state):
		var path: Array=route.vertices
		var styles=state.get("piece_styles",[])
		var style=int(styles[route.owner]) if route.owner<styles.size() else 0
		var deck=CatanCosmetics.road_deck_height(style)
		var points=PackedVector3Array()
		for vid in path:
			var vertex=state.vertices[vid]
			points.append(Vector3(vertex.x,deck,vertex.z))
		# Arrive at the town entrance rather than cutting through houses or towers.
		var start_radius=.34 if state.vertices[path[0]].level==2 else .29
		var end_radius=.34 if state.vertices[path[-1]].level==2 else .29
		var first=points[0]+(points[1]-points[0]).normalized()*(start_radius+.015)
		var last=points[-1]+(points[-2]-points[-1]).normalized()*(end_radius+.015)
		points[0]=first;points[-1]=last
		var lengths=PackedFloat32Array();var total=0.0
		for i in range(1,points.size()):
			var length=points[i-1].distance_to(points[i]);lengths.append(length);total+=length
		var actor: Dictionary=residents[path[0]]
		actor.root.reparent(parent)
		actor.root.scale=Vector3(.34,.348,.34)
		actor.root.name="RoadDweller"+str(path[0])
		actor["route"]={"points":points,"lengths":lengths,"length":total,"vertices":path}
		actor.index=path[0]

static func sample(route: Dictionary,distance: float) -> Vector3:
	distance=clampf(distance,0,route.length)
	for i in route.lengths.size():
		if distance<=route.lengths[i]:return route.points[i].lerp(route.points[i+1],distance/maxf(.0001,route.lengths[i]))
		distance-=route.lengths[i]
	return route.points[-1]
