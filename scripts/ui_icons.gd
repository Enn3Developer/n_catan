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
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",4 if pixels<=18 else 10)
	parent.add_child(row)
	for i in 5:
		if not show_zero and amounts[i]<=0:continue
		var badge=HBoxContainer.new()
		badge.name=RESOURCES[i].capitalize()+"Badge"
		badge.tooltip_text="%s: %d" % [TranslationServer.translate(CatanRules.RES[i]),amounts[i]]
		badge.mouse_filter=Control.MOUSE_FILTER_STOP
		badge.size_flags_horizontal=Control.SIZE_EXPAND_FILL if show_zero else Control.SIZE_SHRINK_CENTER
		badge.alignment=BoxContainer.ALIGNMENT_CENTER
		badge.add_theme_constant_override("separation",4)
		row.add_child(badge)
		icon(badge,RESOURCES[i],pixels)
		if pixels<=18 and amounts[i]==1:continue
		var count=Label.new()
		count.text=str(amounts[i])
		count.add_theme_font_size_override("font_size",24 if pixels>=32 else 14)
		badge.add_child(count)
	return row
static func button_icon(button: Button,key: String,pixels: int=22):
	button.icon=get_icon(key)
	button.expand_icon=true
	button.add_theme_constant_override("icon_max_width",pixels)
	button.add_theme_constant_override("h_separation",6)
	var font=button.get_theme_font("font")
	var text_width=font.get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x
	button.custom_minimum_size.x=maxf(button.custom_minimum_size.x,text_width+pixels+button.get_theme_stylebox("normal").get_minimum_size().x+(6 if not button.text.is_empty() else 0))
