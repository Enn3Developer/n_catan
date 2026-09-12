class_name CatanCosmetics
extends RefCounted

# Keep the deck close to the terrain while retaining the modeled trim.
const ROAD_HEIGHT_SCALE=.30
static func road_base_height(style: int) -> float:
	return .201+(.0375 if style==2 else .0275)*ROAD_HEIGHT_SCALE
static func road_deck_height(style: int) -> float:
	return road_base_height(style)+(.051 if style==2 else .0465)*ROAD_HEIGHT_SCALE

const SETS=["Voyager","Harbor","Citadel","Wildwood"]
const SET_DESCRIPTIONS=["Timber framing, tiled roofs and brass details. A classic island expedition.","Stilt houses, dock roads and a lantern tower. Built for life beside the sea.","Carved stone, battlements and heraldic shields. An island stronghold.","Log cabins, leafy roofs and a treehouse tower. A home among the trees."]
var materials={}
var meshes={}

static func valid_set(id: int) -> bool:return id>=0 and id<SETS.size()

func material(color: Color,metal: float=0.0) -> StandardMaterial3D:
	var key=str(color)+str(metal)
	if not materials.has(key):
		var m=StandardMaterial3D.new()
		m.albedo_color=color
		m.metallic=metal
		m.roughness=.48 if metal>0 else .82
		materials[key]=m
	return materials[key]

func part(parent: Node3D,shape: Mesh,pos: Vector3,color: Color,metal: float=0.0) -> MeshInstance3D:
	var n=MeshInstance3D.new()
	n.mesh=shape
	n.position=pos
	n.material_override=material(color,metal)
	parent.add_child(n)
	return n

func block(parent: Node3D,pos: Vector3,size: Vector3,color: Color,metal: float=0.0) -> MeshInstance3D:
	var key="box"+str(size)
	if not meshes.has(key):
		meshes[key]=CatanMiniature.bevel_box(size)
	return part(parent,meshes[key],pos,color,metal)

func round_part(parent: Node3D,pos: Vector3,radius: float,height: float,color: Color,top: float=-1,sides: int=24,metal: float=0.0) -> MeshInstance3D:
	if top<0:top=radius
	var key="cyl"+str([radius,height,top,sides])
	if not meshes.has(key):
		var shape=CylinderMesh.new()
		shape.bottom_radius=radius;shape.top_radius=top;shape.height=height;shape.radial_segments=sides
		meshes[key]=shape
	return part(parent,meshes[key],pos,color,metal)

func orb(parent: Node3D,pos: Vector3,size: Vector3,color: Color,metal: float=0.0) -> MeshInstance3D:
	if not meshes.has("sphere"):
		var shape=SphereMesh.new();shape.radius=.5;shape.height=1;shape.radial_segments=24;shape.rings=12
		meshes.sphere=shape
	var n=part(parent,meshes.sphere,pos,color,metal);n.scale=size;return n

func beam(parent: Node3D,a: Vector3,b: Vector3,width: float,color: Color):
	var n=round_part(parent,(a+b)*.5,width,a.distance_to(b),color,-1,10)
	if a.distance_to(b)>.001:n.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	return n

func roof(parent: Node3D,center: Vector3,width: float,depth: float,color: Color):
	var gable=SurfaceTool.new()
	gable.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1,1]:
		var a=center+Vector3(-width*.45,-.025,side*depth*.43)
		var b=center+Vector3(width*.45,-.025,side*depth*.43)
		var c=center+Vector3(0,.09,side*depth*.43)
		for p in ([a,c,b] if side==1 else [a,b,c]):gable.add_vertex(p)
	gable.generate_normals()
	part(parent,gable.commit(),Vector3.ZERO,Color("dfceb0"))
	# Individually laid overlapping tiles retain the owner's color on both slopes.
	for side in [-1,1]:
		var panel=block(parent,center+Vector3(side*width*.23,0,0),Vector3(width*.62,.027,depth),color)
		panel.rotation.z=-side*.56
		for row in 4:
			for col in 5:
				var tile=block(parent,center+Vector3(side*(.02+row*width*.12),.075-row*width*.071,-depth*.4+col*depth*.2),Vector3(width*.16,.018,depth*.19),color.lightened(.04 if (row+col)%2==0 else 0.0))
				tile.rotation.z=-side*.56
	beam(parent,center+Vector3(0,.09,-depth*.53),center+Vector3(0,.09,depth*.53),.022,color.darkened(.14))

