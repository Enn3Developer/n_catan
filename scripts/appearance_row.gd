extends PanelContainer
## One appearance field: its name and a control matching the field's kind.
## Choices show every option as a chip, so nothing hides behind a dropdown.

signal changed(key: String,value: Variant)

const DICE=preload("res://assets/icons/dice.svg")

var field: Dictionary
var control: Control
var chips=[]
var seed_value=0

func show_field(entry: Dictionary):
	field=entry
	name=entry.key.to_pascal_case()+"Row"
	%Title.text=entry.label
	if entry.key=="seed":
		# The seed only matters as "a different roll", so it gets a button, not a slider.
		%Title.text="Variation"
		var roll=Button.new()
		roll.text="New variation"
		roll.icon=DICE
		roll.add_theme_constant_override("icon_max_width",18)
		roll.tooltip_text="Same choices, rebuilt with different small differences"
		roll.pressed.connect(func():changed.emit(field.key,(seed_value+1+randi()%255)%256))
		control=roll
		%Value.show()
	else:
		match entry.kind:
			"range","count":
				var slider=HSlider.new()
				slider.min_value=0.0 if entry.kind=="range" else entry.min
				slider.max_value=1.0 if entry.kind=="range" else entry.max
				slider.step=.004 if entry.kind=="range" else 1
				slider.tick_count=entry.max-entry.min+1 if entry.kind=="count" and entry.max-entry.min<=6 else 0
				slider.ticks_on_borders=true
				slider.value_changed.connect(func(value):changed.emit(field.key,_from_slider(value)))
				control=slider
				%Value.show()
			"choice":
				%Chips.show()
				for i in entry.options.size():
					var chip=Button.new()
					chip.name=entry.options[i].to_pascal_case()
					chip.text=entry.options[i]
					chip.toggle_mode=true
					chip.custom_minimum_size=Vector2(0,32)
					chip.pressed.connect(func():show_value(i);changed.emit(field.key,i))
					%Chips.add_child(chip)
					chips.append(chip)
				return
			"toggle":
				var toggle=CheckButton.new()
				toggle.toggled.connect(func(on):changed.emit(field.key,on))
				control=toggle
			"color":
				var picker=ColorPickerButton.new()
				picker.edit_alpha=false
				picker.color_changed.connect(func(color):changed.emit(field.key,color.to_html(false)))
				control=picker
	control.name=name.trim_suffix("Row")
	control.custom_minimum_size=Vector2(60 if entry.kind=="toggle" else 170,34)
	control.size_flags_horizontal=Control.SIZE_SHRINK_END
	%Title.get_parent().add_child(control)

func _from_slider(value: float) -> Variant:
	if field.kind=="count":return int(value)
	return lerpf(field.min,field.max,value)

func show_value(value: Variant):
	if field.key=="seed":
		seed_value=int(value)
		%Value.text="#%d"%(int(value)+1)
		return
	match field.kind:
		"range":
			control.set_value_no_signal(inverse_lerp(field.min,field.max,value))
			%Value.text="%d°"%roundi(value) if field.key=="roof_pitch" else "%d%%"%roundi(value*100)
		"count":
			control.set_value_no_signal(value)
			%Value.text=str(value)
		"choice":
			for i in chips.size():chips[i].set_pressed_no_signal(i==int(value))
		"toggle":control.set_pressed_no_signal(value)
		"color":control.color=Color(value)
