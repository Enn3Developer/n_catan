extends RefCounted
# All dimensions are in normalized tile units; the board maps each unit to 25 m.
# Models come from assets/source/actors.blend and settlements.blend. Pivot nodes
# keep identity rest rotations, so the animation below drives them directly.
var tint=CatanModelTint.new()
var night_glow: StandardMaterial3D
const TILE_ACTOR_SCALE=.4
const SHEEP=preload("res://assets/models/actors/sheep.glb")
const OUTLAW=preload("res://assets/models/actors/outlaw.glb")
const DWELLER=preload("res://assets/models/actors/dweller.glb")
const WORKERS={0:preload("res://assets/models/actors/woodcutter.glb"),1:preload("res://assets/models/actors/quarry_worker.glb"),3:preload("res://assets/models/actors/farmer.glb"),4:preload("res://assets/models/actors/quarry_worker.glb")}
const WORKSITES={0:preload("res://assets/models/settlements/worksite_stump.glb"),1:preload("res://assets/models/settlements/worksite_clay.glb"),4:preload("res://assets/models/settlements/worksite_stone.glb")}
const COTTAGE=preload("res://assets/models/settlements/cottage.glb")
const HARBOR=preload("res://assets/models/settlements/harbor.glb")
const CAMP=preload("res://assets/models/settlements/robber_camp.glb")
const SHIRTS=[Color("728568"),Color("b77453"),Color("c6b48b"),Color("b39a65"),Color("6d8190")]
const OUTLAW_SHIRT=Color("444c49")

func sheep() -> Dictionary:
	var root: Node3D=SHEEP.instantiate();root.name="GrazingSheep"
	var body=root.get_node("Body")
	var legs=[];var knees=[]
	for i in 4:
		legs.append(body.get_node("Leg%d"%i));knees.append(body.get_node("Leg%d/Knee%d"%[i,i]))
	var head=body.get_node("Neck")
	return {"root":root,"body":body,"limbs":legs,"knees":knees,"head":head,"ears":[head.get_node("Ear0"),head.get_node("Ear1")],"tail":body.get_node("Tail"),"type":"sheep"}

func worker(kind: int,bandit: bool=false) -> Dictionary:
	var root: Node3D=(OUTLAW if bandit else WORKERS[kind]).instantiate()
	root.name="HoodedOutlaw" if bandit else "Farmer" if kind==3 else "Woodcutter" if kind==0 else "QuarryWorker"
	tint.paint(root,OUTLAW_SHIRT if bandit else SHIRTS[mini(kind,4)],"Shirt")
	var body=root.get_node("Torso")
	var legs=[];var knees=[];var arms=[];var elbows=[]
	for i in 2:
		legs.append(root.get_node("Thigh%d"%i));knees.append(root.get_node("Thigh%d/Knee%d"%[i,i]))
		arms.append(body.get_node("UpperArm%d"%i));elbows.append(body.get_node("UpperArm%d/Forearm%d"%[i,i]))
	return {"root":root,"body":body,"head":body.get_node("Head"),"limbs":legs,"knees":knees,"arms":arms,"elbows":elbows,"tool":body.get_node("Tool"),"grips":[Vector3(0,.018,0),Vector3(0,-.017,0)],"type":"bandit" if bandit else "worker"}

# Two-bone arm solve: both hands stay on the handle throughout the stroke.
func reach(arm: Node3D,elbow: Node3D,target: Vector3,side: float):
	var delta=target-arm.position
	var distance=clampf(delta.length(),.005,.0845)
	var direction=delta.normalized()
	var bend=Vector3(side,.0,.4)
	bend=(bend-direction*bend.dot(direction)).normalized()
	var along=(.042*.042-.043*.043+distance*distance)/(2*distance)
	var joint=direction*along+bend*sqrt(maxf(0,.042*.042-along*along))
	arm.quaternion=Quaternion(Vector3.DOWN,joint.normalized())
	elbow.quaternion=Quaternion(Vector3.DOWN,arm.quaternion.inverse()*(direction*distance-joint).normalized())