func flag(parent: Node3D,pos: Vector3,color: Color):
	beam(parent,pos,pos+Vector3.UP*.24,.009,Color("bca277"))
	block(parent,pos+Vector3(.045,.19,0),Vector3(.09,.075,.009),color)

func window(parent: Node3D,pos: Vector3):
	block(parent,pos,Vector3(.065,.080,.020),Color("413a30"))
	block(parent,pos+Vector3(0,0,.012),Vector3(.047,.060,.012),Color("efbd68"))
	block(parent,pos+Vector3(0,0,.02),Vector3(.009,.067,.007),Color("624930"))

func settlement(style: int,color: Color,city: bool=false) -> Node3D:
	style=clampi(style,0,SETS.size()-1)
	var root=Node3D.new()
	root.name=("City_" if city else "Settlement_")+SETS[style]
	root.set_meta("cosmetic",style)
	round_part(root,Vector3(0,.008,0),.245 if city else .205,.05,color.darkened(.2),-1,48)
	round_part(root,Vector3(0,.036,0),.230 if city else .190,.012,Color("bba273"),-1,48,.6)
	var wood=Color("66503b")
	var pale=Color("dfceb0")
	match style:
		0:
			block(root,Vector3(0,.18,0),Vector3(.28,.28,.27),pale)
			for x in [-.135,.135]:
				for z in [-.135,.135]:block(root,Vector3(x,.18,z),Vector3(.022,.29,.025),wood)
			block(root,Vector3(0,.23,.145),Vector3(.28,.018,.016),wood)
			roof(root,Vector3(0,.33,0),.35,.34,color)
			block(root,Vector3(.09,.39,-.08),Vector3(.053,.15,.055),Color("9c725a"))
			window(root,Vector3(-.073,.22,.144))
			if city:
				block(root,Vector3(.20,.22,-.04),Vector3(.16,.36,.22),pale)
				roof(root,Vector3(.20,.43,-.04),.23,.28,color)
				window(root,Vector3(.20,.28,.08))
				flag(root,Vector3(.20,.51,-.04),color)
		1:
			for x in [-.14,.14]:
				for z in [-.14,.14]:round_part(root,Vector3(x,.10,z),.025,.18,wood)
			for i in 7:block(root,Vector3(-.15+i*.05,.12,0),Vector3(.046,.024,.34),wood.lightened(.08*(i%2)))
			block(root,Vector3(0,.26,0),Vector3(.25,.24,.23),pale)
			for y in 5:block(root,Vector3(0,.16+y*.045,.124),Vector3(.27,.012,.015),wood)
			roof(root,Vector3(0,.395,0),.34,.33,color)
			window(root,Vector3(-.065,.29,.136))
			for x in [-.16,.16]:
				beam(root,Vector3(x,.13,.16),Vector3(x,.22,.16),.011,wood)
			beam(root,Vector3(-.16,.22,.16),Vector3(.16,.22,.16),.009,wood)
			orb(root,Vector3(.15,.15,.17),Vector3(.042,.055,.04),color)
			if city:
				for y in 5:round_part(root,Vector3(.19,.105+y*.072,-.07),.085-y*.006,.072,color if y%2 else pale)
				round_part(root,Vector3(.19,.49,-.07),.065,.10,Color("ebbb61"),-1,12,.2)
				for a in 6:
					var angle=a*TAU/6
					beam(root,Vector3(.19+cos(angle)*.068,.44,-.07+sin(angle)*.068),Vector3(.19+cos(angle)*.068,.55,-.07+sin(angle)*.068),.007,wood)
				round_part(root,Vector3(.19,.575,-.07),.10,.075,color,0,24)
		2:
			block(root,Vector3(0,.20,0),Vector3(.29,.32,.27),Color("9e9e91"))
			for y in 5:
				for x in 4:
					block(root,Vector3(-.105+x*.07,.075+y*.058,.141),Vector3(.065,.052,.016),Color("b7b6a5").darkened(.035*((x+y)%3)))
			block(root,Vector3(0,.385,0),Vector3(.34,.05,.32),color)
			for x in [-.13,0,.13]:
				for z in [-.135,.135]:block(root,Vector3(x,.43,z),Vector3(.064,.07,.065),color)
			if city:
				for x in [-.19,.19]:
					round_part(root,Vector3(x,.29,-.06),.085,.48,Color("969b91"),-1,16)
					round_part(root,Vector3(x,.54,-.06),.102,.05,color,-1,16)
					for a in 6:
						var angle=a*TAU/6
						block(root,Vector3(x+cos(angle)*.08,.59,-.06+sin(angle)*.08),Vector3(.046,.055,.046),color)
				flag(root,Vector3(0,.44,-.06),color)
			orb(root,Vector3(.065,.24,.159),Vector3(.072,.09,.018),color,.25)
		3:
			for y in 6:
				for x in [-.12,.12]:beam(root,Vector3(x,.07+y*.043,-.14),Vector3(x,.07+y*.043,.14),.029,wood.lightened(.035*(y%2)))
			block(root,Vector3(0,.19,.12),Vector3(.24,.24,.04),Color("96734c"))
			for i in 6:
				var a=i*TAU/6
				orb(root,Vector3(cos(a)*.105,.36,sin(a)*.11),Vector3(.20,.09,.21),color.darkened(.10 if i%2 else 0.0))
			orb(root,Vector3(0,.415,0),Vector3(.20,.10,.20),color.lightened(.10))
			window(root,Vector3(-.07,.22,.146))
			if city:
				beam(root,Vector3(.17,.05,-.07),Vector3(.18,.53,-.06),.047,wood)
				block(root,Vector3(.18,.40,-.06),Vector3(.22,.035,.22),wood)
				block(root,Vector3(.18,.49,-.06),Vector3(.15,.15,.15),Color("a18454"))
				for i in 5:
					var a=i*TAU/5
					orb(root,Vector3(.18+cos(a)*.06,.60,-.06+sin(a)*.06),Vector3(.17,.08,.17),color)
				beam(root,Vector3(.08,.05,.12),Vector3(.08,.40,-.04),.010,wood)
				beam(root,Vector3(.16,.05,.12),Vector3(.16,.40,-.04),.010,wood)
				for y in 6:beam(root,Vector3(.08,.09+y*.053,.10-y*.024),Vector3(.16,.09+y*.053,.10-y*.024),.008,pale)
	block(root,Vector3(.035,.125,.15),Vector3(.062,.15,.018),Color("4c3b2e"))
	orb(root,Vector3(.056,.12,.164),Vector3(.012,.012,.01),Color("d1ae65"),.7)
	return root

