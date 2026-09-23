class_name CatanBackgroundLandscape
extends Node3D
# The mainland around the lake, authored in assets/source/mainland.blend. Its
# twelve sectors let the renderer cull the ones behind the camera.
var material: ShaderMaterial
var sectors=[]
func _init():
	material=ShaderMaterial.new();material.shader=load("res://shaders/background_landscape.gdshader")

func _ready():
	# A dedicated server never renders the backdrop, so skip loading it.
	if "--server" in OS.get_cmdline_user_args():return
	var mainland: Node3D=load("res://assets/models/world/mainland.glb").instantiate()
	add_child(mainland)
	sectors=mainland.find_children("MainlandSector*","MeshInstance3D",true,false)
	for sector in sectors:
		sector.material_override=material
		sector.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sector.gi_mode=GeometryInstance3D.GI_MODE_DISABLED

func set_daylight(amount: float):
	material.set_shader_parameter("haze_color",Color("20344e").lerp(Color("88a6a5"),amount))
