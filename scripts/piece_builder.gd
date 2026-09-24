class_name CatanPieceBuilder
extends RefCounted
## Builds roads, settlements and cities from a CatanAppearance. Everything is plain
## vertex-colored geometry: one draw call for the body, one for the windows that
## glow at night. Results are cached per look, so the board only pays once.
##
## Units match the board: one unit is one tile edge. Towns stand on a disc around
## the vertex and face +z, towards the camera.

const TOWN_RADIUS=.29
const CITY_RADIUS=.36
const ROAD_LENGTH=.77
const ROAD_WIDTH=.17
# Height of every town square's surface above the vertex.
const GROUND_TOP=.012
# Village and city house anchors match the dweller corridors in living_world.gd.
const VILLAGE_HOUSES=[Vector2(.202,-.018),Vector2(0,-.203),Vector2(-.202,-.018)]
const CITY_HOUSE_RADIUS=.238
const CITY_HOUSE_ANGLES=[61.0,1.0,-59.0,-119.0,181.0,121.0]
const FLOWERS=[Color("e0605a"),Color("f0c94a"),Color("e58bc0"),Color("f4efe6"),Color("9c7fd6")]
const WATER=Color("5f9fb5")
const BARK=Color("6e5038")
const SAILCLOTH=Color("efe6d2")
const CACHE_LIMIT=96

static var cache={}
static var body_material: StandardMaterial3D
static var window_material: StandardMaterial3D

var look: Dictionary
var kit=CatanMeshKit.new()
var glow=CatanMeshKit.new()
var rng=RandomNumberGenerator.new()
var detail=true
var player=Color.WHITE
var lights: Array=[]
var chimneys: Array=[]
var deck=0.0
# Local range and night energy for this piece's lamps, read by living_world.wire_lights.
var lamp_reach=[.38,4.0]

static func material() -> StandardMaterial3D:
	if body_material==null:
		body_material=StandardMaterial3D.new()
		body_material.vertex_color_use_as_albedo=true
		body_material.vertex_color_is_srgb=true
		body_material.roughness=.86
	return body_material

static func windows_material() -> StandardMaterial3D:
	if window_material==null:
		window_material=StandardMaterial3D.new()
		window_material.albedo_color=Color("6b5a44")
		window_material.roughness=.4
	return window_material

## Parity 0: a road may leave towards +z. Parity 1: towards -z. Gates open that way.
static func gate_angles(parity: int) -> Array:
	return [90.0,210.0,330.0] if parity==0 else [270.0,30.0,150.0]

static func town(bytes: PackedByteArray,owner: Color,city: bool,parity: int=0,full_detail: bool=true) -> Node3D:
	var key="%s|%s|%s|%d|%s"%[bytes.hex_encode(),"city" if city else "town",owner.to_html(false),parity,full_detail]
	var parts: Dictionary=_cached(key,func():
		var builder=new(bytes,owner,full_detail)
		builder.build_town(city,parity)
		return builder.parts())
	var root=instance(parts,"City" if city else "Settlement")
	root.set_meta("chimneys",parts.chimneys)
	return root

static func road(bytes: PackedByteArray,owner: Color,full_detail: bool=true) -> Node3D:
	var parts: Dictionary=_cached("%s|road|%s|%s"%[bytes.hex_encode(),owner.to_html(false),full_detail],func():
		var builder=new(bytes,owner,full_detail)
		builder.build_road()
		return builder.parts())
	return instance(parts,"Road")

static func road_joint(bytes: PackedByteArray,owner: Color,full_detail: bool=true) -> Node3D:
	var parts: Dictionary=_cached("%s|joint|%s|%s"%[bytes.hex_encode(),owner.to_html(false),full_detail],func():
		var builder=new(bytes,owner,full_detail)
		builder.build_joint()
		return builder.parts())
	return instance(parts,"RoadJoint")

## Height of the walkable road surface above the road's base.
static func road_deck(bytes: PackedByteArray) -> float:
	return [.016,.013,.013,.011,.011][CatanAppearance.decode(bytes).road_surface]

static func _cached(key: String,make: Callable) -> Dictionary:
	if not cache.has(key):
		if cache.size()>=CACHE_LIMIT:cache.clear()
		cache[key]=make.call()
	return cache[key]

static func instance(parts: Dictionary,label: String) -> Node3D:
	var root=Node3D.new()
	root.name=label
	if parts.body!=null:
		var body=MeshInstance3D.new();body.name="Body";body.mesh=parts.body
		root.add_child(body)
	if parts.glow!=null:
		var windows=MeshInstance3D.new();windows.name="NightWindows";windows.mesh=parts.glow
		root.add_child(windows)
	for i in parts.lights.size():
		var lamp=OmniLight3D.new();lamp.name="NightLight%d"%i
		lamp.position=parts.lights[i]
		lamp.light_energy=0
		lamp.set_meta("extras",{"local_range":parts.lamp_reach[0],"night_energy":parts.lamp_reach[1]})
		root.add_child(lamp)
	return root

func _init(bytes: PackedByteArray,owner: Color,full_detail: bool):
	look=CatanAppearance.decode(bytes)
	player=owner
	detail=full_detail
	rng.seed=int(look.seed)*7919+1
	kit.rng.seed=rng.seed+11
	glow.rng.seed=rng.seed+23

func parts() -> Dictionary:
	return {"body":kit.mesh(material()),"glow":glow.mesh(windows_material()),"lights":lights,"chimneys":chimneys,"lamp_reach":lamp_reach}

func color(key: String) -> Color:
	return Color(look[key])

## Places both the body and the glowing windows; they must never drift apart.
func _push(local: Transform3D):
	kit.push(local)
	glow.push(local)

func _pop():
	kit.pop()
	glow.pop()

func _jitter(amount: float) -> float:
	return rng.randf_range(-amount,amount)*float(look.wobble)

# ---------------------------------------------------------------- towns

func build_town(city: bool,parity: int):
	var radius=CITY_RADIUS if city else TOWN_RADIUS
	var gates=gate_angles(parity)
	_ground(radius,city)
	var footprints=[]
	if city:
		for i in CITY_HOUSE_ANGLES.size():
			var angle=deg_to_rad(CITY_HOUSE_ANGLES[i])
			footprints.append(Vector2(cos(angle),sin(angle))*CITY_HOUSE_RADIUS)
	else:
		footprints=VILLAGE_HOUSES
	_square_surface(radius,footprints,city)
	for i in footprints.size():
		var at: Vector2=footprints[i]
		_house_at(Vector3(at.x,.012,at.y),.72 if city else .95,i,city)
	var banner_top: Vector3
	if city:
		banner_top=_landmark()
		if look.city_wall!=3:_city_wall(gates)
		_towers(gates)
	else:
		_centerpiece()
		if look.garden!=0:_garden(parity)
		_border(radius,gates)
		banner_top=Vector3(-.09,.012,.1)
		banner_top=_flagpole(banner_top,.2*float(look.pole_height))
	_banner(banner_top,city)
	_lanterns(radius,gates,city)

func _ground(radius: float,city: bool):
	# The rim always carries the owner's color so towns stay readable.
	kit.cylinder(Vector3(0,-.022,0),radius,radius-.004,.03,32,player.darkened(.1),true,player)
	var ground=color("ground_color")
	if look.square==2:ground=color("foliage_color").lerp(ground,.35)
	kit.cylinder(Vector3(0,-.012,0),radius-.014,radius-.014,.024,32,ground)

func _square_surface(radius: float,houses: Array,city: bool):
	if not detail:return
	var ground=color("ground_color")
	var clear=func(p: Vector2) -> bool:
		for h in houses:
			if p.distance_to(h)<(.075 if city else .1):return false
		return p.length()>(.1 if city else .055)
	var top=.0125
	match int(look.square):
		0,1:
			var size=.02 if look.square==0 else .042
			var ring=size*.6
			while ring<radius-.02:
				var count=maxi(6,floori(TAU*ring/(size*1.1)))
				var offset=rng.randf()
				for i in count:
					var angle=TAU*(i+offset)/count
					var p=Vector2(cos(angle),sin(angle))*ring
					if not clear.call(p):continue
					var tangent=Vector2(-sin(angle),cos(angle))
					var half_t=size*.46*rng.randf_range(.8,1.05);var half_r=size*.44*rng.randf_range(.75,1.0)
					var shade=kit.vary(ground,.14)
					var radial=Vector2(cos(angle),sin(angle))
					var corners=[]
					for c in [[-1,-1],[1,-1],[1,1],[-1,1]]:
						var q=p+tangent*half_t*c[0]+radial*half_r*c[1]
						corners.append(Vector3(q.x,top+rng.randf_range(0,.0015),q.y))
					kit.polygon(corners,shade.lightened(.05),Vector3(p.x,0,p.y))
				ring+=size*1.05
		2:
			for i in 40:
				var p=Vector2.from_angle(rng.randf()*TAU)*sqrt(rng.randf())*(radius-.03)
				if not clear.call(p):continue
				kit.blob(Vector3(p.x,top,p.y),Vector3(.009,.006,.009)*rng.randf_range(.7,1.3),kit.vary(color("foliage_color"),.12),5,3)
		3:
			for i in 26:
				var p=Vector2.from_angle(rng.randf()*TAU)*sqrt(rng.randf())*(radius-.03)
				if not clear.call(p):continue
				kit.blob(Vector3(p.x,top,p.y),Vector3(.006,.003,.005)*rng.randf_range(.7,1.4),kit.vary(color("stone_color"),.12),5,2)
		4:
			var z=-radius+.02
			while z<radius-.02:
				var half=sqrt(maxf(0,pow(radius-.02,2)-z*z))
				kit.polygon([Vector3(-half,top,z),Vector3(half,top,z),Vector3(half,top,z+.021),Vector3(-half,top,z+.021)],kit.vary(ground,.1),Vector3(0,0,z+.01))
				z+=.025