func road(style: int,color: Color) -> Node3D:
	var root=Node3D.new();root.name="Road_"+SETS[clampi(style,0,3)];root.set_meta("cosmetic",style)
	var wood=Color("6b513b")
	if style==2:
		block(root,Vector3.ZERO,Vector3(.155,.075,.77),Color("6f756f"))
		for i in 6:block(root,Vector3(0,.044,-.32+i*.128),Vector3(.144,.014,.117),color)
	else:
		block(root,Vector3.ZERO,Vector3(.115,.055,.77),wood)
		for i in 8:block(root,Vector3(0,.034,-.34+i*.097),Vector3(.17,.025,.085),color if style==0 else wood.lightened(.05*(i%2)))
		for x in [-.069,.069]:
			if style==3:beam(root,Vector3(x,.062,-.37),Vector3(x,.062,.37),.019,color)
			else:block(root,Vector3(x,.052,0),Vector3(.019,.023,.77),color)
		if style==1:
			for z in [-.31,.31]:
				for x in [-.077,.077]:round_part(root,Vector3(x,.065,z),.018,.13,color)
	return root

func road_joint(style: int,color: Color) -> Node3D:
	var root=Node3D.new();root.name="RoadJoint"
	# A small round cap closes bends and three-way branches without overlapping faces.
	round_part(root,Vector3(0,0,0),.09,.075 if style==2 else .055,Color("6f756f") if style==2 else Color("6b513b"),-1,24)
	round_part(root,Vector3(0,.042 if style==2 else .0375,0),.091,.018,color,-1,24)
	return root
