extends Node3D
## Offshore lighthouse whose lantern and sweeping beam come on at night.
## The beam is the spot light itself, scattering in the sea haze around the tower.

const HAZE_DENSITY=.012

@onready var lamp: MeshInstance3D=$Lamp
@onready var beacon: Node3D=$LighthouseBeacon
@onready var spot: SpotLight3D=$LighthouseBeacon/Spot
@onready var haze: FogVolume=$SeaHaze
@onready var rowboat: Node3D=$Rowboat

func _ready():
	# Like the towns' lanterns, the glowing lamp records the light it casts.
	lamp.set_meta("night_light",$NightLight)

func shine(time: float,night: float):
	beacon.rotation.y=fposmod(time*.38,TAU)
	beacon.visible=night>.01
	spot.light_energy=night*18.0
	spot.spot_range=7.0*global_basis.get_scale().y
	lamp.material_override.emission_energy_multiplier=night*1.4
	# Evening haze gathers over the water, so the beam only shows after dusk.
	haze.material.density=HAZE_DENSITY*night

## Rests the rowboat at the calm water line, rolling gently; the board then adds the swell.
func moor(water_y: float,time: float):
	var at=rowboat.global_position
	rowboat.position.y=to_local(Vector3(at.x,water_y,at.z)).y
	rowboat.rotation.z=sin(time*.9)*.04
	rowboat.rotation.x=sin(time*.7+1.3)*.025
