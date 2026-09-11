class_name CatanBackgroundLandscape
extends Node3D
# A single batched mesh per island: terrain and forest share distance haze.
var material: ShaderMaterial
var rng=RandomNumberGenerator.new()
var noise=FastNoiseLite.new()
var islands=[]
func _init():
	name="BackgroundLandscape"
	rng.seed=71249;noise.seed=6153;noise.frequency=1.15
	material=ShaderMaterial.new();material.shader=load("res://shaders/background_landscape.gdshader")
	for i in 12:
		var angle=TAU*i/12+.15*sin(i*2.7)
		var far=i%3==0
		var radius=rng.randf_range(18,22) if far else rng.randf_range(11.8,14.2)
		var width=rng.randf_range(3.8,6.2);var depth=rng.randf_range(1.2,1.6)
		var tall=rng.randf_range(2.8,4.4) if far else rng.randf_range(.7,2.5)
		var peaks=[]
		for j in 4:peaks.append(Vector3(-.65+j*.43+rng.randf_range(-.12,.12),rng.randf_range(-.22,.22),rng.randf_range(.55,1.0)))
		var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var steps_x=64;var steps_z=24
		for x in steps_x:
			for z in steps_z:
				var a=Vector2(lerpf(-width,width,float(x)/steps_x),lerpf(-depth,depth,float(z)/steps_z))
				var b=a+Vector2(width*2/steps_x,0);var c=a+Vector2(0,depth*2/steps_z);var d=b+c-a
				terrain_face(st,[a,c,b],width,depth,tall,peaks)
				terrain_face(st,[b,c,d],width,depth,tall,peaks)
		for tree in 650:
			var p=Vector2(rng.randf_range(-width*.95,width*.95),rng.randf_range(-depth*.92,depth*.92))
			var h=height_at(p,width,depth,tall,peaks)
			if h<.10 or h>tall*.64 or noise.get_noise_2d(p.x*2+27,p.y*2)<-.20:continue
			pine(st,Vector3(p.x,h,p.y),rng.randf_range(.18,.40))
		st.generate_normals()
		var island=MeshInstance3D.new();island.name="DistantIsland%d"%i
		island.mesh=st.commit();island.material_override=material
		island.position=Vector3(cos(angle)*radius,0,sin(angle)*radius)
		# Local X runs along the coast, local Z points radially across its depth.
		island.rotation.y=-angle+PI/2
		island.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		island.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
		add_child(island);islands.append(island)
func height_at(p: Vector2,width: float,depth: float,tall: float,peaks: Array) -> float:
	var q=Vector2(p.x/width,p.y/depth)
	var coastline=q.length()+noise.get_noise_2d(p.x*1.8,p.y*1.8)*.13
	if coastline>=1:return -.07
	var mountain=0.0
	for peak in peaks:
		var d=Vector2((q.x-peak.x)*1.6,(q.y-peak.y)*.8).length()
		mountain=maxf(mountain,peak.z*pow(maxf(0,1-d*1.8),1.3))
	var ridge=.83+.17*absf(noise.get_noise_2d(p.x*3,p.y*3))
	return -.045+pow(maxf(0,1-coastline),.55)*(.14+tall*mountain*ridge)
func terrain_face(st: SurfaceTool,points: Array,width: float,depth: float,tall: float,peaks: Array):
	var vertices=[];var height=0.0
	for p in points:
		var h=height_at(p,width,depth,tall,peaks);height+=h/3
		vertices.append(Vector3(p.x,h,p.y))
	if height<-.065:return
	var normal=(vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).normalized()
	var color=Color("56775c")
	if height<.045:color=Color("a8a38b")
	elif normal.y<.63 or height>tall*.56:color=Color("687b7d")
	if tall>2.8 and height>tall*.65:color=Color("c0ccc7")
	color=color.lightened(rng.randf_range(-.035,.035))
	face(st,vertices,color)
func face(st: SurfaceTool,points: Array,color: Color):
	st.set_color(color.srgb_to_linear())
	for p in points:st.add_vertex(p)
func pine(st: SurfaceTool,base: Vector3,h: float):
	var color=Color("305c4b").lightened(rng.randf_range(-.02,.14))
	for tier in 3:
		var y=h*(.13+tier*.22);var radius=h*(.28-tier*.055)
		var top=base+Vector3(0,y+h*.50,0)
		for side in 6:
			var a=TAU*side/6;var b=TAU*(side+1)/6
			face(st,[base+Vector3(cos(a)*radius,y,sin(a)*radius),top,base+Vector3(cos(b)*radius,y,sin(b)*radius)],color)
func set_daylight(amount: float):
	material.set_shader_parameter("haze_color",Color("20344e").lerp(Color("88a6a5"),amount))
