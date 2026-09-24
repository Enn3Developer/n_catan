extends HBoxContainer
## Five resource tiles, one of which is chosen. Each tile shows the resource's
## illustration above its name.

signal changed(resource: int)

var selected=0:
	set(value):
		selected=value
		if get_child_count()==5:
			for resource in 5:get_child(resource).set_pressed_no_signal(resource==value)

## Replaces each tile's caption, which starts as the resource name.
func set_captions(texts: Array):
	for resource in 5:
		get_child(resource).text=texts[resource]
		# A second line of caption needs room under the illustration.
		get_child(resource).custom_minimum_size.y=78+22*str(texts[resource]).count("\n")

## Greys out tiles that can't be chosen; a tooltip on each says why.
func set_unavailable(reasons: Array):
	for resource in 5:
		get_child(resource).disabled=not str(reasons[resource]).is_empty()
		get_child(resource).tooltip_text=reasons[resource]

func _ready():
	var group=ButtonGroup.new()
	for resource in 5:
		var tile=Button.new()
		tile.toggle_mode=true
		tile.button_group=group
		tile.text=tr(CatanRules.RES[resource])
		tile.icon=CatanIcons.resource_icon(resource)
		tile.expand_icon=true
		tile.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP
		tile.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
		tile.custom_minimum_size=Vector2(0,78)
		tile.size_flags_horizontal=SIZE_EXPAND_FILL
		tile.mouse_default_cursor_shape=CURSOR_POINTING_HAND
		tile.add_theme_constant_override("icon_max_width",34)
		# Illustrations keep their own colors; the theme would tint them like ink glyphs.
		for key in ["icon_normal_color","icon_hover_color","icon_pressed_color","icon_hover_pressed_color","icon_focus_color"]:
			tile.add_theme_color_override(key,Color.WHITE)
		tile.add_to_group("ui_click")
		tile.toggled.connect(func(on):if on:
			selected=resource
			changed.emit(resource))
		add_child(tile)
	get_child(selected).set_pressed_no_signal(true)
