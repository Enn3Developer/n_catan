class_name CatanModelTint
extends RefCounted
## Recolours authored models (dwellers, workers, outlaws) by material role.

var materials={}

func material(color: Color) -> StandardMaterial3D:
	var key=str(color)
	if not materials.has(key):
		var m=StandardMaterial3D.new()
		m.albedo_color=color
		m.roughness=.82
		materials[key]=m
	return materials[key]

# Authored models name recolorable surfaces after a role, optionally followed by
# a signed percentage: "Shirt", "Shirt-16" (darkened .16), "Shirt+07" (lightened .07).
static func role_shade(material_name: String,role: String) -> Variant:
	if material_name==role:return 0.0
	var suffix=material_name.trim_prefix(role)
	if suffix.length()!=3 or suffix==material_name or not suffix[0] in ["+","-"] or not suffix.substr(1).is_valid_int():return null
	return (1 if suffix[0]=="+" else -1)*suffix.substr(1).to_int()/100.0

func paint(root: Node,color: Color,role: String) -> Node:
	for node in root.find_children("*","MeshInstance3D",true,false):
		for i in node.mesh.get_surface_count():
			var base=node.mesh.surface_get_material(i)
			var shade=role_shade(base.resource_name,role) if base else null
			if shade==null:continue
			node.set_surface_override_material(i,material(color.darkened(-shade) if shade<0 else color.lightened(shade)))
	return root