func populate(parent: Node3D,kind: int,index: int,art) -> Array:
	var entries=[]
	if kind>=5:return entries
	var layout=CatanWorldLayout.biome(kind)
	if layout.cottage!=null:
		var hut=layout.cottage
		var at=Vector2(hut[0],hut[1])
		var house: Node3D=COTTAGE.instantiate();house.name="TimberHouse"
		house.position=Vector3(at.x,art.height_at(at,kind)-.006,at.y);house.scale=Vector3.ONE*hut[2]
		parent.add_child(house,true);wire_lights(house)
	for i in layout.workers.size():
		var entry=sheep() if kind==2 else worker(kind)
		var origin=CatanWorldLayout.point(layout.workers[i])
		entry.merge({"origin":origin,"kind":kind,"phase":index*.71+i*1.8,"home":CatanWorldLayout.point(layout.homes[i]),"path":CatanWorldLayout.travel_path(kind,i)})
		parent.add_child(entry.root)
		entry.root.scale=Vector3.ONE*TILE_ACTOR_SCALE
		if WORKSITES.has(kind):
			var worksite: Node3D=WORKSITES[kind].instantiate();worksite.name="Worksite"
			worksite.position=Vector3(origin.x,art.height_at(origin,kind),origin.y)
			worksite.scale=Vector3.ONE*TILE_ACTOR_SCALE
			parent.add_child(worksite,true)
		entries.append(entry)
	animate(entries,0,art)
	return entries

func animate(entries: Array,time: float,art,daylight: float=1.0):
	for actor in entries:
		if actor.type=="sheep":animate_sheep(actor,time,art,daylight)
		else:animate_worker(actor,time,art,daylight)

# A smooth 0→1→0 bump between a and b, peaking in the middle.
static func pulse(x: float,a: float,b: float) -> float:
	return sin(PI*clampf((x-a)/(b-a),0,1))

# Now and then, a short burst: 1 for a fraction of each period, eased in and out.
static func now_and_then(t: float,period: float,length: float) -> float:
	return pulse(fposmod(t,period),0,length)

func animate_sheep(actor: Dictionary,time: float,art,daylight: float):
	var t=time+actor.phase
	# Six seconds to amble between patches, then ten seconds with planted feet.
	# A cosine ease makes both velocity and heading continuous at each stop.
	var cycle=fposmod(t,32.0)
	var returning=cycle>=16.0
	var local=fposmod(cycle,16.0)
	var progress=(1.0-cos(PI*clampf(local/6.0,0,1)))*.5
	var travel=1.0-progress if returning else progress
	var direction=Vector2(cos(actor.phase),sin(actor.phase))
	var point=(actor.origin+direction*(travel-.5)*.12).lerp(actor.home,1.0-daylight)
	actor.root.position=Vector3(point.x,art.height_at(point,actor.kind)+.003,point.y)
	var facing=atan2(-direction.x,-direction.y)
	# Turn to the next patch while standing, before setting off again.
	var turn=smoothstep(14.0,16.0,local)
	actor.root.rotation.y=lerp_angle(PI,facing+(PI if returning else 0.0)+turn*PI,smoothstep(.08,.4,daylight))
	var moving=sin(PI*clampf(local/6.0,0,1))*daylight
	var stride=progress*TAU*3.0
	var rest=1.0-smoothstep(.08,.4,daylight)
	# Walk: hind then fore on one side, then the other, each foot lifted as it swings.
	const GAIT=[PI*.5,0.0,PI*1.5,PI]
	var breathe=sin(t*1.9)*.0012*(1.0-moving)
	actor.body.position.y=.070-rest*.042+absf(sin(stride*2))*.0016*moving+breathe
	actor.body.rotation.z=sin(stride)*.035*moving
	actor.body.rotation.x=sin(stride*2)*.02*moving
	for i in 4:
		var gait=stride+GAIT[i]
		# Lying down, every hoof tucks under the belly: fore shins fold back, hind shins forward.
		var tuck=-1.0 if actor.limbs[i].position.z>0 else 1.0
		actor.limbs[i].rotation.x=sin(gait)*.42*moving+rest*.35*tuck
		actor.knees[i].rotation.x=-maxf(0,cos(gait))*.62*moving-rest*2.6*tuck
	# Graze: lower the head, nibble in short bobs, lift it to chew and look about.
	var graze=smoothstep(6.0,7.5,local)*(1.0-smoothstep(12.0,13.5,local))*daylight
	var nibble=maxf(0,sin(t*7.5))*.10*graze*(1.0-now_and_then(t,4.3,1.4))
	var chew=sin(t*9.0)*.03*(1.0-graze)*(1.0-moving)*daylight
	var look=sin(t*.55)*.25*(1.0-graze)*(1.0-rest)*(1.0-moving*.6)
	actor.head.rotation.x=-.10-graze*.95-rest*.30+nibble+sin(stride*2)*.06*moving+chew
	actor.head.rotation.y=look
	actor.head.position.y=.005
	# Tail wags in bursts; ears flick one at a time.
	actor.tail.rotation.x=(.15+sin(t*14.0)*.35*now_and_then(t+actor.phase,5.7,.9))*daylight
	for i in 2:
		var flick=now_and_then(t*(1.0+i*.13)+i*2.1,3.9+i*1.3,.35)
		actor.ears[i].rotation.z=(sin(t*1.3+i*2.0)*.06+flick*.5*(1 if i==0 else -1))*daylight

