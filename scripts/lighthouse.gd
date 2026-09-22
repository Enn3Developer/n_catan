extends Node3D
## Offshore lighthouse whose lantern and sweeping beam come on at night.

@onready var lamp: MeshInstance3D=$Lamp
@onready var beacon: Node3D=$LighthouseBeacon
@onready var spot: SpotLight3D=$LighthouseBeacon/Spot
@onready var beam: MeshInstance3D=$LighthouseBeacon/Beam

func _ready():
	# Like the towns' lanterns, the glowing lamp records the light it casts.
	lamp.set_meta("night_light",$NightLight)

func shine(time: float,night: float):
	beacon.rotation.y=fposmod(time*.38,TAU)
	beacon.visible=night>.01
	spot.light_energy=night*5.0
	spot.spot_range=7.0*global_basis.get_scale().y
	lamp.material_override.emission_energy_multiplier=night*1.4
	beam.material_override.set_shader_parameter("strength",night)
