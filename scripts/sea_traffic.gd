class_name CatanSeaTraffic
extends RefCounted
# Routes use scenery coordinates, including the larger six-player island scale.
var grid=AStarGrid2D.new()
var rng=RandomNumberGenerator.new()
var board
var fleet=[]
var ports=[]
const STEP=.20
const LIMIT=9.0
func configure(value):
	board=value;fleet.clear();ports.clear();rng.seed=9047
	grid.region=Rect2i(0,0,91,91);grid.cell_size=Vector2.ONE*STEP
	grid.offset=Vector2(-LIMIT,-LIMIT)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var obstacles=[]
	for child in board.scenery.get_children():
		if child is MeshInstance3D:
			var bounds=child.get_aabb();var p=child.position
			obstacles.append(Vector3(p.x,p.z,maxf(bounds.size.x*child.scale.x,bounds.size.z*child.scale.z)*.5+.43))
	# The lighthouse outcrop is a nested mesh rather than a direct scenery child.
	obstacles.append(Vector3(-5,-2.4,.95))
	for harbor in board.harbors:
		var berth=board.scenery.to_local(harbor.to_global(Vector3(-.58,0,1.20)))
		ports.append(Vector2(berth.x,berth.z))
	for x in 91:
		for y in 91:
			var p=grid.get_point_position(Vector2i(x,y));var land=false
			var terrain_p=p*board.board_scale
			for tile in board.state.tiles:
				var q=terrain_p-Vector2(tile.x,tile.z)
				if maxf(absf(q.x),maxf(absf(q.x*.5+q.y*.866),absf(-q.x*.5+q.y*.866)))<.866+.45*board.board_scale:
					land=true;break
			if not land:
				for obstacle in obstacles:
					if p.distance_to(Vector2(obstacle.x,obstacle.y))<obstacle.z:land=true;break
			if not land:
				for harbor in board.harbors:
					var q=harbor.to_local(board.scenery.to_global(Vector3(p.x,0,p.y)))
					if q.x>-.36 and q.x<.70 and q.z>-.2 and q.z<1.10:land=true;break
			grid.set_point_solid(Vector2i(x,y),land)
	for i in board.boats.size():
		var boat=board.boats[i]
		var cell=nearest(Vector2(boat.position.x,boat.position.z))
		var p=grid.get_point_position(cell);boat.position.x=p.x;boat.position.z=p.y
		fleet.append({"boat":boat,"path":PackedVector2Array(),"step":0,"wait":float(i)*5,"port":-1,"visit_next":i!=0,"speed":0.0,"visits":0})
	for ship in fleet:plan(ship)
func cell_for(p: Vector2) -> Vector2i:
	return Vector2i(roundi((p.x+LIMIT)/STEP),roundi((p.y+LIMIT)/STEP)).clamp(Vector2i.ZERO,Vector2i(90,90))
func nearest(p: Vector2) -> Vector2i:
	var cell=cell_for(p)
	if not grid.is_point_solid(cell):return cell
	for radius in range(1,25):
		for x in range(-radius,radius+1):
			for y in range(-radius,radius+1):
				if maxi(absi(x),absi(y))!=radius:continue
				var q=cell+Vector2i(x,y)
				if grid.region.has_point(q) and not grid.is_point_solid(q):return q
	return cell
func plan(ship: Dictionary):
	var boat=ship.boat;var start=nearest(Vector2(boat.position.x,boat.position.z))
	var candidates=[]
	if ship.visit_next:
		for i in ports.size():
			if fleet.any(func(other):return other!=ship and other.port==i):continue
			candidates.append(i)
	for attempt in 20:
		var port=-1;var target: Vector2
		if not candidates.is_empty():
			port=candidates[rng.randi_range(0,candidates.size()-1)];target=ports[port]
		else:
			var a=rng.randf_range(0,TAU);target=Vector2(cos(a),sin(a))*rng.randf_range(4.8,6.6)
		var end=nearest(target)
		var path=grid.get_point_path(start,end)
		if path.size()<3:continue
		ship.path=path;ship.step=1;ship.port=port;ship.visit_next=port<0
		return
	ship.wait=5.0
func animate(delta: float,time: float):
	if delta<=0:return
	for i in fleet.size():
		var ship=fleet[i];var boat=ship.boat
		if ship.wait>0:
			ship.wait=maxf(0,ship.wait-delta)
			ship.speed=move_toward(ship.speed,0,delta*.2)
			if ship.wait==0:plan(ship)
		elif ship.step<ship.path.size():
			var p=Vector2(boat.position.x,boat.position.z)
			var target=ship.path[ship.step];var distance=p.distance_to(target)
			var remaining=p.distance_to(ship.path[-1])
			var speed=minf(.15,maxf(.035,remaining*.22)) if ship.port>=0 else .15
			ship.speed=move_toward(ship.speed,speed,delta*.045)
			var travel=minf(distance,ship.speed*delta)
			var next=p.move_toward(target,travel)
			# Yield to another vessel already crossing this bow, with stable priority.
			for j in i:
				var other=fleet[j].boat;var q=Vector2(other.position.x,other.position.z)
				if next.distance_to(q)<.85 and next.distance_to(q)<p.distance_to(q):next=p;break
			boat.position.x=next.x;boat.position.z=next.y
			if next.distance_to(p)>.00001:
				var heading=atan2(-(next.x-p.x),-(next.y-p.y))
				boat.rotation.y=lerp_angle(boat.rotation.y,heading,1-exp(-delta*2.0))
			if next.distance_to(target)<.006:
				ship.step+=1
				if ship.step>=ship.path.size():
					if ship.port>=0:ship.visits+=1
					ship.wait=rng.randf_range(9,17) if ship.port>=0 else rng.randf_range(3,7)
		boat.position.y=-.27/board.scenery.scale.y+.055+sin(time*.7+i)*.012
		boat.rotation.z=sin(time*.8+i)*.025
		boat.rotation.x=sin(time*.6+i*1.7)*.012
