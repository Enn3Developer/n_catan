extends Node3D
# Weather uses the existing synchronized world clock and never changes game rules.
const CONDITIONS=[Vector3(.18,0,0),Vector3(.72,0,0),Vector3(.93,.65,0),Vector3(1,1,1)]
const KEYFRAMES=[0.0,100.0,190.0,240.0,290.0,340.0,390.0,440.0,500.0,560.0,600.0]
const STATES=[1,0,0,1,2,3,3,2,1,0,1]
var rain: CPUParticles3D
var rain_material: StandardMaterial3D
var lightning: Node3D
var lightning_light: OmniLight3D
var current={"clouds":0.0,"rain":0.0,"storm":0.0,"flash":0.0,"thunder":false}
var _last_amount=-1

static func sample(seconds: float,mode: int=0) -> Dictionary:
	var value=CONDITIONS[clampi(mode-1,0,3)]
	var time=fposmod(seconds,600.0)
	if mode==0:
		for i in KEYFRAMES.size()-1:
			if time<=KEYFRAMES[i+1]:
				var blend=smoothstep(KEYFRAMES[i],KEYFRAMES[i+1],time)
				value=CONDITIONS[STATES[i]].lerp(CONDITIONS[STATES[i+1]],blend)
				break
	# One distant strike per 30 seconds, with thunder arriving after the flash.
	var phase=fposmod(time+7.0,30.0)
	var flash=(1.0-smoothstep(.05,.32,phase))*smoothstep(.65,.95,value.z)
	return {"clouds":value.x,"sun_visibility":1.0-smoothstep(.28,.68,value.x),"rain":value.y,"storm":value.z,"flash":flash,"strike":int(floor((time+7.0)/30.0)),"thunder":value.z>.65 and phase>=1.5 and phase<3.0}

func setup():
	name="Weather"
	rain=CPUParticles3D.new();rain.name="Rain";rain.emitting=false;rain.lifetime=2.0
	rain.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents=Vector3(180,2,180);rain.position.y=78
	rain.direction=Vector3(.13,-1,.05);rain.spread=3;rain.gravity=Vector3(0,-12,0)
	rain.initial_velocity_min=30;rain.initial_velocity_max=38
	rain.local_coords=false;rain.preprocess=2.0
	var drop=BoxMesh.new();drop.size=Vector3(.075,1.65,.075)
	rain_material=StandardMaterial3D.new();rain_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	rain_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	rain_material.albedo_color=Color(.65,.78,.88,.38)
	drop.material=rain_material;rain.mesh=drop
	rain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(rain)
	lightning=Node3D.new();lightning.name="DistantLightning";add_child(lightning)
	var glow=StandardMaterial3D.new();glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;glow.albedo_color=Color(.7,.81,1)
	glow.emission_enabled=true;glow.emission=Color(.6,.75,1);glow.emission_energy_multiplier=2.0
	var points=[Vector3(-170,125,-145),Vector3(-163,106,-142),Vector3(-170,94,-144),Vector3(-158,78,-139),Vector3(-162,67,-140),Vector3(-151,48,-135)]
	for i in points.size()-1:
		var bolt=MeshInstance3D.new();var shape=CylinderMesh.new();shape.top_radius=.24;shape.bottom_radius=.36;shape.height=points[i].distance_to(points[i+1]);shape.radial_segments=5
		bolt.mesh=shape;bolt.material_override=glow;bolt.position=(points[i]+points[i+1])*.5
		bolt.quaternion=Quaternion(Vector3.UP,(points[i+1]-points[i]).normalized());bolt.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;lightning.add_child(bolt)
	lightning_light=OmniLight3D.new();lightning_light.name="LightningGlow";lightning_light.position=Vector3(-158,70,-139)
	lightning_light.light_color=Color(.64,.76,1);lightning_light.omni_range=180;lightning_light.shadow_enabled=false;lightning.add_child(lightning_light)
	lightning.hide()

func update_weather(seconds: float,daylight: float,values: Dictionary,board_scale: float):
	current=sample(seconds,int(values.get("weather",0)))
	var reduced=values.get("reduce_motion",false)
	var particle_level=int(values.get("particles",2))
	var amount=[1,400,1300][clampi(particle_level,0,2)]
	if amount!=_last_amount:rain.amount=amount;_last_amount=amount
	rain.emission_box_extents=Vector3(180*board_scale,2,180*board_scale)
	rain.emitting=current.rain>.02 and particle_level>0 and not reduced
	rain.visible=rain.emitting
	rain_material.albedo_color=Color(.65,.78,.88,current.rain*lerpf(.25,.43,daylight))
	lightning.visible=current.flash>.01 and not reduced
	lightning_light.light_energy=current.flash*2.5 if not reduced else 0.0