func animate_worker(actor: Dictionary,time: float,art,daylight: float):
	var t=time+actor.phase
	var bandit=actor.type=="bandit"
	var point=actor.origin.lerp(actor.get("home",actor.origin),1.0-daylight)
	if not actor.get("path",[]).is_empty():point=CatanWorldLayout.along_path(actor.path,1.0-daylight)
	actor.root.position=Vector3(point.x,art.height_at(point,actor.kind)+.003,point.y)
	actor.root.visible=bandit or daylight>.03
	actor.root.rotation=Vector3.ZERO
	if bandit:
		guard_pose(actor,t,daylight)
		return
	# Walking to and from work happens at dusk and dawn; the tool rides on the shoulder.
	var commute=sin(PI*daylight)
	var working=daylight*(1.0-commute)
	var cycle=fposmod(t*(.88+fposmod(actor.phase,.23)),5.6)
	var pose: Dictionary
	if actor.kind==3:pose=rake_pose(cycle,working)
	else:pose=strike_pose(actor,cycle,working)
	# Idle life on top of the work: breathing and the odd glance aside.
	var breathe=sin(t*1.6)*.0008
	var glance=now_and_then(t,11.0+fposmod(actor.phase,3.0),2.2)*(1.0-pose.effort)
	var walk=t*5.2
	var drop=pose.squat*working
	actor.body.position.y=.079-drop+breathe-absf(sin(walk))*.0025*commute
	actor.body.rotation=Vector3(-pose.lean*working+.05*commute,pose.twist*working+sin(walk)*.06*commute,cos(walk)*.03*commute)
	actor.head.rotation=Vector3(.12+pose.nod*working-.08*commute,glance*.55*sin(t*.4+actor.phase),0)
	# Carry the tool over the right shoulder while walking.
	var carry=Transform3D(Basis(Vector3.RIGHT,.95)*Basis(Vector3.BACK,-.25),Vector3(.036,.118,-.018))
	var tool: Transform3D=pose.tool.interpolate_with(carry,commute)
	actor.tool.transform=actor.body.transform.affine_inverse()*tool
	for i in 2:
		var grip=actor.tool.transform*actor.grips[i].lerp([Vector3(0,-.030,0),Vector3(0,-.004,0)][i],commute)
		reach(actor.arms[i],actor.elbows[i],grip,-1.0 if i==0 else 1.0)
	_legs(actor,drop,.05*(1.0-commute),walk,commute)

## Bends both knees to lower the hips by drop, keeping the feet under the body,
## and walks with the given stride phase and amount.
func _legs(actor: Dictionary,drop: float,spread: float,walk: float,amount: float):
	var squat=acos(clampf(1.0-drop/.079,0.0,1.0))
	for i in 2:
		var gait=walk+i*PI
		actor.limbs[i].position.y=.079-drop
		actor.limbs[i].rotation.x=squat+sin(gait)*.42*amount
		actor.limbs[i].rotation.z=spread*(-1.0 if i==0 else 1.0)
		actor.knees[i].rotation.x=-squat*2.0-maxf(0,cos(gait))*.75*amount

