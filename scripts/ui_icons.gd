class_name CatanIcons
extends RefCounted
const RESOURCES=["timber","brick","wool","grain","ore"]
static var textures={}
static func get_icon(key: String) -> Texture2D:
	if not textures.has(key):textures[key]=load("res://assets/icons/%s.svg" % key)
	return textures[key]
static func resource_icon(id: int) -> Texture2D:return get_icon(RESOURCES[id])
static func icon(parent: Node,key: String,pixels: int=24) -> TextureRect:
	var image=TextureRect.new()
	image.texture=get_icon(key)
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size=Vector2.ONE*pixels
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image
static func resources(parent: Node,amounts: Array,pixels: int=24,show_zero: bool=false) -> HBoxContainer:
	var row=load("res://scenes/ui/resource_row.tscn").instantiate()
	row.icon_size=pixels
	row.show_zero=show_zero
	parent.add_child(row)
	row.show_amounts(amounts)
	return row
static func button_icon(button: Button,key: String,pixels: int=22):
	button.icon=get_icon(key)
	# Resource illustrations already carry color; theme ink must not multiply it.
	if key in RESOURCES:
		for state in ["normal","hover","pressed","hover_pressed"]:
			button.add_theme_color_override("icon_"+state+"_color",Color.WHITE)
	button.expand_icon=true
	button.add_theme_constant_override("icon_max_width",pixels)
	button.add_theme_constant_override("h_separation",6)
	var font=button.get_theme_font("font")
	var text_width=font.get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x
	button.custom_minimum_size.x=maxf(button.custom_minimum_size.x,text_width+pixels+button.get_theme_stylebox("normal").get_minimum_size().x+(6 if not button.text.is_empty() else 0))
