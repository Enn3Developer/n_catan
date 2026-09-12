extends RefCounted
# A small pool of visitors, each with its own route and rest schedule.
const MODEL=preload("res://assets/premium/seagull.glb")
const COUNT=6
const MODEL_SCALE=.32
var board
var flock=[]
var perches=[]
var reduced_last=false

func setup(value):
	board=value
	for i in COUNT:
		var root=Node3D.new();root.name="Seagull%d"%i;board.scenery.add_child(root)
		var model=MODEL.instantiate();root.add_child(model)
		var rng=RandomNumberGenerator.new();rng.seed=8127+i*7919
		model.scale=Vector3.ONE*MODEL_SCALE*rng.randf_range(.9,1.08)
		var bird={"root":root,"model":model,"id":i,"rng":rng,"state":"away","wait":float(i*7),"perch":-1,
			"phase":rng.randf()*TAU,"wing_cycle":rng.randf_range(6,10),"fold":0.0,"flap":0.0,"legs":0,
			"progress":0.0,"duration":1.0,"heading":Vector3.FORWARD,"points":PackedVector3Array()}
		for part in ["WingLeft","WingRight","WristLeft","WristRight","Head","Feet"]:
			bird[part]=model.find_child(part,true,false)
		bird["feathers"]=model.find_children("*","MeshInstance3D",true,false).filter(func(part):return part.mesh.get_blend_shape_count()>0)
		root.hide();flock.append(bird);board.birds.append(root)

func configure():
	# Harbours are rebuilt with the board. Store positions, never their freed nodes.
	perches.clear();reduced_last=false
	for harbor in board.harbors:
		var p=board.scenery.to_local(harbor.to_global(Vector3(-.135,.140,.72)))
		var outward=(board.scenery.global_basis.inverse()*harbor.global_basis.z).normalized()
		perches.append({"position":p,"outward":outward,"owner":-1})
	for bird in flock:
		bird.root.hide();bird.state="away";bird.perch=-1;bird.fold=0.0
		bird.wait=bird.rng.randf_range(12,32)+bird.id*4
	if not perches.is_empty():_rest(flock[0],0)
	for i in [1,2]:
		var bird=flock[i];var angle=bird.rng.randf()*TAU
		bird.root.position=_offshore(angle,bird.rng.randf_range(6,8),bird.rng.randf_range(1.8,2.7))
		bird.root.show();bird.heading=Vector3(-sin(angle),0,cos(angle));bird.legs=0
		_cruise(bird)

func _offshore(angle: float,radius: float,height: float) -> Vector3:
	return Vector3(cos(angle)*radius,height,sin(angle)*radius)

func _release(bird: Dictionary):
	if bird.perch>=0 and bird.perch<perches.size() and perches[bird.perch].owner==bird.id:
		perches[bird.perch].owner=-1
	bird.perch=-1

func _rest(bird: Dictionary,index: int):
	_release(bird);bird.perch=index;perches[index].owner=bird.id
	bird.state="perched";bird.wait=bird.rng.randf_range(12,32)
	bird.root.position=perches[index].position-Vector3.UP*.008*bird.model.scale.y
	bird.heading=-perches[index].outward;bird.root.rotation=Vector3(0,atan2(-bird.heading.x,-bird.heading.z),0)
	bird.root.show()

func _free_perch(bird: Dictionary) -> int:
	var candidates=[]
	for i in perches.size():
		if perches[i].owner<0:candidates.append(i)
	if candidates.is_empty():return -1
	return candidates[bird.rng.randi_range(0,candidates.size()-1)]

func _leg(bird: Dictionary,target: Vector3,state: String,speed: float,arrival: Vector3=Vector3.ZERO):
	var start: Vector3=bird.root.position
	var distance=start.distance_to(target)
	var incoming: Vector3=bird.heading.normalized()
	if incoming.length_squared()<.1:incoming=(target-start).normalized()
	if arrival==Vector3.ZERO:arrival=(target-start).normalized()
	var reach=minf(distance*.32,3.0)
	bird.points=PackedVector3Array([start,start+incoming*reach,target-arrival*reach,target])
	bird.progress=0.0;bird.duration=maxf(1.0,distance/speed);bird.state=state