# The head lies in the swing plane. Solve the impact from the cutting edge/tip,
# then key the handle through a wind-up over the right shoulder, a fast fall into
# the contact, a short jolt, and a pull back to the ready pose.
func strike_pose(actor: Dictionary,cycle: float,working: float) -> Dictionary:
	var axe=actor.kind==0
	var tip=Vector3(0,.084,-.038) if axe else Vector3(0,.069,-.052)
	var contact=Vector3(0,.044 if axe else .0345,-.14)
	var impact_angle=-1.9 if axe else -1.85
	var impact_origin=contact-Basis(Vector3.RIGHT,impact_angle)*tip
	# Keys: time, handle origin, handle pitch, roll, torso lean, twist, squat, head nod, grip slide.
	var keys=[
		[0.0,Vector3(.010,.118,-.046),-.55,0.0,.02,0.0,.004,.10,0.0],
		[.35,Vector3(.010,.118,-.046),-.55,0.0,.02,0.0,.004,.10,0.0],
		[1.25,Vector3(.034,.176,-.024),.30,-.40,-.06,.22,.0,-.10,0.0],
		[1.62,Vector3(.036,.184,-.018),.40,-.45,-.08,.26,.0,-.14,0.0],
		[2.02,impact_origin,impact_angle,0.0,.26,-.04,.012,.30,1.0],
		[2.10,impact_origin+Vector3(0,.003,.001),impact_angle+.04,0.0,.24,-.04,.013,.28,1.0],
		[2.45,impact_origin,impact_angle,0.0,.24,-.03,.012,.28,1.0],
		[2.90,impact_origin+Vector3(0,.022,.012),impact_angle+.35,0.0,.16,0.0,.010,.20,.6],
		[4.20,Vector3(.010,.118,-.046),-.55,0.0,.02,0.0,.004,.10,0.0],
		[5.60,Vector3(.010,.118,-.046),-.55,0.0,.02,0.0,.004,.10,0.0]]
	var k=0
	while k<keys.size()-2 and cycle>=keys[k+1][0]:k+=1
	var a=keys[k];var b=keys[k+1]
	var x=clampf((cycle-a[0])/maxf(.0001,b[0]-a[0]),0,1)
	# The downswing accelerates into the hit; every other move eases.
	x=x*x if k==3 else x*x*(3.0-2.0*x)
	var origin: Vector3=a[1].lerp(b[1],x)
	var pitch=lerpf(a[2],b[2],x)
	var roll=lerpf(a[3],b[3],x)
	var slide=lerpf(a[8],b[8],x)
	actor.grips=[Vector3(0,lerpf(.022,-.014,slide),0),Vector3(0,-.033,0)]
	var rest=Transform3D(Basis(Vector3.RIGHT,-.55),Vector3(.010,.118,-.046))
	var tool=rest.interpolate_with(Transform3D(Basis(Vector3.BACK,roll)*Basis(Vector3.RIGHT,pitch),origin),working)
	return {"tool":tool,"lean":lerpf(a[4],b[4],x),"twist":lerpf(a[5],b[5],x),"squat":lerpf(a[6],b[6],x),"nod":lerpf(a[7],b[7],x),"effort":pulse(cycle,.3,4.3)}

# Rake hay: reach out, drag it back in two strokes, lift and reset.
func rake_pose(cycle: float,working: float) -> Dictionary:
	var stroke=fposmod(cycle,2.8)
	var reach_out=smoothstep(0,.9,stroke)*(1.0-smoothstep(1.0,2.2,stroke))
	var lift=pulse(stroke,2.2,2.8)
	var tool=Transform3D(Basis(Vector3.RIGHT,-2.10+reach_out*.30+lift*.25),Vector3(.004,.020+lift*.012,-.036-reach_out*.034))
	return {"tool":Transform3D(Basis(Vector3.RIGHT,-2.05),Vector3(.004,.019,-.039)).interpolate_with(tool,working),
		"lean":.14+reach_out*.22,"twist":sin(stroke/2.8*TAU)*.08,"squat":.005+reach_out*.009,"nod":.10+reach_out*.08,"effort":1.0}