func _house_at(at: Vector3,scale: float,index: int,city: bool):
	var variety=float(look.variety)
	var spec={
		"width":float(look.house_width)*(1+rng.randf_range(-.15,.12)*variety),
		"depth":float(look.house_depth)*(1+rng.randf_range(-.12,.12)*variety),
		"stories":clampi(int(look.stories)+(1 if city else 0)-(1 if rng.randf()<variety*.35 else 0),1,3),
		"wall":kit.vary(color("wall_color"),.06*variety),
		"roof":kit.vary(color("roof_color"),.1*variety),
		"index":index}
	# Keep neighbours apart even at the widest settings.
	var limit=.23 if not city else .27
	spec.width=minf(spec.width,limit/(.19*scale))
	# Doors face the square, so side houses show their gables to the camera.
	var facing=atan2(-at.x,-at.z) if Vector2(at.x,at.z).length()>.01 else 0.0
	_push(Transform3D(Basis(Vector3.UP,facing+_jitter(.12)).scaled(Vector3.ONE*scale),at))
	house(spec)
	_pop()

# ---------------------------------------------------------------- houses

## One house at the local origin, door towards +z.
func house(spec: Dictionary):
	var w=.19*float(spec.width);var d=.16*float(spec.depth)
	var story=.075*float(look.story_height)
	var stories: int=spec.stories
	var base=_foundation(w,d)
	var top=base+story*stories
	var wall: Color=spec.wall
	var logs=look.wall_material==4
	kit.box(Vector3(0,(base+top)*.5,0),Vector3(w,top-base,d)-(Vector3(.006,0,.006) if logs else Vector3.ZERO),wall.darkened(.15) if logs else wall)
	if detail:_wall_skin(w,d,base,top,wall)
	for s in stories:_storey_openings(w,d,base+story*s,story,s)
	if look.framing!=0 and not logs:_framing(w,d,base,story,stories)
	var roof=_roof(w,d,top,spec.roof)
	_chimneys(w,d,top,roof)
	if look.dormers>0:_dormers(w,d,top,roof,spec.roof)
	# One vane per town, on the house at the back where the camera sees it whole.
	if look.weathervane and spec.index==1:_weathervane(Vector3(0,_roof_height(roof,0,roof.ridge_z),roof.ridge_z))
	lights.append(kit.xform*Vector3(0,base+.04,d*.5+.03))

func _foundation(w: float,d: float) -> float:
	var height=float(look.foundation_height)
	var stone=color("stone_color")
	match int(look.foundation):
		0:
			var h=.008+.028*height
			kit.box(Vector3(0,h*.5,0),Vector3(w+.012,h,d+.012),stone.darkened(.05))
			if detail:
				for face in _faces(w+.012,d+.012):_masonry(face,0,h,.011,.02,.034,.0025,stone,.12)
			_steps(Vector3(0,0,(d+.012)*.5),h,stone)
			return h
		1:
			var h=.03+.08*height
			var timber=color("trim_color")
			for x in [-w*.42,0.0,w*.42]:
				for z in [-d*.4,d*.4]:
					kit.cylinder(Vector3(x,0,z),.0065,.0055,h,6,kit.vary(timber,.08))
			kit.box(Vector3(0,h-.004,0),Vector3(w+.03,.008,d+.03),timber.lightened(.1))
			_ladder(Vector3(w*.22,0,d*.5+.02),h,timber)
			return h
		2:
			var h=.01+.03*height
			var timber=color("trim_color").lightened(.15)
			kit.box(Vector3(0,h*.5,0),Vector3(w+.04,h,d+.05),timber.darkened(.2))
			if detail:
				var z=-(d+.05)*.5
				while z<(d+.05)*.5-.001:
					kit.box(Vector3(0,h+.0015,z+.006),Vector3(w+.04,.003,.011),kit.vary(timber,.1))
					z+=.013
			_steps(Vector3(0,0,(d+.05)*.5),h,timber)
			return h+.003
	return 0.0

func _steps(front: Vector3,height: float,tint: Color):
	var count=clampi(ceili(height/.012),1,4)
	for i in count:
		var h=height*(count-i)/count
		kit.box(front+Vector3(0,h*.5,.007+i*.011),Vector3(.04,h,.012),kit.vary(tint,.08))

func _ladder(front: Vector3,height: float,timber: Color):
	var lean=Vector3(0,0,.03)
	for x in [-.011,.011]:
		kit.beam(front+Vector3(x,0,0)+lean,front+Vector3(x,height,0),.003,.003,timber)
	var rungs=floori(height/.018)
	for i in rungs:
		var t=(i+.7)/(rungs+.4)
		var at=front.lerp(front+Vector3(0,height,0),t)+lean*(1-t)
		kit.beam(at+Vector3(-.011,0,0),at+Vector3(.011,0,0),.0025,.0025,timber)

## The four walls as [origin corner, along, outward normal, length, depth offset].
func _faces(w: float,d: float) -> Array:
	return [
		{"origin":Vector3(-w*.5,0,d*.5),"along":Vector3.RIGHT,"normal":Vector3.BACK,"length":w},
		{"origin":Vector3(w*.5,0,-d*.5),"along":Vector3.LEFT,"normal":Vector3.FORWARD,"length":w},
		{"origin":Vector3(w*.5,0,d*.5),"along":Vector3.FORWARD,"normal":Vector3.RIGHT,"length":d},
		{"origin":Vector3(-w*.5,0,-d*.5),"along":Vector3.BACK,"normal":Vector3.LEFT,"length":d}]

## Staggered blocks over one wall face between two heights.
func _masonry(face: Dictionary,y0: float,y1: float,course: float,shortest: float,longest: float,proud: float,tint: Color,spread: float):
	var rows=maxi(1,roundi((y1-y0)/course))
	var h=(y1-y0)/rows
	for r in rows:
		var u=-rng.randf()*shortest if r%2 else 0.0
		while u<face.length:
			var length=rng.randf_range(shortest,longest)
			var a=maxf(u,0.0);var b=minf(u+length,face.length)
			if b-a>.004:
				var center=face.origin+face.along*(a+b)*.5+Vector3.UP*(y0+h*(r+.5))+face.normal*proud*.5
				var size=face.along.abs()*(b-a-.0018)+Vector3.UP*(h-.0018)+face.normal.abs()*(proud+rng.randf_range(0,proud))
				kit.stone(center,size,kit.vary(tint,spread),face.normal)
			u+=length

func _wall_skin(w: float,d: float,y0: float,y1: float,wall: Color):
	match int(look.wall_material):
		0:
			if look.framing!=0:return
			# Plaster without timbers gets stone quoins to hold the corners.
			var stone=color("stone_color")
			var y=y0;var i=0
			while y<y1-.004:
				var h=minf(.014,y1-y)
				for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
					var long=.022 if i%2==0 else .013;var short=.013 if i%2==0 else .022
					kit.box(Vector3(corner.x*(w*.5-long*.5+.002),y+h*.5,corner.y*(d*.5-short*.5+.002)),Vector3(long,h-.0015,short),kit.vary(stone,.1))
				y+=h;i+=1
		1:
			for face in _faces(w,d):_masonry(face,y0,y1,.021,.026,.046,.0035,wall,.12)
		2:
			for face in _faces(w,d):_masonry(face,y0,y1,.012,.024,.026,.0018,wall,.07)
		3:
			for face in _faces(w,d):
				var u=0.0
				while u<face.length-.002:
					var width=minf(rng.randf_range(.013,.018),face.length-u)
					var center=face.origin+face.along*(u+width*.5)+Vector3.UP*(y0+y1)*.5+face.normal*.0015
					kit.stone(center,face.along.abs()*(width-.0015)+Vector3.UP*(y1-y0)+face.normal.abs()*(.003+rng.randf_range(0,.0015)),kit.vary(wall,.09),face.normal)
					u+=width
		4:
			var radius=.0078
			var y=y0+radius;var row=0
			while y<y1:
				for face in _faces(w,d):
					if (row+int(face.normal.x!=0))%2:continue
					var reach=.012
					var a=face.origin-face.along*reach+Vector3.UP*y-face.normal*.001
					var b=face.origin+face.along*(face.length+reach)+Vector3.UP*y-face.normal*.001
					kit.rod(a,b,radius,6,kit.vary(wall,.1))
				y+=radius*1.8;row+=1

## Door and windows for one storey, laid out evenly on each wall.
func _storey_openings(w: float,d: float,y0: float,height: float,story: int):
	var count: int=look.windows
	for face in _faces(w,d):
		var front=face.normal==Vector3.BACK
		var side=face.normal.x!=0
		var slots=count if not side else mini(count,1 if d<.2 else 2)
		var door=front and story==0
		if door:slots+=1
		if slots==0:continue
		var pitch=face.length/slots
		for i in slots:
			var u=pitch*(i+.5)
			var at=face.origin+face.along*u+Vector3.UP*y0
			if door and i==slots/2:
				_door(at,face)
			else:
				_window(at+Vector3.UP*height*.55,face,minf(pitch*.7,.03))