func _arrive(bird: Dictionary):
	var angle=bird.rng.randf()*TAU
	bird.root.position=_offshore(angle,22,bird.rng.randf_range(2.5,3.5));bird.root.show()
	var target=_offshore(angle+bird.rng.randf_range(-.4,.4),7,bird.rng.randf_range(1.8,2.8))
	bird.heading=(target-bird.root.position).normalized();bird.legs=0;bird.fold=0
	_leg(bird,target,"arriving",bird.rng.randf_range(.85,1.15))

func _cruise(bird: Dictionary):
	var p: Vector3=bird.root.position
	var angle=atan2(p.z,p.x)+bird.rng.randf_range(.65,1.75)*(1 if bird.id%2==0 else -1)
	var target=_offshore(angle,bird.rng.randf_range(5.8,8.4),bird.rng.randf_range(1.7,3.0))
	var tangent=Vector3(-sin(angle),0,cos(angle))*(1 if bird.id%2==0 else -1)
	_leg(bird,target,"flying",bird.rng.randf_range(.7,1.05),tangent)
	bird.legs+=1

func _skim(bird: Dictionary):
	# Start outside the island before descending, away from roofs and the lighthouse.
	var p: Vector3=bird.root.position;var angle=atan2(p.z,p.x)
	_leg(bird,_offshore(angle,9.2,1.6),"skim_approach",.9)

func _approach(bird: Dictionary,index: int):
	_release(bird);bird.perch=index;perches[index].owner=bird.id
	var perch=perches[index]
	_leg(bird,perch.position+perch.outward*1.3+Vector3.UP*.9,"approaching",.75,-perch.outward)

func _land(bird: Dictionary):
	if bird.perch<0:_cruise(bird);return
	var perch=perches[bird.perch]
	var target: Vector3=perch.position-Vector3.UP*.008*bird.model.scale.y
	_leg(bird,target,"landing",.32,-perch.outward)
	bird.points[1]=bird.points[0]-perch.outward*.45
	bird.points[2]=target+perch.outward*.25+Vector3.UP*.10

func _take_off(bird: Dictionary):
	var outward: Vector3=perches[bird.perch].outward if bird.perch>=0 else bird.root.position.normalized()
	_release(bird);bird.heading=outward
	var target: Vector3=bird.root.position+outward*2.4+Vector3.UP*1.6
	_leg(bird,target,"takeoff",.7,outward)
	bird.points[1]=bird.points[0]+Vector3.UP*.65+outward*.3
	bird.legs=0

func _leave(bird: Dictionary):
	if bird.state=="perched":_take_off(bird);return
	var p: Vector3=bird.root.position
	var outward=Vector3(p.x,0,p.z).normalized()
	_release(bird)
	_leg(bird,Vector3(outward.x*25,3.4,outward.z*25),"leaving",1.3,outward)
	# Climb clear of the harbour before heading offshore.
	bird.points[1].y=maxf(bird.points[1].y,p.y+.7)

func _finish(bird: Dictionary):
	match bird.state:
		"leaving":
			bird.state="away";bird.root.hide();bird.wait=bird.rng.randf_range(25,65)
		"approaching":_land(bird)
		"landing":_rest(bird,bird.perch)
		"skim_approach":
			var p: Vector3=bird.root.position;var angle=atan2(p.z,p.x)+.45*(1 if bird.id%2==0 else -1)
			_leg(bird,_offshore(angle,9.5,.22),"skimming",.8)
		"skimming":_cruise(bird)
		_:
			var index=_free_perch(bird)
			if bird.legs>=2 and bird.rng.randf()<.55 and index>=0:_approach(bird,index)
			elif bird.legs>=4 or bird.rng.randf()<.16:_leave(bird)
			elif bird.state=="flying" and bird.rng.randf()<.24:_skim(bird)
			else:_cruise(bird)

static func curve(points: PackedVector3Array,t: float) -> Vector3:
	var u=1.0-t
	return points[0]*u*u*u+points[1]*3*u*u*t+points[2]*3*u*t*t+points[3]*t*t*t