# Outlaws stand guard around their fire: facing out by day with the sword on the
# shoulder, shifting their weight and scanning; turned to the fire by night.
func guard_pose(actor: Dictionary,t: float,daylight: float):
	var night=1.0-daylight
	var out=Vector2(actor.origin.x,actor.origin.y)
	var outward=atan2(-out.x,-out.y)
	actor.root.rotation.y=lerp_angle(outward,outward+PI,smoothstep(.2,.8,night))
	var shift=sin(t*.45)
	var scan=sin(t*.31+actor.phase)*.6*daylight
	var tap=now_and_then(t,7.0+fposmod(actor.phase,2.0),.8)
	actor.body.position.y=.079+sin(t*1.5)*.0008-absf(shift)*.002
	actor.body.rotation=Vector3(.03*night,scan*.35,shift*.035)
	actor.head.rotation=Vector3(.10+.18*night,scan*.65,-shift*.04)
	# Sword on the right shoulder, blade up behind it; it bounces when tapped.
	var shoulder=Transform3D(Basis(Vector3.BACK,-.3)*Basis(Vector3.RIGHT,.65+tap*.35),Vector3(.040,.098,-.020))
	actor.tool.transform=actor.body.transform.affine_inverse()*shoulder
	reach(actor.arms[1],actor.elbows[1],actor.tool.transform*Vector3(0,-.004,0),1.0)
	# The free hand rests on the hip, or warms at the fire at night.
	var hip=Vector3(-.046,.004,-.012).lerp(Vector3(-.018,.030,-.062),night)
	reach(actor.arms[0],actor.elbows[0],hip,-1.0)
	for i in 2:
		actor.limbs[i].position.y=.079-absf(shift)*.002
		actor.limbs[i].rotation=Vector3(0,0,(.06+shift*.03)*(-1.0 if i==0 else 1.0))
		actor.knees[i].rotation.x=-maxf(0,shift*(1 if i==0 else -1))*.12

func town(look: PackedByteArray,color: Color,city: bool,parity: int=0,full_detail: bool=true) -> Node3D:
	var root: Node3D=CatanPieceBuilder.town(look,color,city,parity,full_detail)
	root.name="MedievalCity" if city else "MedievalVillage"
	wire_lights(root)
	root.set_meta("dwellers",populate_town(root,city,color))
	return root

static var dweller_sole=NAN
const TOWN_DWELLER_HEIGHT=.29
const ROAD_DWELLER_HEIGHT=.348
## Height of the dweller's soles above its origin, before scaling, measured from
## the mesh itself. Bounding boxes are padded, so only the vertices are trusted.
static func sole_height() -> float:
	if is_nan(dweller_sole):
		var person: Node3D=DWELLER.instantiate()
		dweller_sole=INF
		for mesh: MeshInstance3D in person.find_children("*","MeshInstance3D",true,false):
			var to_root=Transform3D.IDENTITY
			var node: Node=mesh
			while node!=person:
				to_root=node.transform*to_root
				node=node.get_parent()
			for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				dweller_sole=minf(dweller_sole,(to_root*vertex).y)
		person.free()
	return dweller_sole

const SETTLEMENT_POPULATION=6
const CITY_POPULATION=16

