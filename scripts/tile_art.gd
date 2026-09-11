class_name CatanTileArt
extends RefCounted
const BIOMES=["forest","hills","pasture","fields","mountains","desert"]
const GROUND=["forest_ground_04","brown_mud_dry","leafy_grass","brown_mud_dry","rock_ground","red_sand"]
const TINTS=[Color("768b62"),Color("be8b69"),Color("9cab71"),Color("bba276"),Color("93a0a1"),Color("d2b886")]
# Ground cover needs a darker value than the sunlit terrain to read at board scale.
const LEAVES={"PineNeedles":Color("426e57"),"PineTips":Color("588568"),"OakLeaves":Color("749455"),"OakLight":Color("8ba766"),"Grass":Color("417638"),"DryGrass":Color("84603c"),"Wheat":Color("dab15e"),"Fern":Color("476b3e"),"Moss":Color("6b8660")}
const SURFACES={"PBR_Rock":Color("83939d"),"PBR_Wood":Color("b39162"),"PBR_Bark":Color("74543c"),"PBR_Clay":Color("bd7655"),"Brick":Color("ba7555"),"Sandstone":Color("d0ac79"),"Plaster":Color("dfcba3"),"Roof":Color("657a85")}

var scenes={}
var materials={}
var maps={}
var terrain_meshes={}
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
		node.lod_bias=[.20,.5,1.0,2.0][values.model_quality]
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

func height_at(p: Vector2,kind: int) -> float:
	var edge=maxf(absf(p.x)/.866,maxf(absf(p.x*.5+p.y*.866)/.866,absf(-p.x*.5+p.y*.866)/.866))
	var height=[.045,.07,.04,.018,.10,.065][kind]
	var wave=.5+sin(p.x*6.0+kind)*cos(p.y*5.0)*.5
	var h=.20+pow(maxf(0,1-edge),1.3)*height*wave
	if kind==5:
		# Wind-shaped ripples grow into low dunes, fading into the clear tile boundary.
		h+=pow(maxf(0,1-edge),1.5)*(.018*sin(p.x*26+p.y*5)+.035*sin(p.x*8-p.y*6))
	return h

func terrain(kind: int,detail: int) -> ArrayMesh:
	var key="%d/%d" % [kind,detail]
	if terrain_meshes.has(key):return terrain_meshes[key]
	var steps=[12,20,32,48][detail]
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sector in 6:
		var a=Vector2(cos(deg_to_rad(30+60*sector)),sin(deg_to_rad(30+60*sector)))*.993
		var b=Vector2(cos(deg_to_rad(90+60*sector)),sin(deg_to_rad(90+60*sector)))*.993
		for i in steps:
			for j in range(steps-i):
				var p=a*float(i)/steps+b*float(j)/steps
				var q=a*float(i+1)/steps+b*float(j)/steps
				var r=a*float(i)/steps+b*float(j+1)/steps
				_ground_face(st,[p,q,r],kind)
				if i+j<steps-1:
					var t=a*float(i+1)/steps+b*float(j+1)/steps
					_ground_face(st,[q,t,r],kind)
	st.generate_normals()
	st.generate_tangents()
	terrain_meshes[key]=st.commit()
	return terrain_meshes[key]

func _ground_face(st: SurfaceTool,points: Array,kind: int):
	for p in points:
		st.set_uv(p*.5+Vector2(.5,.5))
		st.add_vertex(Vector3(p.x,height_at(p,kind),p.y))

func cliff_mesh(_index: int) -> ArrayMesh:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings=[Vector2(.993,.20),Vector2(.993,.16),Vector2(.988,-.40),Vector2(.955,-.44)]
	for sector in 6:
		var a=Vector2(cos(deg_to_rad(30+60*sector)),sin(deg_to_rad(30+60*sector)))
		var b=Vector2(cos(deg_to_rad(90+60*sector)),sin(deg_to_rad(90+60*sector)))
		for row in 3:
			var points=[Vector3(a.x*rings[row].x,rings[row].y,a.y*rings[row].x),Vector3(b.x*rings[row].x,rings[row].y,b.y*rings[row].x),Vector3(b.x*rings[row+1].x,rings[row+1].y,b.y*rings[row+1].x),Vector3(a.x*rings[row+1].x,rings[row+1].y,a.y*rings[row+1].x)]
			for i in [0,2,1,0,3,2]:
				st.set_uv(Vector2(points[i].x+points[i].z,points[i].y));st.add_vertex(points[i])
	st.generate_normals();st.generate_tangents();return st.commit()
