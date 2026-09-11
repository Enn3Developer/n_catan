extends RefCounted
# All dimensions are in normalized tile units; the board maps each unit to 25 m.
var craft=CatanCosmetics.new()
var night_glow: StandardMaterial3D
const WOOD=Color("64432d")
const STONE=Color("949487")
const PLASTER=Color("e3cfaa")
const TILE_ACTOR_SCALE=.4

func pivot(parent: Node3D,pos: Vector3,label: String) -> Node3D:
	var node=Node3D.new();node.name=label;node.position=pos;parent.add_child(node)
	return node

func bone(parent: Node3D,pos: Vector3,length: float,width: float,color: Color,label: String) -> Node3D:
	var node=pivot(parent,pos,label)
	craft.round_part(node,Vector3(0,-length*.5,0),width,length,color,width*.88,8)
	return node

func sheep() -> Dictionary:
	var root=Node3D.new();root.name="GrazingSheep"
	var body=pivot(root,Vector3(0,.082,0),"Body")
	var legs=[];var knees=[]
	for x in [-.031,.031]:
		for z in [-.051,.051]:
			var leg=bone(body,Vector3(x,-.022,z),.029,.007,Color("796b56"),"Leg")
			var knee=bone(leg,Vector3(0,-.029,0),.025,.0055,Color("564b3c"),"Knee")
			craft.block(knee,Vector3(0,-.023,-.003),Vector3(.013,.012,.020),Color("34332d"))
			legs.append(leg);knees.append(knee)
	craft.orb(body,Vector3.ZERO,Vector3(.102,.084,.153),Color("ddd5c0"))
	# Overlapping fleece curls preserve a woolly silhouette without a stack of spheres.
	for i in 11:
		var angle=i*2.4
		craft.orb(body,Vector3(cos(angle)*.034,.018+float(i%3)*.009,sin(angle)*.052),Vector3(.052,.045,.055),Color("eee5d1").darkened(.025*(i%3)))
	var head=pivot(body,Vector3(0,.005,-.065),"Neck")
	craft.orb(head,Vector3(0,-.012,-.022),Vector3(.037,.052,.060),Color("625849"))
	craft.orb(head,Vector3(0,-.026,-.042),Vector3(.032,.024,.036),Color("49443a"))
	var ears=[]
	for x in [-1,1]:
		var ear=pivot(head,Vector3(x*.018,.008,-.017),"Ear")
		craft.orb(ear,Vector3(x*.012,0,0),Vector3(.030,.010,.017),Color("a4957a"));ears.append(ear)
		craft.orb(head,Vector3(x*.018,-.005,-.034),Vector3.ONE*.007,Color("191c19"))
	var tail=pivot(body,Vector3(0,.015,.071),"Tail")
	craft.orb(tail,Vector3(0,-.009,.006),Vector3(.023,.035,.027),Color("eee5d1"))
	return {"root":root,"body":body,"limbs":legs,"knees":knees,"head":head,"ears":ears,"tail":tail,"type":"sheep"}

