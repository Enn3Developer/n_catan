class_name CatanTileArt
extends RefCounted
const BIOMES=["forest","hills","pasture","fields","mountains","desert"]
const GROUND=["forest_ground_04","brown_mud_dry","leafy_grass","brown_mud_dry","rock_ground","red_sand"]
const TINTS=[Color("768b62"),Color("be8b69"),Color("9cab71"),Color("bba276"),Color("93a0a1"),Color("d2b886")]
# Ground cover needs a darker value than the sunlit terrain to read at board scale.
const LEAVES={"PineNeedles":Color("426e57"),"PineTips":Color("588568"),"OakLeaves":Color("749455"),"OakLight":Color("8ba766"),"Grass":Color("417638"),"DryGrass":Color("84603c"),"Wheat":Color("dab15e"),"Fern":Color("476b3e"),"Moss":Color("6b8660")}
const SURFACES={"PBR_Rock":Color("83939d"),"PBR_Wood":Color("b39162"),"PBR_Bark":Color("74543c"),"PBR_Clay":Color("bd7655"),"Brick":Color("ba7555"),"Sandstone":Color("d0ac79"),"Plaster":Color("dfcba3"),"Roof":Color("657a85")}

# Ground and cliff meshes are authored in assets/source/terrain.blend.
const GROUNDS=[preload("res://assets/models/terrain/ground_forest.glb"),preload("res://assets/models/terrain/ground_hills.glb"),preload("res://assets/models/terrain/ground_pasture.glb"),preload("res://assets/models/terrain/ground_fields.glb"),preload("res://assets/models/terrain/ground_mountains.glb"),preload("res://assets/models/terrain/ground_desert.glb")]
const CLIFF=preload("res://assets/models/terrain/cliff.glb")
# Ground heights are sampled from the mesh on a grid spanning the tile's [-1,1] square.
const HEIGHT_GRID=128
const RIM_HEIGHT=.20

var scenes={}
var materials={}
var maps={}
var meshes={}
var height_fields={}
var texture_quality=2

func configure(values: Dictionary):
	if texture_quality!=values.texture_quality:
		texture_quality=values.texture_quality
		materials.clear()
		maps.clear()

func texture(asset: String,channel: String) -> Texture2D:
	var key="%d/%s/%s" % [[512,1024,2048][texture_quality],asset,channel]
	if not maps.has(key):
		maps[key]=load("res://assets/materials/runtime/"+key+".jpg")
	return maps[key]

func bind_maps(material: ShaderMaterial,asset: String,channels: Array):
	# Load only maps sampled by this shader; unused authoring maps stay out of exports.
	for channel in channels:
		material.set_shader_parameter(channel+"_map",texture(asset,channel))

func ground(kind: int,index: int) -> ShaderMaterial:
	var material=ShaderMaterial.new()
	material.shader=load("res://shaders/premium_ground.gdshader")
	bind_maps(material,GROUND[kind],["albedo","normal","orm"])
	material.set_shader_parameter("terrain_kind",float(kind))
	material.set_shader_parameter("variation",float(index%7))
	material.set_shader_parameter("tint",TINTS[kind])
	var paths=PackedVector4Array()
	for route in CatanWorldLayout.biome(kind).paths:
		for step in range(1,route.size()):
			var a=route[step-1];var b=route[step]
			paths.append(Vector4(a[0],a[1],b[0],b[1]))
	material.set_shader_parameter("footpath_count",mini(paths.size(),16))
	while paths.size()<16:paths.append(Vector4.ZERO)
	material.set_shader_parameter("footpaths",paths)
	return material

func cliff() -> ShaderMaterial:
	if not materials.has("cliff"):
		var material=ShaderMaterial.new()
		material.shader=load("res://shaders/premium_cliff.gdshader")
		bind_maps(material,"rock_boulder_dry",["albedo","normal"])
		materials.cliff=material
	return materials.cliff

func surface(name: String,base: Material,values: Dictionary) -> Material:
	name=name.get_slice(".",0)
	if materials.has(name):return materials[name]
	if LEAVES.has(name):
		var leaf=ShaderMaterial.new()
		leaf.shader=load("res://shaders/premium_foliage.gdshader")
		leaf.set_shader_parameter("leaf_color",LEAVES[name])
		leaf.set_shader_parameter("soft_blades",name in ["Grass","DryGrass","Fern","Wheat"])
		leaf.set_shader_parameter("flexibility",.018 if name in ["Wheat","Grass","DryGrass","Fern"] else .008)
		leaf.set_shader_parameter("motion_speed",0.0 if values.reduce_motion else values.wind)
		materials[name]=leaf
		return leaf
	var sources={"PBR_Rock":"rock_boulder_dry","PBR_Wood":"weathered_brown_planks","PBR_Bark":"pine_bark","PBR_Clay":"brown_mud_dry","Brick":"brown_mud_dry","Sandstone":"rock_ground","Plaster":"rock_ground","Roof":"weathered_brown_planks"}
	if sources.has(name):
		var surface_material=ShaderMaterial.new()
		surface_material.shader=load("res://shaders/premium_surface.gdshader")
		bind_maps(surface_material,sources[name],["albedo"])
		surface_material.set_shader_parameter("tint",SURFACES[name])
		surface_material.set_shader_parameter("texture_scale",2.0)
		surface_material.set_shader_parameter("texture_strength",.10)

		materials[name]=surface_material
		return surface_material
	var material=base.duplicate() if base else StandardMaterial3D.new()
	if material is StandardMaterial3D:
		material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		material.roughness=.82
		if name=="Iron":material.metallic=.7;material.roughness=.34
		if name=="Ore":material.metallic=.35;material.roughness=.48
		if name=="Water":material.roughness=.12
	materials[name]=material
	return material

