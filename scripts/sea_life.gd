class_name CatanSeaLife
extends Node3D
## Life under the water around the islands: seagrass meadows and kelp on the
## shelf, corals, sea fans and sponges on the reef, starfish on the sand, and
## schools of fish that steer as boids. Placement comes from the map seed, so
## every player sees the same sea floor. Fish move on each client alone.

const WATER_Y=-.675
## Each kind: model, model height (m), depth band (m), count at full detail,
## patchiness (0 even, 1 in tight clumps), scale range, sway, and colors
## [base, tip, variant tip, variant share].
const PLANTS={
	"seagrass":{"model":"seagrass","height":1.37,"depth":Vector2(3.2,9.0),"count":900,"patch":.6,"scale":Vector2(1.6,2.6),"sway":.14,
		"colors":[Color("2d5528"),Color("79a34a"),Color("9aa84c"),.25]},
	"kelp":{"model":"kelp","height":5.5,"depth":Vector2(7.0,18.0),"count":150,"patch":.75,"scale":Vector2(1.0,1.5),"sway":.5,
		"colors":[Color("3b3417"),Color("8f7f33"),Color("a48a3a"),.3]},
	"coral":{"model":"coral","height":1.03,"depth":Vector2(9.0,22.0),"count":120,"patch":.5,"scale":Vector2(1.4,2.4),"sway":0.0,
		"colors":[Color("8a1d18"),Color("e2553f"),Color("f08a4a"),.2]},
	"sea_fan":{"model":"sea_fan","height":1.73,"depth":Vector2(11.0,26.0),"count":80,"patch":.4,"scale":Vector2(1.2,1.8),"sway":.06,
		"colors":[Color("4d1f59"),Color("b25fbf"),Color("e0b53c"),.35]},
	"sponge":{"model":"sponge","height":.71,"depth":Vector2(7.0,22.0),"count":90,"patch":.3,"scale":Vector2(1.3,2.1),"sway":0.0,
		"colors":[Color("a8651b"),Color("e8b54a"),Color("d8743a"),.3]},
	"starfish":{"model":"starfish","height":.06,"depth":Vector2(2.8,10.0),"count":70,"patch":.2,"scale":Vector2(1.3,2.0),"sway":0.0,
		"colors":[Color("c0552b"),Color("e8743e"),Color("b33a5a"),.3]},
	"reef_rock":{"model":"boulder1","height":1.2,"depth":Vector2(4.0,20.0),"count":90,"patch":.3,"scale":Vector2(.8,2.2),"sway":0.0,
		"colors":[Color("4f4a42"),Color("7b746a"),Color("6f7a5a"),.4]},
}
## Each kind of fish: school sizes, speed range (m/s), depth band, and colors
## [back, belly, stripe], stripes per metre and metallic shine.
const FISH={
	"sardine":{"schools":[22,18],"speed":Vector2(2.2,4.0),"depth":Vector2(1.5,9.0),"colors":[Color("2f4f6b"),Color("dfe6ea"),Color("2f4f6b")],"stripes":0.0,"shine":.6},
	"bream":{"schools":[9,7],"speed":Vector2(1.4,2.6),"depth":Vector2(3.0,14.0),"colors":[Color("7d7f78"),Color("d9d3bd"),Color("3a3a36")],"stripes":3.0,"shine":.45},
	"wrasse":{"schools":[1,1,1,1,1],"speed":Vector2(.9,1.8),"depth":Vector2(2.0,8.0),"colors":[Color("2e7a55"),Color("e39a4b"),Color("d85a3a")],"stripes":6.0,"shine":.1},
}
## Fish keep this far off the coast, in metres from the hex edge.
const COAST_CLEARANCE=9.0

var floor_map: CatanSeaFloor
var materials=[]
var schools=[]
var noise=FastNoiseLite.new()
var rng=RandomNumberGenerator.new()
var bounds=Rect2()

func build(state: Dictionary,sea_floor: CatanSeaFloor,values: Dictionary):
	for child in get_children():child.free()
	materials=[]
	schools=[]
	floor_map=sea_floor
	var seed=int(state.get("seed",0))
	rng.seed=seed*13+5
	noise.seed=seed+101
	noise.frequency=.03
	if sea_floor.centers.is_empty():return
	bounds=Rect2(sea_floor.centers[0],Vector2.ZERO)
	for c in sea_floor.centers:bounds=bounds.expand(c)
	bounds=bounds.grow(sea_floor.radius+70.0)
	var detail=[.3,.6,1.0,1.4][clampi(int(values.get("foliage_quality",2)),0,3)]
	var k=0
	for kind in PLANTS:
		_plant(kind,PLANTS[kind],detail,k)
		k+=1
	for kind in FISH:
		for size in FISH[kind].schools:
			_school(kind,maxi(1,int(round(size*minf(detail,1.0)))) if size>1 else 1)
	for kind in FISH:_fish_mesh(kind)