func populate_town(town_root: Node3D,city: bool,color: Color) -> Array:
	var residents=[]
	var count=CITY_POPULATION if city else SETTLEMENT_POPULATION
	for i in count:
		var person: Node3D=DWELLER.instantiate();person.name="Dweller%02d"%i;town_root.add_child(person)
		# Adult height is roughly 1.8 m at the new world scale.
		person.scale=Vector3(.34,TOWN_DWELLER_HEIGHT,.34)
		tint.paint(person,[color,Color("b58a58"),Color("778868"),Color("b57865"),Color("718998")][i%5],"Shirt")
		tint.paint(person,[Color("d2a37e"),Color("b68160"),Color("916449")][i%3],"Skin")
		var body=person.get_node("Torso")
		body.get_node("Hat").visible=i%3==0
		var legs=[person.get_node("Leg0"),person.get_node("Leg1")]
		var arms=[body.get_node("Arm0"),body.get_node("Arm1")]
		var angle=TAU*i/count
		var radial=Vector2(sin(angle),cos(angle))
		var start=radial*(.114 if city else .082)
		var finish=radial*(.150 if city else .20 if radial.y>.1 else .11)
		residents.append({"root":person,"body":body,"limbs":legs,"arms":arms,"index":i,"origin":start,"destination":finish,"moving":false})
	animate_dwellers(residents,0,1)
	return residents

func animate_dwellers(residents: Array,time: float,daylight: float):
	for actor in residents:
		if actor.has("route"):
			_animate_road_dweller(actor,time,daylight)
			continue
		# Short errands stay within each resident's clear street corridor. Different
		# schedules keep most people chatting/resting while a few walk to another spot.
		var outward=actor.destination-actor.origin
		var duration=outward.length()/.024
		var wait_home=4.0+float(actor.index%5)*1.3
		var wait_away=6.0+float((actor.index*3)%7)*1.1
		var cycle=fposmod(time+actor.index*7.73,wait_home+wait_away+duration*2)
		var forward_yaw=atan2(-outward.x,-outward.y)
		var backward_yaw=forward_yaw+PI
		var progress=0.0;var moving=0.0;var yaw=forward_yaw
		if cycle<wait_home:
			yaw=lerp_angle(backward_yaw,forward_yaw,smoothstep(wait_home-.65,wait_home,cycle))
		elif cycle<wait_home+duration:
			var travel=(cycle-wait_home)/duration
			progress=smoothstep(0,1,travel);moving=sin(PI*travel)
		elif cycle<wait_home+duration+wait_away:
			progress=1.0
			var rest=cycle-wait_home-duration
			yaw=lerp_angle(forward_yaw,backward_yaw,smoothstep(wait_away-.65,wait_away,rest))
		else:
			var travel=(cycle-wait_home-duration-wait_away)/duration
			progress=1.0-smoothstep(0,1,travel);moving=sin(PI*travel);yaw=backward_yaw
		var position=actor.origin.lerp(actor.destination,progress)
		actor.root.position=Vector3(position.x,CatanPieceBuilder.GROUND_TOP-sole_height()*TOWN_DWELLER_HEIGHT,position.y)
		actor.root.rotation.y=yaw
		actor.root.visible=daylight>.15
		actor.moving=moving>.08
		_animate_dweller_stride(actor,time,moving)

func _animate_road_dweller(actor: Dictionary,time: float,daylight: float):
	var route: Dictionary=actor.route
	var duration=route.length/.045 # About 1.1 m/s at the island's world scale.
	var rest=12.0+float(actor.index%4)*3.0
	var cycle=fposmod(time+actor.index*7.73,2*(duration+rest))
	var returning=cycle>=duration+rest
	var local=cycle-(duration+rest if returning else 0.0)
	var moving=local<duration
	var distance=minf(local,duration)*.045
	if returning:distance=route.length-distance
	var position=preload("res://scripts/road_travel.gd").sample(route,distance)
	var ahead=preload("res://scripts/road_travel.gd").sample(route,clampf(distance+(-.015 if returning else .015),0,route.length))
	var direction=ahead-position
	if direction.length_squared()>.000001:actor.root.rotation.y=atan2(-direction.x,-direction.z)
	actor.root.position=position
	actor.root.visible=daylight>.15 and moving
	actor.moving=moving and daylight>.15
	_animate_dweller_stride(actor,time,1.0 if moving else 0.0)

