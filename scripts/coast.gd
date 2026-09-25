class_name CatanCoast
extends Node3D
## Shores at the foot of the island's cliffs, generated for each board from its
## seed: sand beaches, shingle coves and rocky shelves with boulders and the odd
## sea stack, like the coasts of Normandy, Cornwall or the Algarve. The strip
## runs along every coastline, so archipelago islets get shores too.

const BOULDERS=[preload("res://assets/models/sealife/boulder0.glb"),preload("res://assets/models/sealife/boulder1.glb"),
	preload("res://assets/models/sealife/boulder2.glb"),preload("res://assets/models/sealife/boulder3.glb")]
const WATER_Y=-.675
## Sand, shingle and rock weights for each biome in CatanTileArt.BIOMES order.
const BIOME_SHORE=[Vector3(.15,.5,.35),Vector3(.05,.25,.7),Vector3(.45,.45,.1),Vector3(.75,.2,.05),Vector3(0,.15,.85),Vector3(.9,.1,0)]
## How far each kind of shore reaches out from the cliff, in metres.
const WIDTH=Vector3(10.0,8.0,7.0)
const SAMPLES_PER_EDGE=10
const ROWS=8

var noise=FastNoiseLite.new()
var rng=RandomNumberGenerator.new()

func build(state: Dictionary,tile_size: float,art,values: Dictionary):
	for child in get_children():child.free()
	_vertex_count=0
	var seed=int(state.get("seed",0))
	rng.seed=seed*7+11
	noise.seed=seed
	noise.frequency=1.0
	var surface=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rocks=[[],[],[],[]]
	for loop in _loops(state):
		_shore(loop,state,tile_size,surface,rocks)
	var shore=MeshInstance3D.new()
	shore.name="Shore"
	surface.generate_normals()
	shore.mesh=surface.commit()
	var material=ShaderMaterial.new()
	material.shader=preload("res://shaders/shore.gdshader")
	material.set_shader_parameter("water_level",WATER_Y)
	shore.material_override=material
	add_child(shore)
	for i in BOULDERS.size():
		if rocks[i].is_empty():continue
		var model=BOULDERS[i].instantiate()
		var source: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false)[0]
		var multimesh=MultiMesh.new()
		multimesh.transform_format=MultiMesh.TRANSFORM_3D
		multimesh.mesh=source.mesh
		multimesh.instance_count=rocks[i].size()
		for k in rocks[i].size():multimesh.set_instance_transform(k,rocks[i][k])
		var holder=MultiMeshInstance3D.new()
		holder.name="Boulders%d"%i
		holder.multimesh=multimesh
		holder.material_override=_shore_rock(art,source.mesh.surface_get_material(0),values)
		add_child(holder)
		model.free()

## The terrain's rock texture tier, tinted warmer and darker: wave-washed
## limestone and granite rather than the pale mountain stone.
func _shore_rock(art,base: Material,values: Dictionary) -> Material:
	var rock: Material=art.surface("PBR_Rock",base,values).duplicate()
	if rock is ShaderMaterial:rock.set_shader_parameter("tint",Color("857c70"))
	elif rock is StandardMaterial3D:rock.albedo_color=Color("857c70")
	return rock

## Each closed coastline as its edges in order, with the land tile beside each.
func _loops(state: Dictionary) -> Array:
	var by_vertex={}
	for i in state.edges.size():
		var e=state.edges[i]
		if int(e.tiles)!=1:continue
		for v in [e.a,e.b]:
			if not by_vertex.has(v):by_vertex[v]=[]
			by_vertex[v].append(i)
	var used={}
	var loops=[]
	for start in by_vertex.values():
		for first in start:
			if used.has(first):continue
			var loop=[]
			var edge=first
			var vertex=state.edges[first].a
			while not used.has(edge):
				used[edge]=true
				var e=state.edges[edge]
				var next_vertex=e.b if e.a==vertex else e.a
				loop.append({"edge":edge,"from":vertex,"to":next_vertex})
				vertex=next_vertex
				var next=-1
				for candidate in by_vertex.get(vertex,[]):
					if candidate!=edge and not used.has(candidate):next=candidate
				if next<0:break
				edge=next
			if loop.size()>=3:loops.append(loop)
	return loops