func worker(kind: int,bandit: bool=false) -> Dictionary:
	var root=Node3D.new();root.name="HoodedOutlaw" if bandit else "Farmer" if kind==3 else "Woodcutter" if kind==0 else "QuarryWorker"
	var shirt=Color("444c49") if bandit else [Color("728568"),Color("b77453"),Color("c6b48b"),Color("b39a65"),Color("6d8190")][mini(kind,4)]
	var skin=Color("c89b76");var trousers=Color("514b42")
	var legs=[];var knees=[]
	for side in [-1,1]:
		var leg=bone(root,Vector3(side*.020,.079,0),.035,.012, trousers,"Thigh")
		var knee=bone(leg,Vector3(0,-.035,0),.032,.009,trousers,"Knee")
		craft.block(knee,Vector3(0,-.036,-.009),Vector3(.024,.020,.039),Color("3f352c"))
		legs.append(leg);knees.append(knee)
	var body=pivot(root,Vector3(0,.079,0),"Torso")
	craft.round_part(body,Vector3(0,.033,0),.031,.066,shirt,.024,8)
	craft.orb(body,Vector3(0,.054,0),Vector3(.066,.030,.043),shirt)
	craft.round_part(body,Vector3(0,.008,0),.032,.009,Color("594332"),-1,8)
	craft.block(body,Vector3(0,.008,-.030),Vector3(.010,.010,.005),Color("b9a06a"))
	if not bandit:
		craft.block(body,Vector3(0,.017,-.029),Vector3(.037,.043,.006),Color("796044"))
		for side in [-1,1]:craft.beam(body,Vector3(side*.014,.068,-.014),Vector3(side*.014,.030,-.031),.0035,Color("796044"))
	var head=pivot(body,Vector3(0,.074,0),"Head")
	craft.round_part(head,Vector3(0,-.004,0),.009,.014,skin,-1,8)
	craft.orb(head,Vector3(0,.017,0),Vector3(.038,.047,.036),skin)
	craft.orb(head,Vector3(0,.026,.006),Vector3(.040,.034,.033),Color("554333"))
	craft.orb(head,Vector3(0,.014,-.019),Vector3(.010,.012,.011),skin)
	for side in [-1,1]:
		craft.orb(head,Vector3(side*.018,.016,0),Vector3(.010,.014,.009),skin)
		craft.orb(head,Vector3(side*.009,.022,-.016),Vector3(.004,.004,.003),Color("33342d"))
	if bandit:
		craft.orb(head,Vector3(0,.028,.008),Vector3(.053,.054,.043),shirt)
		craft.block(head,Vector3(0,.005,-.018),Vector3(.034,.020,.010),shirt)
		craft.block(body,Vector3(0,.027,.025),Vector3(.065,.085,.012),shirt.darkened(.15))
	else:
		var straw=kind==3
		craft.round_part(head,Vector3(0,.039,0),.043 if straw else .030,.006,Color("ccb077") if straw else shirt.darkened(.25),-1,12)
		craft.round_part(head,Vector3(0,.048,0),.023,.020,Color("c0a06a") if straw else shirt.darkened(.12),.018,12)
	var arms=[];var elbows=[]
	for side in [-1,1]:
		var arm=bone(body,Vector3(side*.034,.055,0),.042,.010,shirt,"UpperArm")
		var elbow=bone(arm,Vector3(0,-.042,0),.043,.007,skin,"Forearm")
		craft.orb(elbow,Vector3(0,-.043,0),Vector3(.016,.018,.016),skin)
		arms.append(arm);elbows.append(elbow)
	var tool=pivot(body,Vector3.ZERO,"Tool")
	craft.beam(tool,Vector3(0,-.040,0),Vector3(0,.094,0),.004,WOOD)
	if bandit:
		craft.block(tool,Vector3(0,.087,0),Vector3(.014,.065,.005),Color("b8beb9"))
	elif kind==0:
		craft.block(tool,Vector3(0,.084,-.016),Vector3(.012,.026,.045),Color("84948f"))
		craft.block(tool,Vector3(0,.084,-.038),Vector3(.006,.032,.005),Color("c8cfbe"))
	elif kind==3:
		craft.beam(tool,Vector3(-.035,.086,0),Vector3(.035,.086,0),.004,WOOD)
		for x in [-.03,-.015,0,.015,.03]:craft.beam(tool,Vector3(x,.084,0),Vector3(x,.084,-.027),.0025,Color("867c61"))
	else:
		for side in [-1,1]:
			craft.beam(tool,Vector3(0,.087,0),Vector3(0,.083,side*.028),.006,Color("8b9690"))
			craft.beam(tool,Vector3(0,.083,side*.028),Vector3(0,.074,side*.044),.0035,Color("aab0a3"))
			craft.beam(tool,Vector3(0,.074,side*.044),Vector3(0,.069,side*.052),.0015,Color("c3c9bc"))
	return {"root":root,"body":body,"head":head,"limbs":legs,"knees":knees,"arms":arms,"elbows":elbows,"tool":tool,"grips":[Vector3(0,.018,0),Vector3(0,-.017,0)],"type":"bandit" if bandit else "worker"}

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
		cottage(parent,Vector3(at.x,art.height_at(at,kind)-.006,at.y),Color("79614f"),0,hut[2])
	for i in layout.workers.size():
		var entry=sheep() if kind==2 else worker(kind)
		var origin=CatanWorldLayout.point(layout.workers[i])
		entry.merge({"origin":origin,"kind":kind,"phase":index*.71+i*1.8,"home":CatanWorldLayout.point(layout.homes[i]),"path":CatanWorldLayout.travel_path(kind,i)})
		parent.add_child(entry.root)
		entry.root.scale=Vector3.ONE*TILE_ACTOR_SCALE
		if kind!=2:
			var worksite=pivot(parent,Vector3(origin.x,art.height_at(origin,kind),origin.y),"Worksite")
			worksite.scale=Vector3.ONE*TILE_ACTOR_SCALE
			if kind==0:
				craft.round_part(worksite,Vector3(0,.023,-.14),.030,.046,WOOD,.026,10)
				craft.round_part(worksite,Vector3(0,.047,-.14),.025,.003,Color("c8a477"),-1,10)
			elif kind in [1,4]:craft.orb(worksite,Vector3(0,.017,-.14),Vector3(.07,.041,.060),Color("a98770") if kind==1 else STONE)
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

