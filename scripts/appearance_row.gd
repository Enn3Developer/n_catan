extends PanelContainer
## One appearance field: its name and a control matching the field's kind.

signal changed(key: String,value: Variant)

var field: Dictionary
var control: Control

func show_field(entry: Dictionary):
	field=entry
	name=entry.key.to_pascal_case()+"Row"
	%Title.text=entry.label
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
			var options=OptionButton.new()
			for option in entry.options:options.add_item(option)
			options.item_selected.connect(func(index):changed.emit(field.key,index))
			control=options
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
	control.custom_minimum_size=Vector2(170 if entry.kind!="toggle" else 60,34)
	control.size_flags_horizontal=Control.SIZE_SHRINK_END
	$Row.add_child(control)
	$Row.move_child(control,1)

func _from_slider(value: float) -> Variant:
	if field.kind=="count":return int(value)
	return lerpf(field.min,field.max,value)

func show_value(value: Variant):
	match field.kind:
		"range":
			control.set_value_no_signal(inverse_lerp(field.min,field.max,value))
			%Value.text="%d°"%roundi(value) if field.key=="roof_pitch" else "%d%%"%roundi(value*100)
		"count":
			control.set_value_no_signal(value)
			%Value.text=str(value)
		"choice":control.select(value)
		"toggle":control.set_pressed_no_signal(value)
		"color":control.color=Color(value)