func _opening_outline(shape: int,width: float,height: float) -> Array:
	var points=[]
	match shape:
		1:
			points=[Vector2(-width*.5,-height*.5),Vector2(width*.5,-height*.5)]
			for i in 7:
				var a=PI*i/6.0
				points.append(Vector2(cos(a)*width*.5,height*.5-width*.5+sin(a)*width*.5))
		2:
			for i in 8:points.append(Vector2.from_angle(TAU*i/8.0+PI/8)*width*.55)
		_:
			points=[Vector2(-width*.5,-height*.5),Vector2(width*.5,-height*.5),Vector2(width*.5,height*.5),Vector2(-width*.5,height*.5)]
	return points

func _inflate(points: Array,amount: float) -> Array:
	var result=[]
	for p in points:result.append(p+p.normalized()*amount if p.length()>0 else p)
	return result

func _window(center: Vector3,face: Dictionary,max_width: float):
	var shape: int=look.window_shape
	var width=minf(max_width,[.026,.024,.028,.02][shape])
	var height=[.028,.034,.028,.044][shape]
	var outline=_opening_outline(shape,width,height)
	var trim=color("trim_color")
	var u: Vector3=face.along;var n: Vector3=face.normal
	kit.plate(_inflate(outline,.0045),center+n*.0015,u,Vector3.UP,n*.003,trim.lightened(.08))
	glow.plate(outline,center+n*.0028,u,Vector3.UP,n*.0022,Color.WHITE)
	if shape!=2 and detail:
		kit.beam(center-Vector3.UP*height*.5+n*.004,center+Vector3.UP*height*.5+n*.004,.0022,.0022,trim,n)
		kit.beam(center-u*width*.5+n*.004,center+u*width*.5+n*.004,.0022,.0022,trim,n)
	kit.box(center-Vector3.UP*(height*.5+.003)+n*.004,u.abs()*(width+.012)+Vector3.UP*.004+n.abs()*.009,trim.darkened(.1))
	if look.shutters and shape!=2:
		var accent=color("accent_color")
		for side in [-1,1]:
			kit.box(center+u*side*(width*.5+.0085)+n*.0025,u.abs()*.012+Vector3.UP*height+n.abs()*.0025,kit.vary(accent,.05))
	if look.flower_boxes:
		var box_at=center-Vector3.UP*(height*.5+.008)+n*.008
		kit.box(box_at,u.abs()*(width+.006)+Vector3.UP*.008+n.abs()*.009,color("trim_color").darkened(.15))
		for i in 4:
			var along=(i-1.5)/1.5*width*.45
			var petals=FLOWERS[rng.randi()%FLOWERS.size()] if i%2==0 else color("foliage_color")
			kit.blob(box_at+u*along+Vector3.UP*.006,Vector3.ONE*.0048,petals,5,3)

func _door(base: Vector3,face: Dictionary):
	var style: int=look.door_style
	var u: Vector3=face.along;var n: Vector3=face.normal
	var width=[.026,.026,.036,.038][style];var height=[.048,.05,.048,.038][style]
	var outline=_opening_outline(1 if style==1 else 2 if style==3 else 0,width,height)
	var center=base+Vector3.UP*(height*.5 if style!=3 else width*.5)
	var accent=color("accent_color");var trim=color("trim_color")
	kit.plate(_inflate(outline,.004),center+n*.0015,u,Vector3.UP,n*.003,trim)
	kit.plate(outline,center+n*.003,u,Vector3.UP,n*.003,accent)
	if detail and style!=3:
		var boards=3 if style!=2 else 4
		for i in range(1,boards):
			var along=-width*.5+width*i/boards
			kit.beam(base+u*along+n*.0048,base+u*along+Vector3.UP*height*.8+n*.0048,.0012,.0012,accent.darkened(.25),n)
	kit.blob(center+u*width*.3+n*.006,Vector3.ONE*.0028,Color("d9b76c"),4,2)

func _framing(w: float,d: float,base: float,story: float,stories: int):
	var timber=color("trim_color")
	var t=.0065
	var style: int=look.framing
	var top=base+story*stories
	for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		kit.box(Vector3(corner.x*w*.5,(base+top)*.5,corner.y*d*.5),Vector3(t+.003,top-base,t+.003),kit.vary(timber,.06))
	for s in stories+1:
		var y=base+story*s
		for face in _faces(w,d):
			var a: Vector3=face.origin+Vector3.UP*y+face.normal*.0015
			kit.beam(a,a+face.along*face.length,t,t,kit.vary(timber,.06),face.normal)
	if style<2:return
	for s in stories:
		var y0=base+story*s;var y1=y0+story
		for face in _faces(w,d):
			var n: Vector3=face.normal*.0015
			var a: Vector3=face.origin+n
			var span=minf(face.length*.22,story*.8)
			if style==2:
				kit.beam(a+Vector3.UP*y0,a+face.along*span+Vector3.UP*y1,t*.8,t*.8,timber,face.normal)
				var b: Vector3=face.origin+face.along*face.length+n
				kit.beam(b+Vector3.UP*y0,b-face.along*span+Vector3.UP*y1,t*.8,t*.8,timber,face.normal)
			elif face.normal.x!=0 and (look.windows==0 or d>=.2):
				kit.beam(a+Vector3.UP*y0,a+face.along*face.length+Vector3.UP*y1,t*.8,t*.8,timber,face.normal)
				kit.beam(a+Vector3.UP*y1,a+face.along*face.length+Vector3.UP*y0,t*.8,t*.8,timber,face.normal)
			else:
				for end in [0.0,1.0]:
					var at: Vector3=face.origin+face.along*face.length*end+n
					var inward=face.along*(1 if end==0 else -1)
					kit.beam(at+Vector3.UP*y0,at+inward*span+Vector3.UP*(y0+story*.45),t*.8,t*.8,timber,face.normal)
					kit.beam(at+inward*span+Vector3.UP*(y0+story*.55),at+Vector3.UP*y1,t*.8,t*.8,timber,face.normal)

# ---------------------------------------------------------------- roofs

