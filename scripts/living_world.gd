extends RefCounted
# All dimensions are in normalized tile units; the board maps each unit to 10 m.
var craft=CatanCosmetics.new()
var night_glow: StandardMaterial3D
const WOOD=Color("64432d")
const STONE=Color("949487")
const PLASTER=Color("e3cfaa")

func limb(parent: Node3D,pos: Vector3,length: float,color: Color) -> Node3D:
	var pivot=Node3D.new();pivot.position=pos;parent.add_child(pivot)
	craft.block(pivot,Vector3(0,-length*.5,0),Vector3(.016,length,.018),color)
	return pivot

func sheep() -> Dictionary:
	var root=Node3D.new();root.name="GrazingSheep"
	var legs=[]
	for x in [-.034,.034]:
		for z in [-.055,.055]:legs.append(limb(root,Vector3(x,.058,z),.055,WOOD))
	craft.orb(root,Vector3(0,.087,0),Vector3(.105,.09,.17),Color("e8e0cb"))
	for i in 7:
		var angle=i*2.4
		craft.orb(root,Vector3(cos(angle)*.035,.113,sin(angle)*.054),Vector3.ONE*.055,Color("f4eada"))
	var head=Node3D.new();head.position=Vector3(0,.087,-.081);root.add_child(head)
	craft.orb(head,Vector3(0,0,-.018),Vector3(.049,.055,.066),Color("514938"))
	for x in [-1,1]:
		craft.orb(head,Vector3(x*.029,.02,-.013),Vector3(.034,.012,.018),Color("9e927d"))
		craft.orb(head,Vector3(x*.021,.006,-.04),Vector3.ONE*.008,Color("191c19"))
	return {"root":root,"limbs":legs,"head":head,"type":"sheep"}

func worker(kind: int,bandit: bool=false) -> Dictionary:
	var root=Node3D.new();root.name="Farmer" if kind==3 else "Woodcutter" if kind==0 else "QuarryWorker"
	var shirt=[Color("758569"),Color("b77453"),Color("c6b48b"),Color("9b7850"),Color("6d8190")][mini(kind,4)]
	var legs=[limb(root,Vector3(-.02,.07,0),.065,Color("544838")),limb(root,Vector3(.02,.07,0),.065,Color("544838"))]
	craft.block(root,Vector3(0,.104,0),Vector3(.062,.071,.04),shirt)
	var arms=[limb(root,Vector3(-.038,.132,0),.06,shirt),limb(root,Vector3(.038,.132,0),.06,shirt)]
	craft.orb(root,Vector3(0,.165,0),Vector3(.041,.048,.039),Color("cfaa7d"))
	if bandit:
		root.name="HoodedOutlaw"
		craft.round_part(root,Vector3(0,.104,.012),.053,.12,Color("3c4142"),.029,12)
		craft.orb(root,Vector3(0,.167,.008),Vector3(.060,.060,.052),Color("434744"))
		craft.orb(root,Vector3(0,.165,-.020),Vector3(.034,.030,.016),Color("c69b75"))
		craft.block(arms[1],Vector3(0,-.091,0),Vector3(.012,.076,.006),Color("bbc0b5"))
		craft.block(root,Vector3(.045,.058,.036),Vector3(.054,.056,.04),Color("7d5938"))
	else:
		craft.round_part(root,Vector3(0,.188,0),.04,.008,Color("d0b470"),-1,12)
		craft.round_part(root,Vector3(0,.197,0),.024,.021,Color("ba985a"),.019,12)
		var tool=arms[1]
		craft.beam(tool,Vector3(0,-.059,.015),Vector3(0,-.059,-.105),.004,WOOD)
		craft.block(tool,Vector3(0,-.06,-.102),Vector3(.073,.011,.021),Color("88948c"))
	return {"root":root,"limbs":legs,"arms":arms,"type":"bandit" if bandit else "worker"}

func populate(parent: Node3D,kind: int,index: int,art) -> Array:
	var entries=[]
	if kind==5:return entries
	if kind!=2:
		cottage(parent,Vector3(.53,art.height_at(Vector2(.53,-.45),kind),-.45),Color("79614f"),0,.65)
	var count=5 if kind==2 else 3 if kind==3 else 2
	for i in count:
		var entry=sheep() if kind==2 else worker(kind)
		var origin=Vector2(-.48+i*.22,-.16 if kind==3 else .12)
		if kind==2:origin=[Vector2(-.40,.08),Vector2(-.12,-.27),Vector2(.30,-.20),Vector2(.44,.17),Vector2(-.46,.40)][i]
		if kind==0:origin=Vector2(-.48+i*.85,.20)
		if kind in [1,4]:origin=Vector2(-.42+i*.75,.36)
		entry.merge({"origin":origin,"kind":kind,"phase":index*.71+i*1.8,"home":Vector2(-.25+i*.10,-.40) if kind==2 else Vector2(.53,-.36)})
		parent.add_child(entry.root)
		entries.append(entry)
	animate(entries,0,art)
	return entries