func cottage(parent: Node3D,pos: Vector3,color: Color,angle: float=0,scale_factor: float=1,style: int=0,lit: bool=true):
	var house=Node3D.new();house.name="TimberHouse";house.position=pos;house.rotation.y=angle;house.scale=Vector3.ONE*scale_factor;parent.add_child(house,true)
	craft.block(house,Vector3(0,.072,0),Vector3(.15,.14,.14),[PLASTER,Color("d9cdb5"),STONE,Color("a8875f")][style])
	craft.block(house,Vector3(0,.011,0),Vector3(.17,.025,.16),STONE)
	for x in [-.075,.075]:
		for z in [-.071,.071]:craft.block(house,Vector3(x,.074,z),Vector3(.012,.15,.012),WOOD)
	craft.block(house,Vector3(0,.094,.076),Vector3(.15,.012,.012),WOOD)
	craft.beam(house,Vector3(-.065,.018,.077),Vector3(.061,.137,.077),.005,WOOD)
	craft.roof(house,Vector3(0,.153,0),.20,.20,color)
	craft.block(house,Vector3(.046,.047,.079),Vector3(.035,.073,.01),WOOD)
	var window=craft.block(house,Vector3(-.036,.105,.079),Vector3(.027,.027,.013),Color("665544"))
	if lit:window.material_override=glow_material()
	craft.block(house,Vector3(.045,.195,-.038),Vector3(.027,.09,.031),Color("986c53"))

func town(style: int,color: Color,city: bool) -> Node3D:
	var root=Node3D.new();root.name="MedievalCity" if city else "MedievalVillage";root.set_meta("cosmetic",style)
	root.scale.y=1.20
	var radius=.34 if city else .29
	craft.round_part(root,Vector3(0,.008,0),radius,.035,Color("9f9479"),-1,32)
	# Crossing streets retain an open center and connect to the road endpoints.
	for angle in [0,PI/3,-PI/3]:
		var street=craft.block(root,Vector3(0,.030,0),Vector3(.045,.012,radius*2),Color("c4b99d"));street.rotation.y=angle
	var count=6 if city else 3
	for i in count:
		var angle=TAU*i/count+.5 if city else PI+(i-1)*1.48
		cottage(root,Vector3(sin(angle)*radius*.70,.033,cos(angle)*radius*.70),color.darkened(.12*(i%3)),angle+PI, .72 if city else .95,style,city or i==0)
	if city:
		craft.block(root,Vector3(0,.14,0),Vector3(.11,.22,.11),STONE)
		craft.round_part(root,Vector3(0,.285,0),.096,.11,color,0,12)
		craft.flag(root,Vector3(0,.32,0),color)
		for i in 12:
			var angle=i*TAU/12
			if i%4==0:continue # Three gateways align with the street network.
			var wall=craft.block(root,Vector3(sin(angle)*radius,.073,cos(angle)*radius),Vector3(.18,.09,.032),STONE);wall.rotation.y=angle
			for j in [-1,0,1]:craft.block(wall,Vector3(j*.055,.061,0),Vector3(.026,.037,.039),STONE)
		for i in 3:
			var angle=i*TAU/3+.3
			craft.round_part(root,Vector3(sin(angle)*radius,.108,cos(angle)*radius),.044,.18,STONE,-1,12)
	else:
		craft.round_part(root,Vector3(0,.052,0),.04,.045,STONE,-1,12)
		craft.round_part(root,Vector3(0,.076,0),.027,.005,Color("364e50"),-1,12)
		for x in [-.047,.047]:craft.beam(root,Vector3(x,.03,0),Vector3(x,.139,0),.006,WOOD)
		craft.beam(root,Vector3(-.05,.139,0),Vector3(.05,.139,0),.007,WOOD)
	for i in (5 if city else 1):
		var angle=TAU*i/(5 if city else 1)+.2
		lantern(root,Vector3(sin(angle)*radius*.84,.15,cos(angle)*radius*.84),i<(3 if city else 1))
	# Owner's banner and market canopy remain clear from the overview.
	craft.flag(root,Vector3(-.24 if not city else -.18,.09,.11),color)
	root.set_meta("dwellers",populate_town(root,city,color))
	return root