## Builds the roof and returns a height function for chimneys and dormers.
func _roof(w: float,d: float,top: float,tint: Color) -> Dictionary:
	var over=.004+.026*float(look.roof_overhang)
	var hw=w*.5+over;var hd=d*.5+over
	var pitch=deg_to_rad(float(look.roof_pitch))
	var rise=minf(hd*tan(pitch),.2)
	var style: int=look.roof_style
	var planes=[]
	var info={"rise":rise,"hd":hd,"hw":hw,"ridge_z":0.0,"top":top,"style":style}
	var y=top
	match style:
		0,4:
			var zr=-hd*.25 if style==4 else 0.0
			info.ridge_z=zr
			planes.append([Vector3(-hw,y,hd),Vector3(hw,y,hd),Vector3(hw,y+rise,zr),Vector3(-hw,y+rise,zr)])
			planes.append([Vector3(hw,y,-hd),Vector3(-hw,y,-hd),Vector3(-hw,y+rise,zr),Vector3(hw,y+rise,zr)])
			_gable_fill(w,d,y,rise,hd,zr,rise)
			if detail and look.windows>0:
				for side in [-1,1]:
					var eye=Vector3(side*(w*.5+.001),y+rise*.38,zr*.5)
					var along=Vector3.FORWARD if side>0 else Vector3.BACK
					kit.plate(_inflate(_opening_outline(2,.014,.014),.004),eye,along,Vector3.UP,Vector3(side*.004,0,0),color("trim_color"))
					glow.plate(_opening_outline(2,.014,.014),eye+Vector3(side*.0012,0,0),along,Vector3.UP,Vector3(side*.003,0,0),Color.WHITE)
			_ridge(Vector3(-hw,y+rise,zr),Vector3(hw,y+rise,zr),tint)
		1:
			var xr=maxf(hw-hd,0.0)
			var apex_y=y+(rise if hw>=hd else hw*tan(pitch))
			planes.append([Vector3(-hw,y,hd),Vector3(hw,y,hd),Vector3(xr,apex_y,0),Vector3(-xr,apex_y,0)])
			planes.append([Vector3(hw,y,-hd),Vector3(-hw,y,-hd),Vector3(-xr,apex_y,0),Vector3(xr,apex_y,0)])
			planes.append([Vector3(hw,y,hd),Vector3(hw,y,-hd),Vector3(xr,apex_y,0),Vector3(xr,apex_y,0)])
			planes.append([Vector3(-hw,y,-hd),Vector3(-hw,y,hd),Vector3(-xr,apex_y,0),Vector3(-xr,apex_y,0)])
			info.rise=apex_y-y
			_hip_fill(w,d,y,apex_y,xr)
			if xr>.001:_ridge(Vector3(-xr,apex_y,0),Vector3(xr,apex_y,0),tint)
		2:
			var k=.62
			var cut=hd*(1-k)
			var xr=hw-cut
			planes.append([Vector3(-hw,y,hd),Vector3(hw,y,hd),Vector3(hw,y+rise*k,cut),Vector3(-hw,y+rise*k,cut)])
			planes.append([Vector3(-hw,y+rise*k,cut),Vector3(hw,y+rise*k,cut),Vector3(xr,y+rise,0),Vector3(-xr,y+rise,0)])
			planes.append([Vector3(hw,y,-hd),Vector3(-hw,y,-hd),Vector3(-hw,y+rise*k,-cut),Vector3(hw,y+rise*k,-cut)])
			planes.append([Vector3(hw,y+rise*k,-cut),Vector3(-hw,y+rise*k,-cut),Vector3(-xr,y+rise,0),Vector3(xr,y+rise,0)])
			planes.append([Vector3(hw,y+rise*k,cut),Vector3(hw,y+rise*k,-cut),Vector3(xr,y+rise,0),Vector3(xr,y+rise,0)])
			planes.append([Vector3(-hw,y+rise*k,-cut),Vector3(-hw,y+rise*k,cut),Vector3(-xr,y+rise,0),Vector3(-xr,y+rise,0)])
			_gable_fill(w,d,y,rise*k+over*rise*(1-k)/maxf(cut,.001),hd,0.0,rise,cut)
			_ridge(Vector3(-xr,y+rise,0),Vector3(xr,y+rise,0),tint)
		3:
			var inset=.32*minf(hw,hd)
			var lower=inset*2.3
			var iw=hw-inset;var id=hd-inset
			var upper=minf(id*tan(pitch*.5),.08)
			var y1=y+lower
			planes.append([Vector3(-hw,y,hd),Vector3(hw,y,hd),Vector3(iw,y1,id),Vector3(-iw,y1,id)])
			planes.append([Vector3(hw,y,-hd),Vector3(-hw,y,-hd),Vector3(-iw,y1,-id),Vector3(iw,y1,-id)])
			planes.append([Vector3(hw,y,hd),Vector3(hw,y,-hd),Vector3(iw,y1,-id),Vector3(iw,y1,id)])
			planes.append([Vector3(-hw,y,-hd),Vector3(-hw,y,hd),Vector3(-iw,y1,id),Vector3(-iw,y1,-id)])
			var xr=maxf(iw-id,0.0)
			planes.append([Vector3(-iw,y1,id),Vector3(iw,y1,id),Vector3(xr,y1+upper,0),Vector3(-xr,y1+upper,0)])
			planes.append([Vector3(iw,y1,-id),Vector3(-iw,y1,-id),Vector3(-xr,y1+upper,0),Vector3(xr,y1+upper,0)])
			planes.append([Vector3(iw,y1,id),Vector3(iw,y1,-id),Vector3(xr,y1+upper,0),Vector3(xr,y1+upper,0)])
			planes.append([Vector3(-iw,y1,-id),Vector3(-iw,y1,id),Vector3(-xr,y1+upper,0),Vector3(-xr,y1+upper,0)])
			_hip_fill(w,d,y,y1,iw)
			info.rise=lower+upper
			info.mansard=lower
		5:
			var stone=color("stone_color")
			kit.box(Vector3(0,y+.005,0),Vector3(w+.006,.01,d+.006),tint.darkened(.1))
			for face in _faces(w+.006,d+.006):
				var a: Vector3=face.origin+Vector3.UP*(y+.01)
				kit.beam(a,a+face.along*face.length,.008,.012,kit.vary(stone,.06),Vector3.UP)
				var merlons=maxi(2,floori(face.length/.028))
				for i in merlons:
					var at: Vector3=a+face.along*face.length*(i+.5)/merlons+Vector3.UP*.013
					kit.box(at,face.along.abs()*.012+Vector3.UP*.012+face.normal.abs()*.009,kit.vary(stone,.08))
			info.rise=.026
			info.flat=true
			return info
	for plane in planes:_roof_plane(plane,tint)
	return info

func _gable_fill(w: float,d: float,y: float,rise_at_wall: float,hd: float,zr: float,rise: float,cut: float=-1.0):
	var wall=color("wall_color") if look.wall_material!=4 else color("wall_color").darkened(.1)
	var h_front=rise*(hd-d*.5)/maxf(hd-zr,.001)
	var h_back=rise*(hd-d*.5)/maxf(hd+zr,.001)
	var outline=[Vector2(-d*.5,0),Vector2(d*.5,0),Vector2(d*.5,h_front)]
	if cut>0:
		outline.append(Vector2(cut,rise_at_wall));outline.append(Vector2(-cut,rise_at_wall))
	else:
		outline.append(Vector2(zr,rise-.004))
	outline.append(Vector2(-d*.5,h_back))
	kit.plate(outline,Vector3(0,y,0),Vector3.BACK,Vector3.UP,Vector3(w-.002,0,0),wall)
	if detail and look.framing!=0 and look.wall_material!=4:
		var timber=color("trim_color")
		for side in [-1,1]:
			var x=side*(w*.5+.0015)
			kit.beam(Vector3(x,y,zr),Vector3(x,y+(rise_at_wall if cut>0 else rise)-.006,zr),.005,.005,timber,Vector3(side,0,0))

func _hip_fill(w: float,d: float,y: float,apex: float,half_ridge: float):
	var wall=color("roof_color").darkened(.35)
	var top_x=minf(half_ridge,w*.5)
	kit.hexa([Vector3(-w*.5,y,-d*.5),Vector3(w*.5,y,-d*.5),Vector3(w*.5,y,d*.5),Vector3(-w*.5,y,d*.5),
		Vector3(-top_x,apex-.006,-.001),Vector3(top_x,apex-.006,-.001),Vector3(top_x,apex-.006,.001),Vector3(-top_x,apex-.006,.001)],wall)

func _ridge(a: Vector3,b: Vector3,tint: Color):
	if not look.ridge_cap:return
	if look.roof_material==3:
		kit.rod(a+Vector3.UP*.002,b+Vector3.UP*.002,.009,6,tint.darkened(.12))
	elif look.roof_material!=4:
		kit.beam(a+Vector3.UP*.004,b+Vector3.UP*.004,.012,.008,tint.darkened(.28),Vector3.UP)

## Covers one roof face, eave edge first, with courses of the chosen roofing.
func _roof_plane(q: Array,tint: Color):
	var el: Vector3=q[0];var er: Vector3=q[1];var tr: Vector3=q[2];var tl: Vector3=q[3]
	var normal=(er-el).cross(tl-el)
	if normal.length_squared()<1e-12:normal=(er-el).cross(tr-er)
	normal=normal.normalized()
	if normal.y<0:normal=-normal
	var at=func(u: float,v: float) -> Vector3:return el.lerp(er,u).lerp(tl.lerp(tr,u),v)
	kit.slab([el,er,tr,tl],normal,.003,tint.darkened(.3))
	var material: int=look.roof_material
	if not detail:
		kit.slab([el+normal*.003,er+normal*.003,tr+normal*.003,tl+normal*.003],normal,.004,tint)
		return
	var slope=((tl+tr)*.5-(el+er)*.5).length()
	var spec=[[.017,.018,.004,.004,.07],[.012,.012,.003,.003,.13],[.011,.016,.0025,.002,.08],[.03,10.0,.011,.009,.04],[.03,10.0,.004,.002,.05]][material]
	var courses=maxi(1,roundi(slope/spec[0]))
	var wobble=float(look.wobble)
	for k in courses:
		var v0=float(k)/courses;var v1=float(k+1)/courses
		var bottom=v0-.35/courses if k>0 else -.08/courses
		var span=at.call(0,(v0+v1)*.5).distance_to(at.call(1,(v0+v1)*.5))
		if span<.004:continue
		var tiles=maxi(1,roundi(span/(spec[1]*rng.randf_range(.8,1.2) if material==1 else spec[1])))
		var shift=.5/tiles if k%2 else 0.0
		var edges=[0.0]
		for j in range(1,tiles+1):
			var e=clampf((j-shift)/tiles,0,1)
			if e>edges[-1]+.001:edges.append(e)
		if edges[-1]<1:edges.append(1.0)
		var course_tint=tint.darkened(.05*(1-v0)) if material==3 else tint
		for j in edges.size()-1:
			var gap=.0012/maxf(span,.01)
			var u0=edges[j]+(gap if j>0 else 0.0);var u1=edges[j+1]-(gap if j<edges.size()-2 else 0.0)
			var lift=normal*(spec[3]+rng.randf_range(0,.0015)*wobble+.003)
			var corners=[at.call(u0,bottom)+lift,at.call(u1,bottom)+lift,at.call(u1,v1)+normal*.003,at.call(u0,v1)+normal*.003]
			kit.slab(corners,normal,spec[2],kit.vary(course_tint,spec[4]),true)
	if material==4:
		var area=slope*(el.distance_to(er)+tl.distance_to(tr))*.5
		var count=clampi(roundi(area/.0007),3,80)
		for i in count:
			var p=at.call(rng.randf(),rng.randf_range(.05,.95))
			kit.blob(p+normal*.007,Vector3(.013,.009,.013)*rng.randf_range(.8,1.3),kit.vary(tint,.12),5,3)

func _roof_height(roof: Dictionary,x: float,z: float) -> float:
	if roof.get("flat",false):return roof.top+.012
	var run=roof.hd-absf(z-roof.ridge_z)*1.0
	return roof.top+roof.rise*clampf(run/maxf(roof.hd,.001),0,1)

