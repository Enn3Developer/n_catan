extends Node3D
## A tile's number disc: the number printed on its face and one pip per dice
## combination below it; 6 and 8 are red. The board turns the disc to face the
## camera, so the print reads upright from every side.

const FONT=preload("res://assets/fonts/NotoSerif-Medium.ttf")
const INK=Color("1f1a12")
const HOT_INK=Color("8a2a1c")
# Just above the disc's face (.2625). The gap keeps the print from flickering
# into the disc at a distance once the board scales the token up.
const FACE=.268

@export var hot_pip: Material
@export var cold_pip: Material
var print_label: Label3D
var number=0

func show_number(value: int):
	number=value
	var count=6-absi(7-number)
	var pip_material=hot_pip if number in [6,8] else cold_pip
	for i in $Pips.get_child_count():
		var pip: MeshInstance3D=$Pips.get_child(i)
		pip.visible=i<count
		pip.position.x=(i-(count-1)*.5)*.033
		pip.position.z=.105
		pip.material_override=pip_material
	if print_label==null:
		print_label=Label3D.new()
		print_label.name="Number"
		add_child(print_label)
	print_label.text=str(number)
	print_label.font=FONT
	print_label.font_size=128
	# Likelier rolls print larger, like the tokens on a real table.
	print_label.pixel_size=.0016+.00005*count
	print_label.outline_size=0
	print_label.modulate=HOT_INK if number in [6,8] else INK
	# Printed ink takes the scene's light, so it dims at dusk with the disc.
	print_label.shaded=true
	print_label.double_sided=false
	print_label.alpha_cut=Label3D.ALPHA_CUT_DISCARD
	print_label.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	print_label.rotation.x=-PI/2
	print_label.position=Vector3(0,FACE,-.03)
