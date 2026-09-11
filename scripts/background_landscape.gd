class_name CatanBackgroundLandscape
extends Node3D
# Continuous terrain around a finite lake; sector edges sample the same field.
const SECTORS=12
const ANGULAR_STEPS=32
const RADIAL_STEPS=28
const OUTER_RADIUS=220.0
const PEAKS=[Vector3(.25,3.8,.20),Vector3(1.13,2.2,.26),Vector3(2.05,4.6,.16),Vector3(2.64,2.7,.22),Vector3(3.72,4.2,.18),Vector3(4.48,3.2,.22),Vector3(5.43,3.5,.21)]
var material: ShaderMaterial
var rng=RandomNumberGenerator.new()
var noise=FastNoiseLite.new()
var sectors=[]
func _init():
	name="BackgroundLandscape"
	rng.seed=71249;noise.seed=6153;noise.frequency=.32
	material=ShaderMaterial.new();material.shader=load("res://shaders/background_landscape.gdshader")
	for sector in SECTORS:
		var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for step in ANGULAR_STEPS:
			var a=TAU*(sector*ANGULAR_STEPS+step)/(SECTORS*ANGULAR_STEPS)
			var b=TAU*(sector*ANGULAR_STEPS+step+1)/(SECTORS*ANGULAR_STEPS)
			for ring in RADIAL_STEPS:
				var near_t=float(ring)/RADIAL_STEPS
				var far_t=float(ring+1)/RADIAL_STEPS
				var near_a=terrain_point(a,near_t);var near_b=terrain_point(b,near_t)
				var far_a=terrain_point(a,far_t);var far_b=terrain_point(b,far_t)
				terrain_face(st,[near_a,near_b,far_a])
				terrain_face(st,[near_b,far_b,far_a])
		for tree in 900:
			var angle=TAU*(sector+rng.randf())/SECTORS
			var t=rng.randf_range(.008,.24)
			var p=terrain_point(angle,t)
			if p.y<.10 or p.y>2.4 or noise.get_noise_2d(p.x*.28,p.z*.28)<.04:continue
			pine(st,p,rng.randf_range(.16,.38))
		st.generate_normals()
		var mesh=MeshInstance3D.new();mesh.name="MainlandSector%d"%sector
		mesh.mesh=st.commit();mesh.material_override=material
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
		add_child(mesh);sectors.append(mesh)

func shore_radius(angle: float) -> float:
	var coast=55.0+10.0*sin(angle*3+.4)+5.0*sin(angle*7-.8)+1.8*sin(angle*13)
	for headland in [Vector2(.7,11.0),Vector2(2.8,14.0),Vector2(4.25,12.0),Vector2(5.35,15.0)]:
		coast-=headland.y*exp(-pow(wrapf(angle-headland.x,-PI,PI)/.18,2))
	return coast

func terrain_point(angle: float,t: float) -> Vector3:
	# Concentrate vertices along the shore and foothills. The outer plateau
	# extends beyond the water plane, so no water/void edge sits behind a ridge.
	var radius=lerpf(shore_radius(angle),OUTER_RADIUS,pow(t,1.5))
	var p=Vector2(cos(angle),sin(angle))*radius
	var inland=radius-shore_radius(angle)
	var foothills=smoothstep(0.0,9.0,inland)
	var silhouette=0.0
	for peak in PEAKS:
		var separation=absf(wrapf(angle-peak.x,-PI,PI))
		silhouette+=peak.y*exp(-pow(separation/peak.z,2))
	var ridge=exp(-pow((inland-(19.0+8.0*sin(angle*3.0)))/10.0,2))
	var low_hills=.35+.25*sin(angle*4.0+.5)+.15*sin(inland*.3+angle*2.0)
	var roughness=noise.get_noise_2d(p.x,p.y)*.22
	var h=-.07+foothills*(.5+low_hills+silhouette*ridge+roughness)
	return Vector3(p.x,h,p.y)

func terrain_face(st: SurfaceTool,points: Array):
	var normal=(points[1]-points[0]).cross(points[2]-points[0]).normalized()
	for p in points:
		# Shared vertex colors avoid checkerboard patches between terrain faces.
		var meadow=smoothstep(-.2,.25,noise.get_noise_2d(p.x*.22,p.z*.22))
		var color=Color("3c5947").lerp(Color("79845a"),meadow)
		var rock=maxf(smoothstep(2.0,4.0,p.y),1.0-smoothstep(.60,.85,normal.y))
		color=color.lerp(Color("626e70"),rock)
		var inland=Vector2(p.x,p.z).length()-shore_radius(atan2(p.z,p.x))
		color=Color("8c8b6b").lerp(color,smoothstep(.10,1.2,inland))
		st.set_color(color.srgb_to_linear());st.add_vertex(p)
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
