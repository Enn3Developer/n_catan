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
	if kind==5:return entries
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
	var stride=progress*TAU*2.0
	var rest=1.0-smoothstep(.08,.4,daylight)
	actor.body.position.y=.082-rest*.032+sin(stride*2)*.0018*moving
	actor.body.rotation.z=sin(stride)*.014*moving
	for i in 4:
		var gait=stride+[0.0,PI,PI,0.0][i]
		actor.limbs[i].rotation.x=sin(gait)*.38*moving+rest*1.12
		actor.knees[i].rotation.x=-maxf(0,cos(gait))*.48*moving-rest*1.95
	var graze=smoothstep(6.0,7.5,local)*(1.0-smoothstep(12.0,14.0,local))*daylight
	actor.head.rotation.x=-.12-graze*.92-rest*.30
	actor.head.rotation.y=sin(t*.65)*.12*(1.0-graze)*(1.0-rest)
	actor.head.position.y=.005+sin(t*4.3)*.0015*graze
	actor.tail.rotation.x=sin(t*2.1)*.12*daylight
	for i in 2:actor.ears[i].rotation.z=sin(t*1.7+i*2.0)*.08*daylight

func animate_worker(actor: Dictionary,time: float,art,daylight: float):
	var t=time+actor.phase
	var bandit=actor.type=="bandit"
	var point=actor.origin.lerp(actor.get("home",actor.origin),1.0-daylight)
	if not actor.get("path",[]).is_empty():point=CatanWorldLayout.along_path(actor.path,1.0-daylight)
	actor.root.position=Vector3(point.x,art.height_at(point,actor.kind)+.003,point.y)
	actor.root.visible=bandit or daylight>.03
	actor.root.rotation=Vector3.ZERO
	var cycle=fposmod(t*(.88+fposmod(actor.phase,.23)),5.6)
	# Deliberate lift, short impact, slower recovery, then a breathing pause.
	var lift=smoothstep(.3,1.6,cycle)
	var hit=smoothstep(1.6,1.92,cycle)
	var recover=smoothstep(2.15,3.4,cycle)
	var stroke=lift-hit
	var working=daylight if not bandit else 0.0
	var bend=(hit-recover)*.22*working
	actor.body.rotation.x=-bend+stroke*.05*working
	actor.body.rotation.y=sin(cycle*1.1)*.035*working
	actor.body.position.y=.079+sin(t*1.5)*.0008
	actor.head.rotation.x=.12+bend*.45-stroke*.12*working
	actor.head.rotation.y=sin(t*.45)*.09*(1.0-working*.8)
	actor.tool.position=Vector3(.006,.028+stroke*.040*working,-.043)
	actor.tool.rotation=Vector3(-2.08+stroke*2.93*working,0,-.12)
	if actor.kind==3 and not bandit:
		var rake=(1.0-cos(cycle/5.6*TAU))*.5*working
		actor.body.rotation.x=-.10-rake*.12
		actor.tool.position=Vector3(.004,.019,-.039-rake*.007)
		actor.tool.rotation=Vector3(-2.05+rake*.55,0,-.08)
	if bandit:
		actor.tool.position=Vector3(.025,.012,-.031)
		actor.tool.rotation=Vector3(-.25,0,-.25)
	if not bandit and actor.kind!=3:strike_pose(actor,cycle,working)
	for i in 2:
		var grip=actor.tool.transform*actor.grips[i]
		reach(actor.arms[i],actor.elbows[i],grip,-1.0 if i==0 else 1.0)
		# A wide, planted stance during work. Commute steps only at dusk/dawn.
		var commute=sin(PI*daylight) if not bandit else 0.0
		actor.limbs[i].rotation.x=sin(t*5.0+i*PI)*.32*commute
		actor.limbs[i].rotation.z=.045 if i==0 else -.045
		actor.knees[i].rotation.x=maxf(0,-sin(t*5.0+i*PI))*.5*commute

# The head lies in the swing plane. Solve the impact from the cutting edge/tip,
# then animate the handle up and back from that contact, independently of torso bend.
func strike_pose(actor: Dictionary,cycle: float,working: float):
	var axe=actor.kind==0
	var tip=Vector3(0,.084,-.038) if axe else Vector3(0,.069,-.052)
	var contact=Vector3(0,.044 if axe else .0345,-.14)
	var impact_angle=-1.9 if axe else -1.85
	var impact_basis=Basis(Vector3.RIGHT,impact_angle)
	var impact_origin=contact-impact_basis*tip
	var overhead=Vector3(.010,.170,-.044)
	var ready=Vector3(.010,.119,-.041)
	var ready_angle=-.55
	var origin=ready
	var angle=ready_angle
	var slide=0.0
	var lean=0.0
	if cycle<1.7:
		var lift=smoothstep(.35,1.7,cycle)
		origin=ready.lerp(overhead,lift)
		angle=lerpf(ready_angle,.42,lift)
		lean=-lift*.045
	elif cycle<2.12:
		# Accelerate into contact, instead of easing to a stop before the hit.
		var swing=pow((cycle-1.7)/.42,2.0)
		origin=overhead.lerp(impact_origin,swing)
		angle=lerpf(.42,impact_angle,swing)
		slide=swing
		lean=lerpf(-.045,.24,swing)
	elif cycle<2.5:
		origin=impact_origin;angle=impact_angle;slide=1.0;lean=.24
	else:
		# Pull the head free before returning to the ready position.
		var recover=smoothstep(2.5,4.3,cycle)
		origin=impact_origin.lerp(ready,recover)
		angle=lerpf(impact_angle,ready_angle,recover)
		slide=1.0-recover;lean=.24*(1.0-recover)
	actor.body.rotation=Vector3(-lean*working,0,0)
	actor.head.rotation.x=.12+lean*.35
	actor.grips=[Vector3(0,lerpf(.022,-.014,slide),0),Vector3(0,-.033,0)]
	var pose=Transform3D(Basis(Vector3.RIGHT,lerpf(ready_angle,angle,working)),ready.lerp(origin,working))
	actor.tool.transform=actor.body.transform.affine_inverse()*pose

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
	actor.body.position.y=.079+absf(sin(stride))*.003*moving
	actor.body.rotation.y=sin(time*.5+actor.index)*.10*(1.0-moving)
	for leg in 2:
		actor.limbs[leg].rotation.x=sin(stride+leg*PI)*.35*moving
		actor.arms[leg].rotation.x=-sin(stride+leg*PI)*.28*moving
	# Occasional small hand gestures while stopped, with planted feet.
	actor.arms[0].rotation.z=sin(time*.9+actor.index)*.12*(1.0-moving)

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