func animate(entries: Array,time: float,art,daylight: float=1.0):
	for actor in entries:
		var t=time+actor.phase
		var sheep_actor=actor.type=="sheep"
		var angle=t*.15
		var offset=Vector2(sin(angle)*.065,cos(angle)*.055) if sheep_actor else Vector2(sin(t*.12)*.035,0)
		var night=1.0-daylight
		var point=(actor.origin+offset*daylight).lerp(actor.get("home",actor.origin),night)
		actor.root.visible=sheep_actor or actor.type=="bandit" or night<.97
		actor.root.scale.y=lerpf(.64,1.0,daylight) if sheep_actor else 1.0
		actor.root.position=Vector3(point.x,art.height_at(point,actor.kind)+.003,point.y)
		actor.root.rotation.y=atan2(-cos(angle),sin(angle)) if sheep_actor else .35+sin(t*.12)*.25
		for i in actor.limbs.size():actor.limbs[i].rotation.x=sin(t*3+i*PI)*(.22 if sheep_actor else .08)*daylight
		if sheep_actor:actor.head.rotation.x=.2+maxf(0,sin(t*.7))*.65*daylight
		else:
			for arm in actor.arms:arm.rotation.x=(-.55+sin(t*1.8)*.5)*daylight
			actor.root.rotation.x=sin(t*1.8)*.07*daylight

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
	var radius=.34 if city else .29
	craft.round_part(root,Vector3(0,.008,0),radius,.035,Color("9f9479"),-1,32)
	# Crossing streets retain an open center and connect to the road endpoints.
	for angle in [0,PI/3,-PI/3]:
		var street=craft.block(root,Vector3(0,.030,0),Vector3(.045,.012,radius*2),Color("c4b99d"));street.rotation.y=angle
	var count=6 if city else 3
	for i in count:
		var angle=TAU*i/count+.5
		cottage(root,Vector3(sin(angle)*radius*.63,.033,cos(angle)*radius*.63),color.darkened(.12*(i%3)),angle, .72 if city else .95,style,city or i==0)
	if city:
		craft.block(root,Vector3(0,.14,-.03),Vector3(.135,.22,.135),STONE)
		craft.round_part(root,Vector3(0,.285,-.03),.096,.11,color,0,12)
		craft.flag(root,Vector3(0,.32,-.03),color)
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
	craft.flag(root,Vector3(-.10,.09,.08),color)
	return root

func harbor(resource: int) -> Node3D:
	var root=Node3D.new();root.name="CoastalHarbor";root.set_meta("resource",resource)
	# Cliff top at .20: the quay meets the land above it, then steps down to water.
	craft.block(root,Vector3(0,.105,.065),Vector3(.46,.23,.20),STONE)
	craft.block(root,Vector3(0,.225,.065),Vector3(.49,.022,.21),Color("c2b89e"))
	for i in 5:craft.block(root,Vector3(0,.20-i*.026,.18+i*.041),Vector3(.20,.04,.044),Color("b8ab8e"))
	for i in 12:craft.block(root,Vector3(0,.067,.38+i*.032),Vector3(.32,.025,.029),Color("ad8659").lightened(.025*(i%2)))
	for z in [.38,.54,.72]:
		for x in [-.135,.135]:
			craft.round_part(root,Vector3(x,.015,z),.018,.22,WOOD,-1,8)
			craft.round_part(root,Vector3(x,.131,z),.022,.018,Color("a18c64"),-1,10)
	# Rope handrails and a small shore warehouse distinguish it from a road.
	for x in [-.135,.135]:craft.beam(root,Vector3(x,.13,.38),Vector3(x,.13,.72),.005,Color("c1ad7b"))
	cottage(root,Vector3(-.16,.238,.055),Color("687b80"),0,.65)
	for i in 3:craft.block(root,Vector3(.15,.258+i*.025,.04),Vector3(.042,.026,.06),Color("9b7348"))
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
		light.visible=night>.01
		light.light_energy=night*1.15
