class_name CatanDialog
extends Control
## A modal parchment card over a dimmed screen. Dialog scenes inherit
## dialog.tscn and add their content below the title.

signal close_requested

## Keeps the card near 580 px wide and scrolls content taller than the window.
func fit():
	for edge in ["left","right"]:%DialogMargin.add_theme_constant_override("margin_"+edge,maxi(20,int((size.x-580)/2)))
	%DialogScroll.custom_minimum_size.y=minf(%Body.get_combined_minimum_size().y,size.y-96)

func close():
	close_requested.emit()

## SpinBox keeps its text field internal, so its look cannot be authored in a scene.
static func style_amount(spin: SpinBox):
	var field=spin.get_line_edit()
	field.add_theme_font_size_override("font_size",20)
	field.add_theme_color_override("font_uneditable_color",Color("493521"))