const SETTLEMENT_POPULATION=6
const CITY_POPULATION=16

func populate_town(town_root: Node3D,city: bool,color: Color) -> Array:
	var residents=[]
	var count=CITY_POPULATION if city else SETTLEMENT_POPULATION
	for i in count:
		var person=Node3D.new();person.name="Dweller%02d"%i;town_root.add_child(person)
		# Adult height is roughly 1.8 m at the new world scale.
		person.scale=Vector3(.34,.29,.34)
		var shirt=[color,Color("b58a58"),Color("778868"),Color("b57865"),Color("718998")][i%5]
		var skin=[Color("d2a37e"),Color("b68160"),Color("916449")][i%3]
		var body=pivot(person,Vector3(0,.079,0),"Torso")
		craft.round_part(body,Vector3(0,.033,0),.028,.066,shirt,.023,8)
		craft.round_part(body,Vector3(0,.075,0),.009,.018,skin,-1,8)
		craft.orb(body,Vector3(0,.104,0),Vector3(.037,.045,.036),skin)
		craft.orb(body,Vector3(0,.118,.006),Vector3(.039,.027,.035),Color("584333"))
		if i%3==0:
			craft.round_part(body,Vector3(0,.133,0),.037,.008,Color("c9a86d"),-1,10)
		var legs=[];var arms=[]
		for side in [-1,1]:
			var leg=bone(person,Vector3(side*.017,.079,0),.064,.010,Color("514638"),"Leg")
			craft.block(leg,Vector3(0,-.065,-.009),Vector3(.023,.016,.036),Color("46392b"));legs.append(leg)
			arms.append(bone(body,Vector3(side*.031,.052,0),.064,.009,shirt,"Arm"))
		var angle=TAU*i/count
		var radial=Vector2(sin(angle),cos(angle))
		var start=radial*(.114 if city else .082)
		var finish=radial*(.150 if city else .20 if radial.y>.1 else .11)
		residents.append({"root":person,"body":body,"limbs":legs,"arms":arms,"index":i,"origin":start,"destination":finish,"moving":false})
	animate_dwellers(residents,0,1)
	return residents

func animate_dwellers(residents: Array,time: float,daylight: float):
	for actor in residents:
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
		actor.root.position=Vector3(position.x,.034,position.y)
		actor.root.rotation.y=yaw
		actor.root.visible=daylight>.15
		actor.moving=moving>.08
		var stride=time*4.6+actor.index*1.7
		actor.body.position.y=.079+absf(sin(stride))*.003*moving
		actor.body.rotation.y=sin(time*.5+actor.index)*.10*(1.0-moving)
		for leg in 2:
			actor.limbs[leg].rotation.x=sin(stride+leg*PI)*.35*moving
			actor.arms[leg].rotation.x=-sin(stride+leg*PI)*.28*moving
		# Occasional small hand gestures while stopped, with planted feet.
		actor.arms[0].rotation.z=sin(time*.9+actor.index)*.12*(1.0-moving)