func _chimneys(w: float,d: float,top: float,roof: Dictionary):
	var stone=color("stone_color")
	for i in int(look.chimneys):
		var x=w*.28*(1 if i==0 else -1)
		var z=-d*.18
		var peak=_roof_height(roof,x,z) if not roof.get("flat",false) else top+.02
		var ridge=top+roof.rise
		var height=maxf(peak,ridge*.8+top*.2)+.03-top
		kit.box(Vector3(x,top+height*.5-.01,z),Vector3(.024,height+.02,.024),kit.vary(stone,.08))
		if detail:
			var face={"origin":Vector3(x-.0125,0,z+.0125),"along":Vector3.RIGHT,"normal":Vector3.BACK,"length":.025}
			_masonry(face,top+height*.45,top+height-.012,.009,.01,.014,.0015,stone,.12)
		kit.box(Vector3(x,top+height-.005,z),Vector3(.03,.006,.03),stone.darkened(.2))
		chimneys.append(kit.xform*Vector3(x,top+height,z))

func _dormers(w: float,d: float,top: float,roof: Dictionary,tint: Color):
	if roof.get("flat",false) or roof.rise<.05:return
	var count: int=look.dormers
	for i in count:
		var x=w*((i+.5)/count-.5)*.8
		var z_front=d*.32
		var sill=_roof_height(roof,x,z_front)
		var body_top=sill+.032
		if body_top>top+roof.rise-.01:continue
		var back=roof.ridge_z
		kit.box(Vector3(x,(sill-.01+body_top)*.5,(z_front+back)*.5),Vector3(.04,body_top-sill+.01,z_front-back),color("wall_color"))
		var face={"along":Vector3.RIGHT,"normal":Vector3.BACK}
		_window(Vector3(x,sill+.016,z_front),face,.022)
		var peak=body_top+.016
		for side in [-1,1]:
			var q=[Vector3(x+side*.026,body_top-.003,z_front+.008),Vector3(x+side*.026,body_top-.003,back),Vector3(x,peak,back),Vector3(x,peak,z_front+.008)]
			var n=(q[1]-q[0]).cross(q[3]-q[0]).normalized()
			if n.y<0:n=-n
			kit.slab(q,n,.004,kit.vary(tint,.05))
		kit.plate([Vector2(-.02,0),Vector2(.02,0),Vector2(0,.015)],Vector3(x,body_top,z_front+.002),Vector3.RIGHT,Vector3.UP,Vector3(0,0,.004),color("wall_color"))

func _weathervane(ridge: Vector3):
	var iron=Color("3b3632")
	var height=.07
	kit.rod(ridge-Vector3.UP*.004,ridge+Vector3.UP*height,.0022,5,iron)
	kit.beam(ridge+Vector3(-.013,height*.55,0),ridge+Vector3(.013,height*.55,0),.002,.002,iron)
	kit.beam(ridge+Vector3(0,height*.55,-.013),ridge+Vector3(0,height*.55,.013),.002,.002,iron)
	kit.blob(ridge+Vector3.UP*height*.72,Vector3.ONE*.005,Color("d9b76c"),5,3)
	var arm=ridge+Vector3.UP*(height-.008)
	kit.beam(arm+Vector3(-.03,0,0),arm+Vector3(.026,0,0),.0025,.0025,iron)
	kit.plate([Vector2(0,-.006),Vector2(.012,0),Vector2(0,.006)],arm+Vector3(.024,0,0),Vector3.RIGHT,Vector3.UP,Vector3(0,0,.002),iron)
	# The tail fin flies the owner's color like the banner.
	kit.plate([Vector2(0,-.004),Vector2(-.018,-.012),Vector2(-.018,.012),Vector2(0,.004)],arm+Vector3(-.014,0,0),Vector3.RIGHT,Vector3.UP,Vector3(0,0,.002),player)

# ---------------------------------------------------------------- town dressing

func _centerpiece():
	var y=.012
	var stone=color("stone_color");var timber=color("trim_color")
	match int(look.centerpiece):
		0:
			kit.cylinder(Vector3(0,y,0),.034,.032,.024,10,kit.vary(stone,.05))
			kit.cylinder(Vector3(0,y+.02,0),.024,.024,.0045,10,WATER.darkened(.4))
			for x in [-.028,.028]:kit.box(Vector3(x,y+.045,0),Vector3(.006,.05,.006),timber)
			kit.beam(Vector3(-.03,y+.064,0),Vector3(.03,y+.064,0),.004,.004,timber.darkened(.1))
			for side in [-1,1]:
				var q=[Vector3(-.04,y+.064,side*.03),Vector3(.04,y+.064,side*.03),Vector3(.04,y+.084,0),Vector3(-.04,y+.084,0)]
				kit.slab(q,Vector3(0,1,side*.6),.004,color("roof_color"))
			kit.box(Vector3(.01,y+.038,0),Vector3(.009,.01,.009),timber.lightened(.1))
		1:
			kit.cylinder(Vector3(0,y,0),.05,.048,.016,12,kit.vary(stone,.05))
			kit.cylinder(Vector3(0,y+.012,0),.042,.042,.005,12,WATER)
			kit.cylinder(Vector3(0,y,0),.008,.006,.05,8,stone.lightened(.1))
			kit.cylinder(Vector3(0,y+.05,0),.004,.018,.008,8,stone.lightened(.1))
			kit.blob(Vector3(0,y+.062,0),Vector3(.01,.008,.01),WATER.lightened(.35),6,3)
		2:
			kit.cylinder(Vector3(0,y,0),.011,.007,.07,7,BARK)
			kit.cylinder(Vector3(0,y,0),.03,.03,.006,10,stone)
			var leaf=color("foliage_color")
			for p in [Vector3(0,.1,0),Vector3(.025,.08,.01),Vector3(-.022,.082,-.012),Vector3(.005,.078,-.026),Vector3(-.01,.075,.024)]:
				kit.blob(p,Vector3(.034,.028,.034)*rng.randf_range(.85,1.1),kit.vary(leaf,.1),7,4)
		3:
			kit.box(Vector3(0,y+.016,0),Vector3(.04,.032,.04),stone.darkened(.08))
			kit.box(Vector3(0,y+.034,0),Vector3(.046,.006,.046),stone)
			var bronze=stone.lightened(.15)
			kit.blob(Vector3(0,y+.056,0),Vector3(.011,.019,.009),bronze,6,4)
			kit.blob(Vector3(0,y+.081,0),Vector3(.0075,.0075,.0075),bronze,6,4)
			kit.beam(Vector3(.008,y+.06,0),Vector3(.02,y+.085,0),.004,.004,bronze)
		4:
			for i in 9:
				var a=TAU*i/9
				kit.blob(Vector3(cos(a)*.028,y+.004,sin(a)*.028),Vector3(.008,.006,.008),kit.vary(stone,.1),5,3)
			for i in 4:
				var a=TAU*i/4+.4
				kit.rod(Vector3(cos(a)*.02,y+.002,sin(a)*.02),Vector3(0,y+.03,0),.004,5,BARK)
			glow.blob(Vector3(0,y+.016,0),Vector3(.012,.022,.012),Color.WHITE,6,3)
			lights.append(kit.xform*Vector3(0,y+.03,0))
		5:
			for c in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				kit.box(Vector3(c.x*.034,y+.03,c.y*.022),Vector3(.005,.06,.005),timber)
			kit.box(Vector3(0,y+.016,.01),Vector3(.07,.03,.022),timber.lightened(.1))
			var stripes=6
			for i in stripes:
				var x0=-.042+.084*i/stripes;var x1=x0+.084/stripes
				var tint=player if i%2==0 else color("emblem_color")
				kit.slab([Vector3(x0,y+.062,.034),Vector3(x1,y+.062,.034),Vector3(x1,y+.072,-.03),Vector3(x0,y+.072,-.03)],Vector3(0,1,.16),.003,tint)
			for i in 3:
				kit.blob(Vector3(-.02+.02*i,y+.035,.012),Vector3.ONE*.007,FLOWERS[i],5,3)

