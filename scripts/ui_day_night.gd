extends Node
## Keeps the interface on the same clock as the island, without rebuilding UI.

const PALETTE={
	"493521":"eee5d2", "392818":"fff3dc", "796347":"b8bec6",
	"8c522d":"d6b878", "8b7b63":"89929f", "8a775c":"929dab",
	"263c36":"e3e9df", "44574b":"b7c4bd",
	"fff1d3":"253344", "fff5df":"2d3e51", "f4e2bb":"253344",
	"f3deb4":"293749", "f6e4be":"283647", "f8e8c6":"2b394b",
	"e4c18c":"35465a", "f2d4a0":"43586d", "ccdbb2":"405641",
	"eedab0":"253344", "eee1bb":"2b3a49", "fff1ce":"30404f",
	"ac8654":"657387", "b49668":"657387", "6b834f":"8ba57a",
	"795635":"748197", "b5a07b":"1c2938", "91734d":"526276",
	"6d8958":"789568", "496340":"566e4f", "b77633":"d6b878",
	"526747":"9fbb8d", "b4c696":"506944",
}

var amount=0.0
var root: Control
var palette_theme: Theme
var bindings: Array=[]
var registered_styles={}
var textures={}
@onready var atlas: SubViewport=$Atlas
var materials: Array[ShaderMaterial]=[]
const NIGHT_SHADER=preload("res://shaders/ui_night.gdshader")
var symbol_material: ShaderMaterial
var pending: Array[WeakRef]=[]
const OUTLINED_TYPES=["Label","Button","OptionButton","CheckButton","CheckBox","LineEdit","PopupMenu","TooltipLabel"]

func setup(control: Control):
	root=control
	palette_theme=root.theme.duplicate(true)
	root.theme=palette_theme
	for type in OUTLINED_TYPES:
		palette_theme.set_constant("outline_size",type,4)
		palette_theme.set_color("font_outline_color",type,Color(0.04,0.06,0.09,0))
	symbol_material=ShaderMaterial.new()
	symbol_material.shader=NIGHT_SHADER
	symbol_material.set_shader_parameter("icon",true)
	symbol_material.set_shader_parameter("symbol",true)
	materials.append(symbol_material)
	for type in palette_theme.get_color_type_list():
		for key in palette_theme.get_color_list(type):
			var day=palette_theme.get_color(key,type)
			var dark=_night_color(day)
			if day!=dark:bindings.append([weakref(palette_theme),key,day,dark,type])
	for type in palette_theme.get_stylebox_type_list():
		for key in palette_theme.get_stylebox_list(type):
			_register_style(palette_theme.get_stylebox(key,type))
	for type in palette_theme.get_icon_type_list():
		for key in palette_theme.get_icon_list(type):
			palette_theme.set_icon(key,type,_texture(palette_theme.get_icon(key,type)))
	get_tree().node_added.connect(_node_added)
	_scan(root)

func _night_color(day: Color) -> Color:
	# Only interface palette colors change; player and resource colors stay intact.
	var key=day.to_html(false)
	if not PALETTE.has(key):return day
	var result=Color(PALETTE[key])
	result.a=day.a
	return result

func _text_amount() -> float:
	# Bring up the light lettering before the surfaces finish darkening.
	return smoothstep(0.0,0.6,amount)

func _texture(source: Texture2D) -> Texture2D:
	var key=source.get_instance_id()
	if textures.has(key):return textures[key]
	var slot=textures.size()
	var position=Vector2((slot%5)*100,(slot/5)*100)
	var rect=TextureRect.new()
	rect.texture=source
	rect.position=position
	rect.size=source.get_size()
	var material=ShaderMaterial.new()
	material.shader=NIGHT_SHADER
	material.set_shader_parameter("night",amount)
	material.set_shader_parameter("accent","primary" in source.resource_path or "pressed" in source.resource_path)
	material.set_shader_parameter("icon",not "button" in source.resource_path and not "parchment" in source.resource_path)
	rect.material=material
	atlas.add_child(rect)
	materials.append(material)
	var texture=AtlasTexture.new()
	texture.atlas=atlas.get_texture()
	texture.region=Rect2(position,source.get_size())
	texture.filter_clip=true
	textures[key]=texture
	return texture

func _register_style(style: StyleBox):
	var id=style.get_instance_id()
	if registered_styles.has(id) and registered_styles[id].get_ref()==style:return
	registered_styles[id]=weakref(style)
	if style is StyleBoxTexture:
		style.texture=_texture(style.texture)
	elif style is StyleBoxFlat:
		for key in ["bg_color","border_color"]:
			var day=style.get(key)
			var dark=_night_color(day)
			if day!=dark:
				bindings.append([weakref(style),key,day,dark])
				style.set(key,day.lerp(dark,amount))

func _node_added(node: Node):
	if node is Control:pending.append(weakref(node))

func _scan(node: Node):
	if node is Control:_register_control(node)
	for child in node.get_children():_scan(child)

func _register_control(control: Control):
	# Authored screens reference the day resource; inherit the live instance instead.
	if control!=root and control.theme!=null and control.theme.resource_path=="res://assets/ui_theme.tres":
		control.theme=null
	if control is TextureRect and control.texture!=null:
		var path=control.texture.resource_path
		if path.begins_with("res://assets/icons/") and not path.get_file().get_basename() in CatanIcons.RESOURCES:
			control.material=symbol_material
	for property in control.get_property_list():
		var key: String=property.name
		if key.begins_with("theme_override_colors/") and not "outline" in key:
			var day=control.get(key)
			if not day is Color:continue
			var dark=_night_color(day)
			if day!=dark:
				bindings.append([weakref(control),key,day,dark])
				control.set(key,day.lerp(dark,_text_amount()))
		elif key.begins_with("theme_override_styles/"):
			var style=control.get(key)
			if style is StyleBox:_register_style(style)

func advance(daylight: float,delta: float):
	# Also soften abrupt clock corrections from a network snapshot or a new game.
	var next=lerpf(amount,1.0-clampf(daylight,0.0,1.0),1.0-exp(-delta*3.0))
	if absf(next-(1.0-daylight))<0.0001:next=1.0-daylight
	var added=pending
	pending=[]
	for ref in added:
		var control=ref.get_ref()
		if is_instance_valid(control) and root.is_ancestor_of(control):_register_control(control)
	if is_equal_approx(next,amount):return
	amount=next
	for type in OUTLINED_TYPES:
		palette_theme.set_color("font_outline_color",type,Color(0.04,0.06,0.09,4.0*amount*(1.0-amount)))
	for material in materials:material.set_shader_parameter("night",amount)
	atlas.render_target_update_mode=SubViewport.UPDATE_ONCE
	bindings=bindings.filter(func(binding):return binding[0].get_ref()!=null)
	for binding in bindings:
		var object=binding[0].get_ref()
		var text_color=binding.size()==5 or str(binding[1]).begins_with("theme_override_colors/")
		var color=binding[2].lerp(binding[3],_text_amount() if text_color else amount)
		if binding.size()==5:object.set_color(binding[1],binding[4],color)
		else:object.set(binding[1],color)
	# Keep only live overrides after HUD rebuilds.
	for id in registered_styles.keys():
		if registered_styles[id].get_ref()==null:registered_styles.erase(id)
