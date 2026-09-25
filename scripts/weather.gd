extends Node3D
# Weather uses the existing synchronized world clock and never changes game rules.
# Clear, cloudy, rain, thunderstorm, then drizzle; x clouds, y rain, z storm.
const CONDITIONS=[Vector3(.18,0,0),Vector3(.72,0,0),Vector3(.93,.65,0),Vector3(1,1,1),Vector3(.86,.28,0)]
## Each ten-minute day follows one of these outlines, picked from the map seed
## and the day number, so the sky changes from day to day but every player
## sees the same one. Pairs are [second, condition]; every day opens and
## closes clear so days join without a jump.
const DAYS=[
	[[0,0],[210,0],[260,1],[330,1],[380,0],[600,0]],
	[[0,0],[120,1],[190,2],[250,2],[310,1],[420,0],[470,1],[515,4],[560,1],[600,0]],
	[[0,0],[90,1],[170,2],[220,3],[330,3],[380,2],[450,1],[540,0],[600,0]],
	[[0,0],[70,1],[160,4],[300,4],[430,1],[520,0],[600,0]],
	[[0,0],[140,0],[200,1],[280,0],[400,1],[460,2],[520,1],[600,0]],
]
const DAY_WEIGHTS=[4,3,2,2,3]
## Storm strikes land in slots of this many seconds; about half the slots get one.
const STRIKE_SLOT=24.0
@onready var rain: GPUParticles3D=$Rain
@onready var rain_material: StandardMaterial3D=$Rain.material_override
@onready var lightning: Node3D=$DistantLightning
@onready var lightning_light: OmniLight3D=$DistantLightning/LightningGlow
var current={"clouds":0.0,"rain":0.0,"storm":0.0,"flash":0.0,"thunder":false}
var _last_amount=-1

## A stable 0..1 value for a few integers; the same on every machine.
static func _hash(a: int,b: int,c: int) -> float:
	var h=(a*73856093)^(b*19349663)^(c*83492791)
	h=(h^(h>>13))*1274126177
	return float((h^(h>>16))&0xffff)/65535.0

static func day_outline(day: int,seed: int) -> int:
	var total=0
	for w in DAY_WEIGHTS:total+=w
	var pick=_hash(seed,day,7)*total
	for i in DAY_WEIGHTS.size():
		pick-=DAY_WEIGHTS[i]
		if pick<0:return i
	return 0

static func sample(seconds: float,mode: int=0,day: int=0,seed: int=0) -> Dictionary:
	var value=CONDITIONS[clampi(mode-1,0,3)]
	var time=fposmod(seconds,600.0)
	if mode==0:
		var outline: Array=DAYS[day_outline(day,seed)]
		# Inner keys drift by up to 20 seconds, so repeated outlines differ a
		# little. Keys sit at least 45 seconds apart, so they never swap.
		var keys=[]
		for i in outline.size():
			keys.append(float(outline[i][0])+(0.0 if i==0 or i==outline.size()-1 else (_hash(seed,day,i)-.5)*40.0))
		for i in outline.size()-1:
			if time<=keys[i+1]:
				value=CONDITIONS[outline[i][1]].lerp(CONDITIONS[outline[i+1][1]],smoothstep(keys[i],keys[i+1],time))
				break
	# Strikes come at uneven times and places. Far ones rumble later and softer.
	var slot=int(floor(time/STRIKE_SLOT))
	var chance=_hash(seed,day*50+slot,11)
	var offset=_hash(seed,day*50+slot,13)*(STRIKE_SLOT-8.0)
	var distance=_hash(seed,day*50+slot,17)
	var phase=time-slot*STRIKE_SLOT-offset
	var storm_gate=smoothstep(.65,.95,value.z)
	var strikes=chance<.55 and storm_gate>0.0
	# A main flash and a weaker return stroke just after it.
	var flash=0.0
	if strikes and phase>=0.0:
		flash=maxf(1.0-smoothstep(.0,.18,phase),.6*(1.0-smoothstep(.2,.36,phase))*smoothstep(.12,.2,phase))*storm_gate*lerpf(1.0,.55,distance)
	var delay=1.2+distance*4.0
	return {"clouds":value.x,"sun_visibility":1.0-smoothstep(.28,.68,value.x),"rain":value.y,"storm":value.z,"flash":flash,
		"strike":day*50+slot,"strike_angle":_hash(seed,day*50+slot,19)*TAU,"strike_distance":distance,
		"thunder":strikes and value.z>.65 and phase>=delay and phase<delay+1.5}

func update_weather(seconds: float,daylight: float,values: Dictionary,board_scale: float,day: int=0,seed: int=0):
	current=sample(seconds,int(values.get("weather",0)),day,seed)
	var reduced=values.get("reduce_motion",false)
	var particle_level=int(values.get("particles",2))
	var amount=[1,400,1300][clampi(particle_level,0,2)]
	if amount!=_last_amount:rain.amount=amount;_last_amount=amount
	if not is_equal_approx(rain.process_material.emission_box_extents.x,180*board_scale):
		rain.process_material.emission_box_extents=Vector3(180*board_scale,2,180*board_scale)
		# Drops fall about 100 units from the emitter before they expire.
		rain.visibility_aabb=AABB(Vector3(-200*board_scale,-100,-200*board_scale),Vector3(400*board_scale,104,400*board_scale))
	rain.emitting=current.rain>.02 and particle_level>0 and not reduced
	rain.visible=rain.emitting
	rain_material.albedo_color=Color(.65,.78,.88,current.rain*lerpf(.25,.43,daylight))
	# Wind leans the rain harder as a storm builds.
	rain.process_material.direction=Vector3(.13+.3*current.storm,-1,.05+.12*current.storm)
	lightning.visible=current.flash>.01 and not reduced
	lightning.rotation.y=current.strike_angle
	lightning.scale=Vector3.ONE*board_scale*lerpf(.85,1.5,current.strike_distance)
	lightning_light.light_energy=current.flash*2.5 if not reduced else 0.0