static func direction(points: PackedVector3Array,t: float) -> Vector3:
	return (points[1]-points[0])*3*pow(1.0-t,2)+(points[2]-points[1])*6*(1.0-t)*t+(points[3]-points[2])*3*t*t

func _pose(bird: Dictionary,delta: float,time: float):
	var resting=bird.state=="perched"
	var folding=resting or (bird.state=="landing" and bird.progress>.88)
	bird.fold=move_toward(bird.fold,1.0 if folding else 0.0,delta*2.8)
	var powered=bird.state in ["takeoff","landing","arriving"] or fposmod(time+bird.phase,bird.wing_cycle)<2.1
	bird.flap=lerpf(bird.flap,1.0 if powered and not resting else 0.0,1.0-exp(-delta*4.0))
	var beat=time*TAU*2.0+bird.phase
	for side in [-1,1]:
		var shoulder: Node3D=bird.WingLeft if side<0 else bird.WingRight
		var wrist: Node3D=bird.WristLeft if side<0 else bird.WristRight
		shoulder.rotation=Vector3(0,0,side*(.08+sin(beat)*.52*bird.flap)*(1-bird.fold))
		wrist.rotation=Vector3(0,0,side*sin(beat-.65)*.16*bird.flap*(1-bird.fold))
	for feathers in bird.feathers:feathers.set_blend_shape_value(0,bird.fold)
	bird.Feet.visible=resting or (bird.state=="landing" and bird.progress>.5) or (bird.state=="takeoff" and bird.progress<.25)
	bird.Head.rotation.y=sin(time*.6+bird.phase)*.24 if resting else 0.0

func animate(delta: float,time: float,daylight: float,conditions: Dictionary,reduced: bool):
	var retreat=daylight<.2 or float(conditions.get("storm",0))>.35
	if reduced:
		if not reduced_last:
			for bird in flock:
				_release(bird);bird.root.hide();bird.state="away"
			for i in mini(3,perches.size()):
				_rest(flock[i],i);flock[i].fold=1.0;_pose(flock[i],0,0)
		for bird in flock:bird.root.visible=bird.state=="perched" and not retreat
		reduced_last=true;return
	reduced_last=false
	if delta<=0:return
	var limit=3 if float(conditions.get("rain",0))>.2 else 5
	var visible_count=flock.filter(func(bird):return bird.state!="away").size()
	for bird in flock:
		if bird.state=="away":
			bird.wait-=delta
			if bird.wait<=0 and not retreat and visible_count<limit:
				_arrive(bird);visible_count+=1
			continue
		bird.root.show()
		if retreat and bird.state not in ["leaving","takeoff","perched"]:_leave(bird)
		if bird.state=="perched":
			if retreat:bird.wait=minf(bird.wait,1.4)
			bird.wait-=delta
			if bird.wait<2.0:
				var outward: Vector3=perches[bird.perch].outward
				var heading=atan2(-outward.x,-outward.z)
				bird.root.rotation.y=lerp_angle(bird.root.rotation.y,heading,1-exp(-delta*3.5))
			if bird.wait<=0:_take_off(bird)
		else:
			bird.progress=minf(1.0,bird.progress+delta/bird.duration)
			var t: float=bird.progress
			if bird.state=="landing":t=1-pow(1-t,1.5)
			elif bird.state=="takeoff":t=pow(t,1.2)
			bird.root.position=curve(bird.points,t)
			var heading=direction(bird.points,t).normalized()
			bird.heading=heading
			var yaw=atan2(-heading.x,-heading.z)
			var turn=wrapf(yaw-bird.root.rotation.y,-PI,PI)
			var bank=clampf(-turn/maxf(delta,.001)*.18,-.42,.42)
			if bird.state=="landing":bank=0.0
			bird.root.rotation=Vector3(asin(clampf(heading.y,-.4,.4)),yaw,lerpf(bird.root.rotation.z,bank,1-exp(-delta*3)))
			if bird.progress>=1.0:
				if retreat and bird.state!="leaving":_leave(bird)
				else:_finish(bird)
		_pose(bird,delta,time)
