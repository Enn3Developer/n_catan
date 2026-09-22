extends Button
## A player color choice painted in its own color, with ink that stays readable on it.

func show_color(color: Color,color_name: String):
	tooltip_text=tr(color_name)
	var ink=Color("101820") if color.get_luminance()>.35 else Color.WHITE
	for state in ["normal","hover","pressed","hover_pressed","focus"]:
		var surface: StyleBoxFlat=get_theme_stylebox(state)
		surface.bg_color=color
		surface.border_color=ink
	for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:
		add_theme_color_override(state,ink)