## A small plot in the open quarter of the square, away from the gates.
func _garden(parity: int):
	var at=Vector2(.085,.125) if parity==0 else Vector2(.04,.135)
	var y=.012
	# Faces out of the square, so the woodpile's cut ends and the beds' fronts show.
	_push(Transform3D(Basis(Vector3.UP,atan2(at.x,at.y)),Vector3(at.x,0,at.y)))
	var soil=Color("6a4d34")
	var timber=color("trim_color")
	match int(look.garden):
		1:
			kit.box(Vector3(0,y+.003,0),Vector3(.084,.006,.056),soil)
			for side in [-1,1]:
				kit.box(Vector3(0,y+.005,side*.03),Vector3(.09,.01,.005),timber)
				kit.box(Vector3(side*.044,y+.005,0),Vector3(.005,.01,.064),timber)
			var leaf=color("foliage_color")
			for row in 3:
				for i in 5:
					var p=Vector3(-.032+.016*i+_jitter(.002),y+.009,-.017+.017*row)
					kit.blob(p,Vector3(.0065,.0055,.0065)*rng.randf_range(.85,1.15),kit.vary(leaf.lightened(.08*row),.08),5,3)
		2:
			var leaf=color("foliage_color")
			for bed in 2:
				var z=-.015+.03*bed
				kit.box(Vector3(0,y+.004,z),Vector3(.08,.008,.022),soil)
				kit.box(Vector3(0,y+.004,z),Vector3(.086,.006,.026),color("stone_color"))
				for i in 6:
					var p=Vector3(-.032+.0128*i,y+.011,z+_jitter(.004))
					kit.blob(p,Vector3.ONE*.006,kit.vary(leaf,.1),5,3)
					kit.blob(p+Vector3(0,.005,0),Vector3.ONE*.0042,FLOWERS[(i+bed*2)%FLOWERS.size()],5,3)
		3:
			var hay=Color("d6b25c")
			for spot in [Vector3(-.022,y,-.008),Vector3(.02,y,-.012),Vector3(0,y,.02)]:
				var r=.022*rng.randf_range(.9,1.1)
				kit.cylinder(spot,r,r*.95,.018,9,kit.vary(hay,.06))
				kit.blob(spot+Vector3.UP*.018,Vector3(r*.95,r*.85,r*.95),kit.vary(hay.lightened(.06),.06),8,4)
			kit.rod(Vector3(.034,y,.03),Vector3(.02,y+.05,.004),.0018,4,timber)
		4:
			for x in [-.036,.036]:
				kit.box(Vector3(x,y+.022,-.016),Vector3(.005,.044,.005),timber)
			kit.slab([Vector3(-.044,y+.046,-.026),Vector3(.044,y+.046,-.026),Vector3(.044,y+.036,.024),Vector3(-.044,y+.036,.024)],Vector3(0,1,.2),.004,kit.vary(color("roof_color"),.05))
			var bark=BARK
			for layer in 3:
				var count=5-layer
				for i in count:
					var x=(i-(count-1)*.5)*.016
					var p=Vector3(x,y+.006+layer*.0115,0)
					kit.rod(p+Vector3(0,0,-.018),p+Vector3(0,0,.018),.006,6,kit.vary(bark,.1))
					kit.blob(p+Vector3(0,0,.018),Vector3(.0056,.0056,.0015),Color("c9a06a"),6,2)
	_pop()

func _border(radius: float,gates: Array):
	var style: int=look.border
	if style==0:return
	var r=radius-.022
	var steps=64
	for i in steps:
		var a0=TAU*i/steps;var a1=TAU*(i+1)/steps
		if _near_gate((a0+a1)*.5,gates,18.0):continue
		var p0=Vector3(cos(a0)*r,.012,sin(a0)*r);var p1=Vector3(cos(a1)*r,.012,sin(a1)*r)
		match style:
			1:
				var timber=color("wall_color").lightened(.3)
				kit.box(p0+Vector3.UP*.013,Vector3(.005,.026,.005),kit.vary(timber,.05),-a0)
				kit.beam(p0+Vector3.UP*.009,p1+Vector3.UP*.009,.003,.004,timber.darkened(.1))
				kit.beam(p0+Vector3.UP*.019,p1+Vector3.UP*.019,.003,.004,timber.darkened(.1))
			2:
				kit.blob((p0+p1)*.5+Vector3.UP*.012,Vector3(.016,.015,.016)*rng.randf_range(.9,1.15),kit.vary(color("foliage_color"),.1),6,3)
			3:
				kit.beam(p0+Vector3.UP*.009,p1+Vector3.UP*.009,.012,.018,kit.vary(color("stone_color"),.1))

func _near_gate(angle: float,gates: Array,spread: float) -> bool:
	for g in gates:
		if absf(angle_difference(angle,deg_to_rad(g)))<deg_to_rad(spread):return true
	return false

func _lanterns(radius: float,gates: Array,city: bool):
	var spots=[]
	if city:
		for g in gates:
			for side in [-1,1]:spots.append(Vector2.from_angle(deg_to_rad(g+side*17))*(radius-.07))
	else:
		spots=[Vector2(.12,.2),Vector2(-.12,.2),Vector2(.235,.13),Vector2(-.235,.13)]
	var timber=color("trim_color")
	for i in mini(int(look.lanterns),spots.size()):
		var at=Vector3(spots[i].x,.012,spots[i].y)
		kit.cylinder(at,.004,.003,.075,6,timber.darkened(.2))
		kit.box(at+Vector3(0,.082,0),Vector3(.016,.004,.016),timber.darkened(.3))
		glow.box(at+Vector3(0,.072,0),Vector3(.011,.014,.011),Color.WHITE)
		kit.cylinder(at+Vector3(0,.084,0),.01,0,.008,4,timber.darkened(.3))
		lights.append(kit.xform*(at+Vector3(0,.072,0)))

func _flagpole(base: Vector3,height: float) -> Vector3:
	kit.cylinder(base,.0045,.0035,height,6,color("trim_color").darkened(.2))
	kit.blob(base+Vector3.UP*(height+.004),Vector3.ONE*.006,Color("d9b76c"),5,3)
	return base+Vector3.UP*height

## Every banner flies in the owner's color; only its shape and emblem are chosen.
func _banner(top: Vector3,city: bool):
	var size=1.3 if city else 1.0
	var length=.085*size;var height=.056*size
	var shape: int=look.banner_shape
	var u=Vector3.RIGHT;var v=Vector3.UP;var depth=Vector3(0,0,.003)
	var origin=top-Vector3.UP*.006
	var pieces=[]
	match shape:
		0:pieces=[[Vector2(0,0),Vector2(length*1.15,-height*.5),Vector2(0,-height)]]
		1:pieces=[[Vector2(0,0),Vector2(length,0),Vector2(length*.62,-height*.5),Vector2(0,-height*.5)],[Vector2(0,-height*.5),Vector2(length*.62,-height*.5),Vector2(length,-height),Vector2(0,-height)]]
		2:pieces=[[Vector2(0,0),Vector2(length,0),Vector2(length,-height),Vector2(0,-height)]]
		3:
			origin=top-Vector3.UP*.012+Vector3(0,0,.012)
			kit.beam(origin+Vector3(-.036*size,.004,0),origin+Vector3(.036*size,.004,0),.004,.004,color("trim_color"))
			var half=.03*size;var drop=.1*size
			pieces=[[Vector2(-half,0),Vector2(half,0),Vector2(half,-drop*.82),Vector2(0,-drop),Vector2(-half,-drop*.82)]]
			length=half*2;height=drop
	var cloth=player
	for piece in pieces:kit.plate(piece,origin,u,v,depth,cloth)
	var emblem=color("emblem_color")
	var marks=[]
	var cx=length*(.42 if shape==0 else .5)*(1 if shape!=3 else 0)
	var cy=-height*.5 if shape!=3 else -height*.42
	var s=minf(length,height)*.5
	match int(look.emblem):
		1:marks=[[Vector2(cx-length*.5+.004,cy+s*.2),Vector2(cx+length*.5-.004,cy+s*.2),Vector2(cx+length*.5-.004,cy-s*.2),Vector2(cx-length*.5+.004,cy-s*.2)]]
		2:marks=[[Vector2(cx-s*.2,cy+s*.85),Vector2(cx+s*.2,cy+s*.85),Vector2(cx+s*.2,cy-s*.85),Vector2(cx-s*.2,cy-s*.85)],[Vector2(cx-s*.85,cy+s*.2),Vector2(cx+s*.85,cy+s*.2),Vector2(cx+s*.85,cy-s*.2),Vector2(cx-s*.85,cy-s*.2)]]
		3:
			var disc=[]
			for i in 10:disc.append(Vector2(cx,cy)+Vector2.from_angle(TAU*i/10)*s*.55)
			marks=[disc]
		4:marks=[[Vector2(cx-s,cy-s*.3),Vector2(cx,cy+s*.6),Vector2(cx,cy+s*.1),Vector2(cx-s,cy-s*.8)],[Vector2(cx,cy+s*.6),Vector2(cx+s,cy-s*.3),Vector2(cx+s,cy-s*.8),Vector2(cx,cy+s*.1)]]
		5:marks=[[Vector2(cx-s*.8,cy+s*.8),Vector2(cx,cy+s*.8),Vector2(cx,cy),Vector2(cx-s*.8,cy)],[Vector2(cx,cy),Vector2(cx+s*.8,cy),Vector2(cx+s*.8,cy-s*.8),Vector2(cx,cy-s*.8)]]
	if shape==0:
		# Keep marks inside the pennant's taper.
		var trimmed=[]
		for mark in marks:
			var inside=[]
			for p in mark:inside.append(Vector2(minf(p.x,length*.7),clampf(p.y,-height*.5-(height*.5)*(1-p.x/(length*1.15))*.8,-height*.5+(height*.5)*(1-p.x/(length*1.15))*.8)))
			trimmed.append(inside)
		marks=trimmed
	for mark in marks:kit.plate(mark,origin,u,v,depth*1.7,emblem)

# ---------------------------------------------------------------- cities