func _model_mesh(name: String) -> Mesh:
	var root=load("res://assets/models/sealife/%s.glb"%name).instantiate()
	var mesh: Mesh=root.find_children("*","MeshInstance3D",true,false)[0].mesh
	root.free()
	return mesh

func _plant(kind: String,spec: Dictionary,detail: float,layer: int):
	var wanted=int(spec.count*detail)
	var transforms=[]
	var tries=0
	while transforms.size()<wanted and tries<wanted*40:
		tries+=1
		var p=Vector2(rng.randf_range(bounds.position.x,bounds.end.x),rng.randf_range(bounds.position.y,bounds.end.y))
		var shore=floor_map.shore_distance(p)
		if shore<4.0:continue
		var depth=CatanSeaFloor.seabed_depth(shore)
		if depth<spec.depth.x or depth>spec.depth.y:continue
		# Clumped kinds only grow where their own noise layer is high.
		var patch=noise.get_noise_2d(p.x+layer*211.0,p.y-layer*97.0)*.5+.5
		if patch<spec.patch*.7:continue
		var size=rng.randf_range(spec.scale.x,spec.scale.y)
		# Tall kelp stops short of the surface.
		size=minf(size,(depth-1.2)/spec.height)
		if size<=.2:continue
		var basis=Basis(Vector3.UP,rng.randf()*TAU)*Basis.from_scale(Vector3.ONE*size)
		transforms.append(Transform3D(basis,Vector3(p.x,WATER_Y,p.y)))
	if transforms.is_empty():return
	var multimesh=MultiMesh.new()
	multimesh.transform_format=MultiMesh.TRANSFORM_3D
	multimesh.mesh=_model_mesh(spec.model)
	multimesh.instance_count=transforms.size()
	for i in transforms.size():multimesh.set_instance_transform(i,transforms[i])
	var material=ShaderMaterial.new()
	material.shader=preload("res://shaders/sea_plant.gdshader")
	material.set_shader_parameter("water_level",WATER_Y)
	material.set_shader_parameter("model_height",spec.height)
	material.set_shader_parameter("sway",spec.sway)
	material.set_shader_parameter("base_color",spec.colors[0])
	material.set_shader_parameter("tip_color",spec.colors[1])
	material.set_shader_parameter("variant_color",spec.colors[2])
	material.set_shader_parameter("variant_share",spec.colors[3])
	_share_floor(material)
	var holder=MultiMeshInstance3D.new()
	holder.name=kind.capitalize().replace(" ","")
	holder.multimesh=multimesh
	holder.material_override=material
	holder.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader lowers every instance to the bed; widen culling to match.
	holder.extra_cull_margin=30.0
	add_child(holder)
	materials.append(material)

func _share_floor(material: ShaderMaterial):
	var centers=floor_map.centers.duplicate()
	while centers.size()<48:centers.append(Vector2(10000,10000))
	material.set_shader_parameter("tile_centers",centers)
	material.set_shader_parameter("tile_count",floor_map.centers.size())
	material.set_shader_parameter("tile_radius",floor_map.radius)

## A school starts at a random spot in open water and wanders between goals.
func _school(kind: String,size: int):
	var spec=FISH[kind]
	var home=_open_water(spec.depth)
	var fish=[]
	for i in size:
		var offset=Vector3(rng.randf_range(-3,3),rng.randf_range(-1,1),rng.randf_range(-3,3))
		var heading=Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1)).normalized()
		fish.append({"p":home+offset,"v":heading*spec.speed.x,"phase":rng.randf(),"rate":rng.randf_range(7.0,9.0)})
	schools.append({"kind":kind,"fish":fish,"goal":_open_water(spec.depth),"timer":rng.randf_range(8,16)})

