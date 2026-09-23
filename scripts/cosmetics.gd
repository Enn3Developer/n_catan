class_name CatanCosmetics
extends RefCounted

# Keep the deck close to the terrain while retaining the modeled trim.
const ROAD_HEIGHT_SCALE=.30
static func road_base_height(style: int) -> float:
	return .201+(.0375 if style==2 else .0275)*ROAD_HEIGHT_SCALE
static func road_deck_height(style: int) -> float:
	return road_base_height(style)+(.051 if style==2 else .0465)*ROAD_HEIGHT_SCALE

const SETS=["Voyager","Harbor","Citadel","Wildwood"]
const SET_DESCRIPTIONS=["Timber framing, tiled roofs and brass details. A classic island expedition.","Stilt houses, dock roads and a lantern tower. Built for life beside the sea.","Carved stone, battlements and heraldic shields. An island stronghold.","Log cabins, leafy roofs and a treehouse tower. A home among the trees."]
var materials={}

static func valid_set(id: int) -> bool:return id>=0 and id<SETS.size()

func material(color: Color) -> StandardMaterial3D:
	var key=str(color)
	if not materials.has(key):
		var m=StandardMaterial3D.new()
		m.albedo_color=color
		m.roughness=.82
		materials[key]=m
	return materials[key]

# Authored models name recolorable surfaces after a role, optionally followed by
# a signed percentage: "Player", "Player-16" (darkened .16), "Player+07" (lightened .07).
static func role_shade(material_name: String,role: String) -> Variant:
	if material_name==role:return 0.0
	var suffix=material_name.trim_prefix(role)
	if suffix.length()!=3 or suffix==material_name or not suffix[0] in ["+","-"] or not suffix.substr(1).is_valid_int():return null
	return (1 if suffix[0]=="+" else -1)*suffix.substr(1).to_int()/100.0

func paint(root: Node,color: Color,role: String="Player") -> Node:
	for node in root.find_children("*","MeshInstance3D",true,false):
		for i in node.mesh.get_surface_count():
			var base=node.mesh.surface_get_material(i)
			var shade=role_shade(base.resource_name,role) if base else null
			if shade==null:continue
			node.set_surface_override_material(i,material(color.darkened(-shade) if shade<0 else color.lightened(shade)))
	return root

func model(path: String,label: String,style: int,color: Color) -> Node3D:
	var root: Node3D=load(path).instantiate()
	root.name=label
	root.set_meta("cosmetic",style)
	return paint(root,color)

func settlement(style: int,color: Color,city: bool=false) -> Node3D:
	style=clampi(style,0,SETS.size()-1)
	var kind="city" if city else "settlement"
	return model("res://assets/models/pieces/%s_%s.glb"%[SETS[style].to_lower(),kind],("City_" if city else "Settlement_")+SETS[style],style,color)

func road(style: int,color: Color) -> Node3D:
	style=clampi(style,0,SETS.size()-1)
	return model("res://assets/models/pieces/%s_road.glb"%SETS[style].to_lower(),"Road_"+SETS[style],style,color)

func road_joint(style: int,color: Color) -> Node3D:
	style=clampi(style,0,SETS.size()-1)
	# A small round cap closes bends and three-way branches without overlapping faces.
	return model("res://assets/models/pieces/%s_road_joint.glb"%SETS[style].to_lower(),"RoadJoint",style,color)
