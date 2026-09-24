extends OptionButton
## A resource dropdown showing each resource's illustration.

func _ready():
	# Illustrations keep their own colors; the theme would tint them like ink glyphs.
	for key in ["icon_normal_color","icon_hover_color","icon_pressed_color","icon_hover_pressed_color","icon_focus_color"]:
		add_theme_color_override(key,Color.WHITE)
	add_theme_color_override("icon_disabled_color",Color(1,1,1,.5))
	for resource in 5:
		add_icon_item(CatanIcons.resource_icon(resource),tr(CatanRules.RES[resource]))
		get_popup().set_item_icon_max_width(resource,26)