func _shore(loop: Array,state: Dictionary,tile_size: float,surface: SurfaceTool,rocks: Array):
	var count=loop.size()
	var normals=[]
	var weights=[]
	var harbor=[]
	for step in loop:
		var a=state.vertices[step.from]
		var b=state.vertices[step.to]
		var middle=Vector2(a.x+b.x,a.z+b.z)*.5
		var along=Vector2(b.x-a.x,b.z-a.z).normalized()
		var normal=Vector2(-along.y,along.x)
		var land=-1
		for t in a.tiles:
			if t in b.tiles:land=t
		if land>=0 and normal.dot(middle-Vector2(state.tiles[land].x,state.tiles[land].z))<0:normal=-normal
		normals.append(normal)
		weights.append(BIOME_SHORE[mini(int(state.tiles[land].kind),5)] if land>=0 else BIOME_SHORE[0])
		# Harbors get a shingle slipway under the pier.
		harbor.append(a.port!=-2 and a.port==b.port)
	# Where two coast edges meet, the strip bends along the mitred normal.
	var mitres=[]
	for k in count:
		var n1: Vector2=normals[(k-1+count)%count]
		var n2: Vector2=normals[k]
		var m=(n1+n2).normalized()
		mitres.append(m/maxf(m.dot(n2),.5))
	var ring=[]
	var arc=0.0
	for k in count:
		var step=loop[k]
		var a=state.vertices[step.from]
		var b=state.vertices[step.to]
		var from=Vector2(a.x,a.z)*tile_size
		var to=Vector2(b.x,b.z)*tile_size
		for s in SAMPLES_PER_EDGE:
			var u=float(s)/SAMPLES_PER_EDGE
			var point=from.lerp(to,u)
			var out: Vector2=mitres[k].lerp(mitres[(k+1)%count],u)
			# Blend each half-edge into its neighbour so shore types change gradually.
			var mix: Vector3=weights[k]
			if u<.5:mix=mix.lerp(weights[(k-1+count)%count],(.5-u))
			else:mix=mix.lerp(weights[(k+1)%count],(u-.5))
			if harbor[k]:mix=Vector3(0,1,0)
			mix+=Vector3(noise.get_noise_1d(arc*.018),noise.get_noise_1d(arc*.018+71.0),noise.get_noise_1d(arc*.018+143.0))*.55
			mix=Vector3(maxf(mix.x,0.0),maxf(mix.y,0.0),maxf(mix.z,0.0))
			mix=mix*mix
			mix/=maxf(mix.x+mix.y+mix.z,.0001)
			var width=mix.dot(WIDTH)*(.8+.4*(noise.get_noise_1d(arc*.04+300.0)*.5+.5))
			ring.append({"point":point,"out":out,"mix":mix,"width":width,"arc":arc})
			arc+=from.distance_to(to)/SAMPLES_PER_EDGE
	var total=ring.size()
	var base=_vertex_count
	for sample in ring:
		for r in ROWS:
			var v=float(r)/(ROWS-1)
			var p: Vector2=sample.point+sample.out*(sample.width*v-.5)
			var h=_height(sample.mix,v,p)
			surface.set_color(Color(sample.mix.x,sample.mix.y,sample.mix.z,v))
			surface.set_uv(Vector2(sample.arc,sample.width*v))
			surface.add_vertex(Vector3(p.x,WATER_Y+h,p.y))
	_vertex_count+=total*ROWS
	for i in total:
		var j=(i+1)%total
		for r in ROWS-1:
			var a=base+i*ROWS+r
			var b=base+j*ROWS+r
			# Keep the strip facing up whichever way the loop runs.
			var up=(ring[j].point-ring[i].point).cross(ring[i].out)<0
			if up:
				surface.add_index(a);surface.add_index(b);surface.add_index(a+1)
				surface.add_index(b);surface.add_index(b+1);surface.add_index(a+1)
			else:
				surface.add_index(a);surface.add_index(a+1);surface.add_index(b)
				surface.add_index(b);surface.add_index(a+1);surface.add_index(b+1)
	_scatter(ring,rocks,harbor)

var _vertex_count=0

## Metres above the waterline across the strip; v runs from cliff foot (0) to
## the underwater toe (1), where it dips under the sea bed.
func _height(mix: Vector3,v: float,p: Vector2) -> float:
	var sand=1.1-4.6*pow(v,1.6)
	var shingle=1.5-5.4*pow(v,1.15)
	var rock=.8+noise.get_noise_2d(p.x*.35,p.y*.35)*.8-5.0*pow(v,2.0)
	var h=mix.dot(Vector3(sand,shingle,rock))+noise.get_noise_2d(p.x*.6+40.0,p.y*.6)*.12*v
	if v>.99:h-=2.5
	return h

## Boulders on rocky stretches and at the foot of shingle coves, and now and
## then a sea stack standing off a rocky headland.
func _scatter(ring: Array,rocks: Array,harbor: Array):
	var near_harbor={}
	for k in harbor.size():
		if harbor[k]:
			for d in range(-1,2):near_harbor[(k+d+harbor.size())%harbor.size()]=true
	for i in ring.size():
		var sample=ring[i]
		var rock_share: float=sample.mix.z
		var chances=rock_share*1.4+sample.mix.y*.15
		while rng.randf()<chances:
			chances-=1.0
			var v=rng.randf_range(.02,.95) if rock_share>.3 else rng.randf_range(0,.2)
			var p: Vector2=sample.point+sample.out*(sample.width*v)+Vector2(rng.randf_range(-1,1),rng.randf_range(-1,1))
			var size=rng.randf_range(.45,1.5)*(1.25-v*.5)*(.6+rock_share*.6)
			var y=WATER_Y+_height(sample.mix,v,p)-size*.3
			rocks[rng.randi()%4].append(_rock(Vector3(p.x,y,p.y),Vector3(size,size*rng.randf_range(.7,1.2),size)))
		if rock_share>.7 and rng.randf()<.025 and not near_harbor.has(i/SAMPLES_PER_EDGE):
			# Stacks stand clear of the ship lane along the coast.
			var p: Vector2=sample.point+sample.out*rng.randf_range(16.0,20.0)
			var size=rng.randf_range(2.2,3.4)
			rocks[rng.randi()%4].append(_rock(Vector3(p.x,WATER_Y-3.0,p.y),Vector3(size,size*rng.randf_range(3.0,4.2),size)))

func _rock(at: Vector3,scale: Vector3) -> Transform3D:
	var basis=Basis(Vector3.UP,rng.randf()*TAU)*Basis(Vector3.RIGHT,rng.randf_range(-.2,.2))
	return Transform3D(basis*Basis.from_scale(scale),at)