func _landmark() -> Vector3:
	var height=float(look.keep_height)
	var stone=color("stone_color");var wall=color("wall_color")
	var y=.012
	match int(look.keep):
		0:
			var h=.2*height
			kit.cylinder(Vector3(0,y,0),.066,.058,h,14,kit.vary(stone,.04))
			if detail:_tower_courses(Vector3(0,y,0),.066,.058,h,stone)
			_tower_windows(Vector3(0,y,0),.06,h,3)
			return _flagpole(_tower_top(Vector3(0,y+h,0),.064),.07)
		1:
			var h=.17*height;var s=.13
			kit.box(Vector3(0,y+h*.5,0),Vector3(s,h,s),stone)
			if detail:
				for face in _faces(s,s):_masonry(face,y,y+h,.022,.03,.05,.0035,stone,.1)
			for c in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				var at=Vector3(c.x*s*.5,y,c.y*s*.5)
				kit.cylinder(at,.02,.018,h+.03,8,stone.lightened(.06))
				_tower_top(at+Vector3.UP*(h+.03),.02)
			for face in _faces(s,s):
				var a: Vector3=face.origin+Vector3.UP*(y+h)
				for i in 4:
					kit.box(a+face.along*face.length*(i+.5)/4+Vector3.UP*.008+face.normal*.002,face.along.abs()*.014+Vector3.UP*.016+face.normal.abs()*.01,kit.vary(stone,.06))
				for i in 2:
					for level in 2:
						var at: Vector3=face.origin+face.along*face.length*(i+.5)/2+Vector3.UP*(y+h*(.4+.35*level))
						glow.plate(_opening_outline(1,.012,.024),at+face.normal*.002,face.along,Vector3.UP,face.normal*.003,Color.WHITE)
			_door(Vector3(0,y,s*.5),{"along":Vector3.RIGHT,"normal":Vector3.BACK})
			lights.append(Vector3(0,y+.05,s*.5+.03))
			return _flagpole(Vector3(0,y+h,0),.08)
		2:
			_push(Transform3D(Basis.IDENTITY,Vector3(0,y,0)))
			var spec={"width":.95,"depth":.72,"stories":2,"wall":wall,"roof":color("roof_color"),"index":9}
			house(spec)
			_pop()
			var story=.075*float(look.story_height)
			return _flagpole(Vector3(.09,y+story*2+.02,-.045),.07*height+.06)
		3:
			var h=.26*height
			var bands=6
			for i in bands:
				var r0=lerpf(.05,.034,float(i)/bands);var r1=lerpf(.05,.034,float(i+1)/bands)
				kit.cylinder(Vector3(0,y+h*i/bands,0),r0,r1,h/bands,14,wall if i%2==0 else color("accent_color"),false)
			var top=y+h
			kit.cylinder(Vector3(0,top,0),.05,.05,.006,14,stone)
			for i in 12:
				var a=TAU*i/12
				kit.box(Vector3(cos(a)*.046,top+.012,sin(a)*.046),Vector3(.003,.014,.003),color("trim_color"))
			glow.cylinder(Vector3(0,top+.006,0),.024,.024,.03,8,Color.WHITE)
			kit.cylinder(Vector3(0,top+.036,0),.032,0,.03,10,color("roof_color"))
			lights.append(Vector3(0,top+.02,0))
			return _flagpole(Vector3(0,top+.066,0),.045)
		4:
			var h=.17*height
			kit.cylinder(Vector3(0,y,0),.062,.045,h,12,wall)
			if look.wall_material==1 and detail:_tower_courses(Vector3(0,y,0),.062,.045,h,wall)
			_tower_windows(Vector3(0,y,0),.055,h,2)
			var cap=Vector3(0,y+h,0)
			kit.cylinder(cap,.052,0,.05,10,color("roof_color"))
			var hub=cap+Vector3(0,.012,.052)
			kit.blob(hub,Vector3.ONE*.008,color("trim_color"),5,3)
			for i in 4:
				var a=TAU*i/4+.35
				var tip=hub+Vector3(cos(a),sin(a),0)*.12
				kit.beam(hub,tip,.004,.004,color("trim_color"),Vector3.BACK)
				var side=Vector3(cos(a+PI/2),sin(a+PI/2),0)*.026
				var inner=hub.lerp(tip,.25)
				kit.slab([inner+Vector3(0,0,.002),tip+Vector3(0,0,.002),tip+side+Vector3(0,0,.002),inner+side+Vector3(0,0,.002)],Vector3.BACK,.002,SAILCLOTH)
			return _flagpole(cap+Vector3(0,.05,0),.035)
		5:
			var h=.22*height
			kit.cylinder(Vector3(0,y,0),.04,.02,h,9,BARK)
			for i in 5:
				var a=TAU*i/5
				kit.blob(Vector3(cos(a)*.035,y+.006,sin(a)*.035),Vector3(.022,.012,.014),BARK.darkened(.1),6,3)
			var deck_y=y+h*.45
			kit.cylinder(Vector3(0,deck_y,0),.08,.08,.008,12,color("trim_color").lightened(.1))
			_push(Transform3D(Basis(Vector3.UP,.5).scaled(Vector3.ONE*.42),Vector3(.02,deck_y+.008,.035)))
			house({"width":1.0,"depth":.9,"stories":1,"wall":wall,"roof":color("roof_color"),"index":7})
			_pop()
			var leaf=color("foliage_color")
			for i in 9:
				var a=TAU*i/9
				var r=.07 if i%2 else .04
				kit.blob(Vector3(cos(a)*r,y+h+rng.randf_range(-.02,.03),sin(a)*r),Vector3(.06,.045,.06)*rng.randf_range(.8,1.1),kit.vary(leaf,.1),7,4)
			kit.blob(Vector3(0,y+h+.05,0),Vector3(.06,.05,.06),leaf.lightened(.08),7,4)
			return _flagpole(Vector3(0,y+h+.08,0),.05)
	return Vector3(0,.3,0)

func _tower_courses(base: Vector3,r0: float,r1: float,height: float,stone: Color):
	var rows=maxi(2,roundi(height/.02))
	for i in rows:
		var t=float(i)/rows
		if i%2:continue
		kit.cylinder(base+Vector3.UP*height*t,lerpf(r0,r1,t)+.0015,lerpf(r0,r1,t+1.0/rows)+.0015,height/rows,14,kit.vary(stone,.06),false)

func _tower_windows(base: Vector3,radius: float,height: float,levels: int):
	for level in levels:
		var y=height*(.35+.5*level/maxf(levels-1,1))*.9
		for i in 3:
			var a=deg_to_rad(90+(i-1)*70+level*35)
			var n=Vector3(cos(a),0,sin(a))
			var along=n.cross(Vector3.UP)
			glow.plate(_opening_outline(1,.011,.022),base+n*(radius+.001)+Vector3.UP*y,along,Vector3.UP,n*.004,Color.WHITE)

## A tower cap in the chosen style; returns the highest point for a flag.
func _tower_top(top: Vector3,radius: float) -> Vector3:
	var roof=color("roof_color");var stone=color("stone_color")
	match int(look.tower_roof):
		0:
			var height=radius*2.4
			var bands=4 if detail else 1
			for i in bands:
				var t0=float(i)/bands;var t1=float(i+1)/bands
				var r0=(radius+.008)*(1-t0)+.002;var r1=(radius+.008)*(1-t1)
				kit.cylinder(top+Vector3.UP*(height*t0-.002*i),r0,r1,height/bands+.002,12,kit.vary(roof,.06),i==0)
			return top+Vector3.UP*height
		1:
			kit.cylinder(top,radius+.004,radius+.004,.008,12,stone.lightened(.05))
			for i in 8:
				var a=TAU*i/8
				kit.box(top+Vector3(cos(a)*radius,.014,sin(a)*radius),Vector3(.01,.012,.01),kit.vary(stone,.06),-a)
			return top+Vector3.UP*.008
		2:
			kit.cylinder(top,radius+.004,radius+.004,.006,12,stone)
			kit.blob(top+Vector3.UP*.004,Vector3(radius,radius*1.1,radius),roof,10,5)
			return top+Vector3.UP*radius*1.1
		_:
			kit.cylinder(top,radius+.006,radius+.006,.008,12,roof.darkened(.1))
			return top+Vector3.UP*.008

func _city_wall(gates: Array):
	var style: int=look.city_wall
	var radius=.335
	var height=.05*float(look.wall_height)
	var stone=color("stone_color");var timber=color("trim_color")
	var steps=40
	for i in steps:
		var a0=TAU*i/steps;var a1=TAU*(i+1)/steps
		var middle=(a0+a1)*.5
		var gate=_near_gate(middle,gates,11.0)
		var p0=Vector3(cos(a0)*radius,.012,sin(a0)*radius);var p1=Vector3(cos(a1)*radius,.012,sin(a1)*radius)
		match style:
			0:
				if gate:
					kit.beam(p0+Vector3.UP*(height-.006),p1+Vector3.UP*(height-.006),.02,.012,stone.darkened(.1))
					continue
				kit.beam(p0+Vector3.UP*height*.5,p1+Vector3.UP*height*.5,.02,height,kit.vary(stone,.07))
				if look.crenels:
					var outward=Vector3(cos(middle),0,sin(middle))
					kit.box((p0+p1)*.5+Vector3.UP*(height+.006)+outward*.006,Vector3(.012,.012,.007),kit.vary(stone,.06),-middle+PI/2)
			1:
				if gate:
					kit.beam(p0+Vector3.UP*(height+.01),p1+Vector3.UP*(height+.01),.01,.008,timber)
					continue
				for k in 3:
					var at=p0.lerp(p1,(k+.5)/3)
					var h=height*rng.randf_range(1.0,1.2)
					kit.cylinder(at,.0055,.0055,h,5,kit.vary(timber,.1),false)
					kit.cylinder(at+Vector3.UP*h,.0055,0,.012,5,kit.vary(timber,.1),false)
			2:
				if gate:continue
				kit.beam(p0+Vector3.UP*height*.3,p1+Vector3.UP*height*.3,.03,height*.6,color("ground_color").darkened(.2))
				kit.blob((p0+p1)*.5+Vector3.UP*height*.75,Vector3(.024,height*.5,.024),kit.vary(color("foliage_color"),.1),6,3)
	if look.lanterns==0 and style==0:
		for g in gates:
			var at=Vector3(cos(deg_to_rad(g))*radius,.012+height,sin(deg_to_rad(g))*radius)
			kit.box(at,Vector3(.03,.01,.03),stone.darkened(.1))

