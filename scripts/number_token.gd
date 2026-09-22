extends Node3D
## A tile's number disc with one pip per dice combination; 6 and 8 are red.

@export var hot_pip: Material
@export var cold_pip: Material

func show_number(number: int):
	var count=6-absi(7-number)
	var pip_material=hot_pip if number in [6,8] else cold_pip
	for i in $Pips.get_child_count():
		var pip: MeshInstance3D=$Pips.get_child(i)
		pip.visible=i<count
		pip.position.x=(i-(count-1)*.5)*.033
		pip.material_override=pip_material