func instantiate(kind: int,index: int,values: Dictionary) -> Node3D:
	var key="%s_%d" % [BIOMES[kind],index%2]
	if not scenes.has(key):scenes[key]=load("res://assets/premium/"+key+".glb")
	var root=scenes[key].instantiate()
	root.name="Diorama_%s" % key
	apply_instance(root,values)
	return root

func apply_instance(root: Node,values: Dictionary):
	for node in root.find_children("*","MeshInstance3D",true,false):
		node.lod_bias=lod_bias(values)
		node.gi_mode=GeometryInstance3D.GI_MODE_STATIC
		var layer=str(node.name)
		node.visible=true
		if layer.begins_with("GroundCover"):
			var part=layer.split("__")[0].trim_prefix("GroundCover")
			node.visible=int(part)<=values.foliage_quality if part.is_valid_int() else values.foliage_quality>=1
		if layer.begins_with("Micro"):node.visible=values.model_quality>=2 and values.foliage_quality>=2
		if layer.begins_with("SmallDetails"):node.visible=values.model_quality>=1
		if str(root.name).contains("pasture") and (layer.contains("__Wool") or layer.contains("__Skin") or layer.contains("__Dark")):node.visible=false
		for i in node.mesh.get_surface_count():
			var base=node.mesh.surface_get_material(i)
			var material_name=base.resource_name if base else ""
			node.set_surface_override_material(i,surface(material_name,base,values))
		if layer.begins_with("GroundCover") or layer.begins_with("Micro"):
			node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if values.foliage_quality==3 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func animate(values: Dictionary):
	for key in LEAVES:
		if materials.has(key):materials[key].set_shader_parameter("motion_speed",0.0 if values.reduce_motion else values.wind)

static func lod_bias(values: Dictionary) -> float:
	return [.20,.5,1.0,2.0][values.model_quality]

func ground_mesh(kind: int) -> Mesh:
	if not meshes.has(kind):meshes[kind]=_model_mesh(GROUNDS[kind])
	return meshes[kind]

func cliff_mesh() -> Mesh:
	if not meshes.has("cliff"):meshes.cliff=_model_mesh(CLIFF)
	return meshes.cliff

static func _model_mesh(model: PackedScene) -> Mesh:
	var root=model.instantiate()
	var mesh: Mesh=root.find_children("*","MeshInstance3D",true,false)[0].mesh
	root.free()
	return mesh

# Height of the authored ground under a point in tile space.
func height_at(p: Vector2,kind: int) -> float:
	var field: PackedFloat32Array=_height_field(kind)
	var cell=((p+Vector2.ONE)*.5*(HEIGHT_GRID-1)).clamp(Vector2.ZERO,Vector2.ONE*(HEIGHT_GRID-1))
	var x=mini(int(cell.x),HEIGHT_GRID-2);var y=mini(int(cell.y),HEIGHT_GRID-2)
	var t=cell-Vector2(x,y)
	var near=lerpf(field[y*HEIGHT_GRID+x],field[y*HEIGHT_GRID+x+1],t.x)
	var far=lerpf(field[(y+1)*HEIGHT_GRID+x],field[(y+1)*HEIGHT_GRID+x+1],t.x)
	return lerpf(near,far,t.y)

# Rasterizes the ground triangles once per biome; points off the tile keep the rim height.
func _height_field(kind: int) -> PackedFloat32Array:
	if height_fields.has(kind):return height_fields[kind]
	var field=PackedFloat32Array();field.resize(HEIGHT_GRID*HEIGHT_GRID);field.fill(RIM_HEIGHT)
	var arrays=ground_mesh(kind).surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var to_grid=.5*(HEIGHT_GRID-1)
	for i in range(0,indices.size(),3):
		var a=vertices[indices[i]];var b=vertices[indices[i+1]];var c=vertices[indices[i+2]]
		var pa=(Vector2(a.x,a.z)+Vector2.ONE)*to_grid;var pb=(Vector2(b.x,b.z)+Vector2.ONE)*to_grid;var pc=(Vector2(c.x,c.z)+Vector2.ONE)*to_grid
		var area=(pb-pa).cross(pc-pa)
		if absf(area)<1e-9:continue
		for gy in range(maxi(ceili(minf(pa.y,minf(pb.y,pc.y))),0),mini(floori(maxf(pa.y,maxf(pb.y,pc.y))),HEIGHT_GRID-1)+1):
			for gx in range(maxi(ceili(minf(pa.x,minf(pb.x,pc.x))),0),mini(floori(maxf(pa.x,maxf(pb.x,pc.x))),HEIGHT_GRID-1)+1):
				var g=Vector2(gx,gy)
				var wa=(pb-g).cross(pc-g)/area;var wb=(pc-g).cross(pa-g)/area
				var wc=1.0-wa-wb
				if wa<-1e-4 or wb<-1e-4 or wc<-1e-4:continue
				field[gy*HEIGHT_GRID+gx]=a.y*wa+b.y*wb+c.y*wc
	height_fields[kind]=field
	return field