func harbor(resource: int) -> Node3D:
	var root=Node3D.new();root.name="CoastalHarbor";root.set_meta("resource",resource)
	# Cliff top at .20: the quay meets the land above it, then steps down to water.
	craft.block(root,Vector3(0,.105,.065),Vector3(.19,.23,.20),STONE)
	craft.block(root,Vector3(0,.225,.065),Vector3(.195,.022,.21),Color("c2b89e"))
	for i in 5:craft.block(root,Vector3(0,.20-i*.026,.18+i*.041),Vector3(.16,.04,.044),Color("b8ab8e"))
	for i in 12:craft.block(root,Vector3(0,.067,.38+i*.032),Vector3(.32,.025,.029),Color("ad8659").lightened(.025*(i%2)))
	for z in [.38,.54,.72]:
		for x in [-.135,.135]:
			craft.round_part(root,Vector3(x,.015,z),.018,.22,WOOD,-1,8)
			craft.round_part(root,Vector3(x,.131,z),.022,.018,Color("a18c64"),-1,10)
	# Rope handrails and a small shore warehouse distinguish it from a road.
	for x in [-.135,.135]:craft.beam(root,Vector3(x,.13,.38),Vector3(x,.13,.72),.005,Color("c1ad7b"))
	cottage(root,Vector3(-.025,.238,.055),Color("687b80"),0,.50)
	for i in 3:craft.block(root,Vector3(.060,.254+i*.020,.055),Vector3(.025,.020,.039),Color("9b7348"))
	lantern(root,Vector3(.135,.16,.54),true)
	var boat=Node3D.new();boat.name="MooredBoat";boat.position=Vector3(.29,-.025,.61);boat.scale=Vector3.ONE*.65;root.add_child(boat)
	craft.part(boat,CatanMiniature.hull(),Vector3.ZERO,Color("6e4b35"))
	craft.block(boat,Vector3(0,.10,0),Vector3(.20,.02,.50),Color("b28c5e"))
	craft.beam(boat,Vector3(0,.1,0),Vector3(0,.66,0),.012,WOOD)
	var sail=craft.part(boat,CatanMiniature.sail(),Vector3.ZERO,Color("e4d3a5"));sail.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED
	craft.beam(root,Vector3(.135,.12,.54),Vector3(.28,.055,.59),.004,Color("c1ad7b"))
	return root

func glow_material() -> StandardMaterial3D:
	if night_glow==null:
		night_glow=StandardMaterial3D.new()
		night_glow.albedo_color=Color("665544")
		night_glow.emission_enabled=true
		night_glow.emission=Color("ffb55d")
		night_glow.emission_energy_multiplier=0.0
	return night_glow

func lantern(parent: Node3D,pos: Vector3,cast_light: bool):
	craft.beam(parent,pos-Vector3.UP*.12,pos,.006,WOOD)
	var bulb=craft.block(parent,pos,Vector3(.028,.038,.028),Color("ffc475"))
	bulb.name="NightLantern";bulb.material_override=glow_material()
	craft.block(parent,pos+Vector3.UP*.023,Vector3(.038,.009,.038),WOOD)
	if cast_light:
		var light=OmniLight3D.new();light.name="NightLight"
		light.position=pos;light.light_color=Color("ffb765")
		light.omni_range=3.8;light.omni_attenuation=1.5
		light.light_energy=0;light.shadow_enabled=false
		parent.add_child(light,true)

func robber_band(kind: int,art) -> Dictionary:
	var root=Node3D.new();root.name="RobberBand"
	var entries=[]
	var center=Vector2(0,.82)
	for i in 4:
		var angle=i*TAU/4
		var origin=center+Vector2(cos(angle)*.145,sin(angle)*.05)
		var entry=worker(kind,true)
		entry.merge({"origin":origin,"home":center+Vector2(cos(angle)*.115,sin(angle)*.05),"kind":kind,"phase":i*1.8})
		root.add_child(entry.root,true);entries.append(entry)
	# Stolen supplies and a small hearth keep the blocking piece identifiable.
	for i in 3:craft.orb(root,Vector3(.21+i*.035,art.height_at(Vector2(.21+i*.035,.74),kind)+.026,.74),Vector3(.04,.052,.04),Color("96754e"))
	var ground=art.height_at(center,kind)
	for i in 7:
		var angle=i*TAU/7
		craft.orb(root,Vector3(center.x+cos(angle)*.037,ground+.012,center.y+sin(angle)*.037),Vector3(.028,.023,.027),STONE)
	var fire=craft.round_part(root,Vector3(center.x,ground+.028,center.y),.022,.05,Color("ef9e40"),0,9)
	fire.name="Campfire";fire.material_override=glow_material()
	lantern(root,Vector3(center.x,ground+.13,center.y),true)
	return {"root":root,"actors":entries}

func night_lighting(lights: Array,night: float):
	var glow=glow_material()
	glow.albedo_color=Color("665544").lerp(Color("ffd092"),night)
	glow.emission_energy_multiplier=night*3.2
	for light in lights:
		light.omni_range=.38*light.global_basis.get_scale().y
		light.visible=night>.01
		light.light_energy=night*1.15