func _open_water(depth_band: Vector2) -> Vector3:
	for attempt in 200:
		var p=Vector2(rng.randf_range(bounds.position.x,bounds.end.x),rng.randf_range(bounds.position.y,bounds.end.y))
		var shore=floor_map.shore_distance(p)
		if shore<COAST_CLEARANCE+4.0 or shore>70.0:continue
		var depth=CatanSeaFloor.seabed_depth(shore)
		if depth<depth_band.x+2.0:continue
		var y=WATER_Y-rng.randf_range(depth_band.x,minf(depth_band.y,depth-2.0))
		return Vector3(p.x,y,p.y)
	return Vector3(bounds.get_center().x,WATER_Y-3.0,bounds.get_center().y)

func _fish_mesh(kind: String):
	var spec=FISH[kind]
	var count=0
	for school in schools:
		if school.kind==kind:count+=school.fish.size()
	if count==0:return
	var multimesh=MultiMesh.new()
	multimesh.transform_format=MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data=true
	multimesh.mesh=_model_mesh(kind)
	multimesh.instance_count=count
	var material=ShaderMaterial.new()
	material.shader=preload("res://shaders/fish.gdshader")
	material.set_shader_parameter("back_color",spec.colors[0])
	material.set_shader_parameter("belly_color",spec.colors[1])
	material.set_shader_parameter("stripe_color",spec.colors[2])
	material.set_shader_parameter("stripes",spec.stripes)
	material.set_shader_parameter("shine",spec.shine)
	var holder=MultiMeshInstance3D.new()
	holder.name=kind.capitalize()+"Fish"
	holder.multimesh=multimesh
	holder.material_override=material
	holder.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.set_meta("kind",kind)
	add_child(holder)
	materials.append(material)
	_draw_fish(holder)

## Advances the plants' sway and the schools. Delta is zero under Reduce motion.
func animate(delta: float,elapsed: float):
	for material in materials:material.set_shader_parameter("animation_time",elapsed)
	if delta<=0.0 or schools.is_empty():return
	delta=minf(delta,.1)
	for school in schools:_steer(school,delta)
	for holder in get_children():
		if holder.has_meta("kind"):_draw_fish(holder)

## Boid rules inside each school: keep apart, match heading, stay together,
## head for the school's goal, and turn away from the coast and the bed.
func _steer(school: Dictionary,delta: float):
	var spec=FISH[school.kind]
	school.timer-=delta
	var centre=Vector3.ZERO
	var heading=Vector3.ZERO
	for f in school.fish:centre+=f.p;heading+=f.v
	centre/=school.fish.size()
	if school.timer<=0.0 or centre.distance_to(school.goal)<6.0:
		school.goal=_open_water(spec.depth)
		school.timer=rng.randf_range(10,20)
	var alone=school.fish.size()==1
	for f in school.fish:
		var push=Vector3.ZERO
		if not alone:
			var apart=Vector3.ZERO
			for other in school.fish:
				if other==f:continue
				var gap: Vector3=f.p-other.p
				var d=gap.length()
				if d<1.6 and d>.001:apart+=gap/(d*d)
			push+=apart*2.2
			push+=(heading/school.fish.size()-f.v)*.6
			push+=(centre-f.p)*.35
		push+=(school.goal-f.p).normalized()*(1.4 if alone else .9)
		var flat=Vector2(f.p.x,f.p.z)
		var shore=floor_map.shore_distance(flat)
		if shore<COAST_CLEARANCE:
			var away=floor_map.away_from_shore(flat)
			push+=Vector3(away.x,0,away.y)*(COAST_CLEARANCE-shore)*1.5
		var bottom=WATER_Y-CatanSeaFloor.seabed_depth(shore)+1.5
		var top=WATER_Y-1.0
		if f.p.y<bottom:push.y+=(bottom-f.p.y)*2.0
		if f.p.y>top:push.y-=(f.p.y-top)*2.0
		f.v+=push*delta
		f.v.y*=.96
		var speed=clampf(f.v.length(),spec.speed.x,spec.speed.y)
		f.v=f.v.normalized()*speed
		f.p+=f.v*delta
		# A faster fish beats its tail faster.
		f.rate=lerpf(f.rate,6.0+speed*2.5,delta*2.0)

func _draw_fish(holder: MultiMeshInstance3D):
	var kind=holder.get_meta("kind")
	var i=0
	for school in schools:
		if school.kind!=kind:continue
		for f in school.fish:
			var forward: Vector3=f.v.normalized() if f.v.length()>.01 else Vector3.FORWARD
			holder.multimesh.set_instance_transform(i,Transform3D(Basis.looking_at(forward,Vector3.UP,true),f.p))
			holder.multimesh.set_instance_custom_data(i,Color(f.phase,f.rate,0,0))
			i+=1
