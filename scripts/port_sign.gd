class_name CatanPortSign
extends Node3D
## A painted signboard on a post at the end of a harbor pier: the resource the
## harbor takes, its rate and its name, or "3:1" and "Any" for a harbor that
## takes anything. Icons come from tools/build_sign_icons.gd.
## The board turns on its post to face the camera; the post stays put.

const FONT=preload("res://assets/fonts/FiraSans-Medium.ttf")
const WOOD=Color("6b4a32")
# A dark painted face keeps every resource picture and the rate legible.
const PAINT=Color("35555a")
const INK=Color("f3e6c4")
# Leans the board back so the top-down camera sees its face.
const LEAN=-.6
const POST_HEIGHT=.36
const BOARD=Vector2(.5,.25)

var board: Node3D

static func make(resource: int) -> CatanPortSign:
	var port_sign=CatanPortSign.new()
	port_sign.name="PortSign"
	port_sign._build(resource)
	return port_sign

func _build(resource: int):
	var post=MeshInstance3D.new()
	post.name="Post"
	var post_mesh=CylinderMesh.new()
	post_mesh.top_radius=.015
	post_mesh.bottom_radius=.018
	post_mesh.height=POST_HEIGHT
	post_mesh.radial_segments=8
	post.mesh=post_mesh
	post.material_override=_material(WOOD)
	post.position.y=POST_HEIGHT*.5
	add_child(post)
	board=Node3D.new()
	board.name="Board"
	board.position.y=POST_HEIGHT
	add_child(board)
	# A painted plank in front of a wider wooden backing that shows as its frame.
	# The layers stand well apart: the board is scaled up about 25 times, and
	# closer faces fight in the depth buffer from the usual camera distance.
	var backing=MeshInstance3D.new()
	backing.name="Frame"
	var backing_mesh=BoxMesh.new()
	backing_mesh.size=Vector3(BOARD.x+.03,BOARD.y+.03,.02)
	backing.mesh=backing_mesh
	backing.material_override=_material(WOOD)
	backing.position.z=-.022
	board.add_child(backing)
	var plank=MeshInstance3D.new()
	plank.name="Plank"
	var plank_mesh=BoxMesh.new()
	plank_mesh.size=Vector3(BOARD.x,BOARD.y,.026)
	plank.mesh=plank_mesh
	plank.material_override=_material(PAINT)
	board.add_child(plank)
	var words=Vector2(0 if resource<0 else .075,0)
	board.add_child(_text("Rate","3:1" if resource<0 else "2:1",.0016,words+Vector2(0,.028)))
	board.add_child(_text("Name","Any" if resource<0 else CatanRules.RES[resource],.00095,words+Vector2(0,-.07)))
	if resource>=0:
		var art=Sprite3D.new()
		art.name="Resource"
		art.texture=load("res://assets/icons/sign/%s.png" % CatanIcons.RESOURCES[resource])
		art.pixel_size=.22/art.texture.get_width()
		art.shaded=true
		# Full sun would bleach the picture's colors on the dark board.
		art.modulate=Color(.82,.82,.82)
		art.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		art.double_sided=false
		art.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
		art.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		art.position=Vector3(-.125,0,.035)
		board.add_child(art)

## Painted lettering; Label3D translates its text, so the name follows the language.
func _text(node_name: String,text: String,pixel: float,at: Vector2) -> Label3D:
	var label=Label3D.new()
	label.name=node_name
	label.text=text
	label.font=FONT
	label.font_size=96
	label.pixel_size=pixel
	label.outline_size=0
	label.modulate=INK
	label.shaded=true
	label.double_sided=false
	label.alpha_cut=Label3D.ALPHA_CUT_DISCARD
	label.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	label.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.position=Vector3(at.x,at.y,.035)
	return label

func _material(tint: Color) -> StandardMaterial3D:
	var material=StandardMaterial3D.new()
	material.albedo_color=tint
	material.roughness=.9
	# The board leans towards the camera; shadows it cast on itself streaked its face.
	material.disable_receive_shadows=true
	return material

## Turns the board to the camera's heading, leaning back towards it.
func face(yaw: float):
	board.global_rotation=Vector3(LEAN,yaw,0)
