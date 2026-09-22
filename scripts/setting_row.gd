extends PanelContainer
## One preference: its name and the control that edits it. The option, toggle
## and slider variants inherit setting_row.tscn and add their control.

signal changed(spec: Array,value: Variant)
signal hovered(spec: Array)

@onready var control: Control=%Control
@onready var value_label: Label=get_node_or_null("%Value")
var spec: Array

## Configures the row from one settings_menu.gd OPTIONS entry and returns its control.
func show_spec(value_spec: Array) -> Control:
	spec=value_spec
	name=spec[1]+"Row"
	%Title.text=spec[3]
	control.name=spec[1]
	control.tooltip_text=spec[6]
	if control is OptionButton:
		for text in spec[5]: control.add_item(text)
	elif control is Range:
		control.min_value=spec[5][0]
		control.max_value=spec[5][1]
		control.step=spec[5][2]
		value_label.name=spec[1]+"Value"
	return control

func show_value(value: Variant):
	if control is OptionButton: control.select(value)
	elif control is CheckButton: control.set_pressed_no_signal(value)
	else:
		control.set_value_no_signal(value*spec[5][3])
		value_label.text="%.1f×" % value if spec[2]=="camera_speed" else "%d%%" % (value*100)

func _on_hovered():
	hovered.emit(spec)

func _on_choice(value: Variant):
	changed.emit(spec,value)

func _on_slide(value: float):
	changed.emit(spec,value/spec[5][3])
