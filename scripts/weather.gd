extends Node3D
# Weather uses the existing synchronized world clock and never changes game rules.
const CONDITIONS=[Vector3(.18,0,0),Vector3(.72,0,0),Vector3(.93,.65,0),Vector3(1,1,1)]
const KEYFRAMES=[0.0,100.0,190.0,240.0,290.0,340.0,390.0,440.0,500.0,560.0,600.0]
const STATES=[1,0,0,1,2,3,3,2,1,0,1]
@onready var rain: CPUParticles3D=$Rain
@onready var rain_material: StandardMaterial3D=$Rain.material_override
@onready var lightning: Node3D=$DistantLightning
@onready var lightning_light: OmniLight3D=$DistantLightning/LightningGlow
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