func _animate_dweller_stride(actor: Dictionary,time: float,moving: float):
	var stride=time*4.6+actor.index*1.7
	var still=1.0-moving
	var t=time+actor.index*3.1
	# Walking: a bob at each step, hips sway over the planted foot, arms swing
	# against the legs. Standing: breathing, weight shifts and chatty gestures.
	var talk=now_and_then(t,6.0+float(actor.index%4),2.4)*still
	var shift=sin(t*.37)*still
	actor.body.position.y=.079-absf(sin(stride))*.0035*moving+sin(t*1.7)*.0006*still
	actor.body.rotation=Vector3(-.06*moving+sin(t*5.5)*.03*talk,sin(stride)*.09*moving+sin(t*.5)*.14*still,cos(stride)*.035*moving+shift*.03)
	for leg in 2:
		var swing=sin(stride+leg*PI)
		actor.limbs[leg].rotation=Vector3(swing*.42*moving,0,(.03+shift*.02)*(-1.0 if leg==0 else 1.0)*still)
		actor.arms[leg].rotation=Vector3(-swing*.38*moving,0,(.10 if leg==1 else -.10)*moving+(.06 if leg==1 else -.06)*still)
	# One hand talks, rising and turning over while they chat.
	actor.arms[0].rotation.x+=talk*(.9+sin(t*3.1)*.25)
	actor.arms[0].rotation.z-=talk*.25

func harbor(resource: int) -> Node3D:
	var root: Node3D=HARBOR.instantiate();root.name="CoastalHarbor";root.set_meta("resource",resource)
	wire_lights(root)
	return root

func glow_material() -> StandardMaterial3D:
	if night_glow==null:
		night_glow=StandardMaterial3D.new()
		night_glow.albedo_color=Color("665544")
		night_glow.emission_enabled=true
		night_glow.emission=Color("ffb55d")
		night_glow.emission_energy_multiplier=0.0
	return night_glow

# Authored lamps carry their reach and night energy as glTF extras. Every window,
# lantern and fire that glows at night records the lamp beside it.
func wire_lights(root: Node3D):
	for light in root.find_children("NightLight*","OmniLight3D",true,false):
		var extras: Dictionary=light.get_meta("extras",{})
		light.set_meta("local_range",extras.get("local_range",.38));light.set_meta("night_energy",extras.get("night_energy",4.0))
		light.light_color=Color("ffb765");light.omni_attenuation=1.5
		light.light_energy=0;light.shadow_enabled=false
	for emitter in root.find_children("*","MeshInstance3D",true,false):
		if not (str(emitter.name).begins_with("NightWindow") or str(emitter.name).begins_with("NightLantern") or str(emitter.name).begins_with("Campfire")):continue
		emitter.material_override=glow_material()
		var lamps=emitter.get_parent().find_children("NightLight*","OmniLight3D",true,false)
		if not lamps.is_empty():emitter.set_meta("night_light",lamps[0])

func robber_band(kind: int,art) -> Dictionary:
	var root: Node3D=CAMP.instantiate();root.name="RobberBand"
	# Stolen supplies and a small hearth keep the blocking piece identifiable.
	for part in root.get_children():part.position.y+=art.height_at(Vector2(part.position.x,part.position.z),kind)
	wire_lights(root)
	var entries=[]
	var center=Vector2.ZERO
	for i in 4:
		var angle=i*TAU/4
		var origin=center+Vector2(cos(angle)*.145,sin(angle)*.05)
		var entry=worker(kind,true)
		entry.merge({"origin":origin,"home":center+Vector2(cos(angle)*.115,sin(angle)*.05),"kind":kind,"phase":i*1.8})
		root.add_child(entry.root,true);entries.append(entry)
	return {"root":root,"actors":entries}

func night_lighting(lights: Array,night: float):
	var glow=glow_material()
	glow.albedo_color=Color("665544").lerp(Color("ffd092"),night)
	glow.emission_energy_multiplier=night*3.2
	for light in lights:
		# Light3D disables inherited scale; its own global basis is always unit
		# length. The parent retains the miniature-to-world conversion.
		var world_scale=light.get_parent().global_basis.get_scale().y
		light.omni_range=float(light.get_meta("local_range",.38))*world_scale
		light.visible=night>.01
		light.light_energy=night*float(light.get_meta("night_energy",4.0))