func _towers(gates: Array):
	var count: int=look.towers
	if count==0:return
	var radius=.335
	var wall_height=.05*float(look.wall_height) if look.city_wall!=3 else 0.0
	var height=wall_height+.045*float(look.tower_height)+.03
	var base_angle=gates[0]+60.0
	var stone=color("stone_color") if look.city_wall!=1 else color("trim_color")
	for i in count:
		var angle=base_angle+360.0*i/count
		for g in gates:
			var diff=angle_difference(deg_to_rad(angle),deg_to_rad(g))
			if absf(diff)<deg_to_rad(16):angle=g+(16.0 if diff>=0 else -16.0)
		var at=Vector3(cos(deg_to_rad(angle))*radius,.012,sin(deg_to_rad(angle))*radius)
		kit.cylinder(at,.032,.029,height,10,kit.vary(stone,.05))
		if detail and look.city_wall!=1:_tower_courses(at,.032,.029,height,stone)
		var n=Vector3(cos(deg_to_rad(angle)),0,sin(deg_to_rad(angle)))
		glow.plate(_opening_outline(0,.006,.018),at+n*.031+Vector3.UP*height*.62,n.cross(Vector3.UP),Vector3.UP,n*.003,Color.WHITE)
		_tower_top(at+Vector3.UP*height,.03)

# ---------------------------------------------------------------- roads

func _road_widths() -> Vector2:
	var width=ROAD_WIDTH*float(look.road_width)
	return Vector2(width*.8,width)

func build_road():
	var widths=_road_widths()
	var half=widths.x*.5
	var length=ROAD_LENGTH
	_road_surface(half,length)
	var top=[.016,.013,.013,.011,.011][int(look.road_surface)]
	deck=top
	# The owner's color runs along both edges of every road.
	for side in [-1,1]:
		kit.box(Vector3(side*(half+.004),(top+.004)*.5,0),Vector3(.008,top+.004,length),player)
	var edge=half+.012
	var timber=color("trim_color")
	match int(look.road_edges):
		1:
			for side in [-1,1]:
				var z=-length*.5
				while z<length*.5-.001:
					var run=minf(rng.randf_range(.03,.045),length*.5-z)
					kit.box(Vector3(side*edge,(top+.008)*.5,z+run*.5),Vector3(.011,top+.008,run-.002),kit.vary(color("stone_color"),.1))
					z+=run
		2:
			for side in [-1,1]:
				for i in 8:
					var z=-length*.5+length*(i+.5)/8
					kit.box(Vector3(side*edge,.02,z),Vector3(.006,.04,.006),kit.vary(timber,.08))
				for y in [.018,.032]:
					kit.box(Vector3(side*edge,y,0),Vector3(.0035,.004,length),timber.lightened(.08))
		3:
			for side in [-1,1]:
				var count=roundi(length/.03)
				for i in count:
					var z=-length*.5+length*(i+.5)/count
					kit.blob(Vector3(side*(edge+.002),.014,z),Vector3(.012,.014,.018)*rng.randf_range(.85,1.1),kit.vary(color("foliage_color"),.1),5,3)
		4:
			for side in [-1,1]:
				var posts=[]
				for i in 6:
					var z=-length*.5+length*(i+.5)/6
					kit.cylinder(Vector3(side*edge,0,z),.004,.0035,.036,6,kit.vary(timber,.08))
					posts.append(Vector3(side*edge,.03,z))
				for i in posts.size()-1:
					var sag=(posts[i]+posts[i+1])*.5-Vector3.UP*.008
					kit.rod(posts[i],sag,.0017,4,Color("cdb58a"))
					kit.rod(sag,posts[i+1],.0017,4,Color("cdb58a"))
	if look.road_lamps:
		var at=Vector3(edge+.006,0,0)
		kit.cylinder(at,.0035,.003,.065,6,timber.darkened(.2))
		kit.beam(at+Vector3(0,.063,0),at+Vector3(-.014,.063,0),.003,.003,timber.darkened(.2))
		glow.box(at+Vector3(-.014,.054,0),Vector3(.009,.012,.009),Color.WHITE)
		lights.append(at+Vector3(-.014,.054,0))
		lamp_reach=[.22,2.5]
		kit.box(at+Vector3(-.014,.061,0),Vector3(.012,.003,.012),timber.darkened(.3))

func _road_surface(half: float,length: float):
	var road=color("road_color")
	var z0=-length*.5;var z1=length*.5
	match int(look.road_surface):
		0:
			var timber=color("trim_color")
			for x in [-half*.55,half*.55]:
				kit.box(Vector3(x,.0045,0),Vector3(.012,.009,length),timber.darkened(.15))
			var z=z0+.001
			while z<z1-.004:
				var depth=minf(rng.randf_range(.02,.025),z1-z)
				kit.box(Vector3(_jitter(.004),.0125,z+depth*.5),Vector3(half*2+_jitter(.01),.007,depth-.004),kit.vary(road,.1),_jitter(.06))
				z+=depth
		1,2:
			kit.box(Vector3(0,.004,0),Vector3(half*2,.008,length),road.darkened(.25))
			var size=.022 if look.road_surface==1 else .038
			if not detail:
				kit.box(Vector3(0,.0105,0),Vector3(half*2,.005,length),road)
				return
			var columns=maxi(1,roundi(half*2/size))
			var z=z0
			var row=0
			while z<z1-.003:
				var depth=minf(size*rng.randf_range(.85,1.15),z1-z)
				var shift=(.5 if row%2 else 0.0)
				var edges=[-half]
				for c in range(1,columns+1):
					var e=-half+half*2*(c-shift)/columns
					if e>edges[-1]+.004:edges.append(minf(e,half))
				if edges[-1]<half:edges.append(half)
				for c in edges.size()-1:
					var w=edges[c+1]-edges[c]-.002
					if w<.003:continue
					var center=Vector3((edges[c]+edges[c+1])*.5,.0105+rng.randf_range(0,.0012),z+depth*.5)
					kit.box(center,Vector3(w,.005,depth-.002),kit.vary(road,.12),_jitter(.05),[0])
				z+=depth;row+=1
		3,4:
			kit.box(Vector3(0,.005,0),Vector3(half*2,.01,length),road.darkened(.05))
			if not detail:return
			if look.road_surface==3:
				for x in [-half*.45,half*.45]:
					kit.polygon([Vector3(x-.006,.0102,z0),Vector3(x+.006,.0102,z0),Vector3(x+.006,.0102,z1),Vector3(x-.006,.0102,z1)],road.darkened(.14),Vector3(x,0,0))
				for i in 14:
					kit.blob(Vector3(rng.randf_range(-half,half)*.9,.01,rng.randf_range(z0,z1)),Vector3(.004,.003,.004)*rng.randf_range(.7,1.4),kit.vary(color("stone_color"),.12),4,2)
			else:
				for i in 90:
					var at=Vector3(rng.randf_range(-half,half)*.95,.0103,rng.randf_range(z0,z1))
					var s=rng.randf_range(.003,.006)
					kit.polygon([at+Vector3(-s,0,-s),at+Vector3(s,0,-s*.6),at+Vector3(s*.7,0,s),at+Vector3(-s,0,s*.8)],kit.vary(road.lerp(color("stone_color"),.5),.15),at-Vector3.UP)

func build_joint():
	var half=_road_widths().x*.5
	var road=color("road_color")
	var radius=half*1.12
	match int(look.road_surface):
		0:
			kit.cylinder(Vector3.ZERO,radius,radius,.016,10,color("trim_color").lightened(.1))
			if detail:
				for i in 5:
					var z=-radius+radius*2*(i+.5)/5
					var span=sqrt(maxf(0,radius*radius-z*z))*.95
					kit.box(Vector3(0,.0165,z),Vector3(span*2,.002,radius*2/5-.004),kit.vary(road,.1))
		1,2:
			kit.cylinder(Vector3.ZERO,radius,radius,.008,10,road.darkened(.25))
			kit.cylinder(Vector3(0,.008,0),radius-.003,radius-.003,.005,10,road)
			if detail:
				for i in 8:
					var a=TAU*i/8
					kit.box(Vector3(cos(a)*radius*.55,.0135,sin(a)*radius*.55),Vector3(.014,.002,.014),kit.vary(road,.12),a)
		_:
			kit.cylinder(Vector3.ZERO,radius,radius,.011,10,road.darkened(.05))
	deck=[.016,.013,.013,.011,.011][int(look.road_surface)]
