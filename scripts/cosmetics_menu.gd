extends Control
## The workshop: every edit rebuilds the preview from the same generator the
## board uses, so what you see here is exactly what lands on the island.
## Edits you close without applying wait in a draft until you come back.

signal close_requested
var preferences: CatanSettings
var network: CatanNetwork
const ROW=preload("res://scenes/ui/appearance_row.tscn")
const SWATCH=preload("res://scenes/ui/color_swatch.tscn")
const DICE=preload("res://assets/icons/dice.svg")
const COLOR_SWATCHES=[
	["Coral","ed815d"],["Red","c94c4c"],["Orange","df903d"],["Gold","d9b76c"],["Yellow","ebd85b"],
	["Lime","a7cf54"],["Green","7dcc83"],["Forest","39825b"],["Teal","329c91"],["Cyan","65bfcb"],
	["Sky","6ca9df"],["Blue","426ec4"],["Indigo","5956a8"],["Purple","9062bd"],["Lavender","b697d7"],
	["Pink","df89b3"],["Sand","d1aa87"],["Brown","946549"],["Ivory","e9e4d4"],["Slate","536578"]]
# Camera framing per preview: focus height, orthographic size.
const FRAMING={"settlement":[.07,.95],"city":[.1,1.15],"road":[.02,1.7]}
const REBUILD_DELAY=.06
const CARD=Vector2(1180,800)
const THUMBNAIL=Vector2i(176,124)
const HISTORY_LIMIT=60
# Slider drags merge into one undo step when edits come this close together.
const MERGE_SECONDS=.8

## Unapplied edits per seat, kept while the game runs.
static var drafts={}

var values: Dictionary=CatanAppearance.defaults()
var target=-1
var piece="settlement"
var section="homes"
var rows={}
var headings=[]
var preset_buttons=[]
var thumbnails=[]
var thumbnail_color=Color.TRANSPARENT
var section_buttons={}
var color_buttons=[]
var preview_color=Color("ed815d")
var history=[]
var last_edit={"key":"","time":0.0}
var yaw=-.35
var zoom=1.0
var rebuild_clock=-1.0
var updating=false
var night=false
var night_glow: StandardMaterial3D
var rng=RandomNumberGenerator.new()
@onready var choices: OptionButton=%CosmeticPlayer
@onready var display_root: Node3D=%Display
@onready var camera: Camera3D=%PreviewCamera

func _ready():
	rng.randomize()
	for i in CatanAppearance.PRESETS.size():
		var entry: Dictionary=CatanAppearance.PRESETS[i]
		var button=_card(entry.name+"Preset",entry.name,entry.description)
		button.toggle_mode=true
		button.expand_icon=true
		button.pressed.connect(func():use_preset(i))
		preset_buttons.append(button)
	var surprise=_card("Surprise","Surprise me","Roll a random, matching look")
	surprise.icon=DICE
	for state in ["normal","hover","pressed","hover_pressed","focus"]:
		surprise.remove_theme_color_override("icon_%s_color"%state)
	surprise.add_theme_constant_override("icon_max_width",40)
	surprise.pressed.connect(_on_surprise_pressed)
	for group in CatanAppearance.GROUPS:
		var button=Button.new()
		button.name=group[1]+"Section"
		button.text=group[1]
		button.toggle_mode=true
		button.custom_minimum_size=Vector2(0,34)
		button.pressed.connect(func():select_section(group[0]))
		%Sections.add_child(button)
		section_buttons[group[0]]=button
	for entry in _display_order():
		if entry.has("heading"):
			var heading=Label.new()
			heading.name=entry.heading.to_pascal_case()+"Heading"
			heading.text=entry.heading
			heading.uppercase=true
			heading.theme_type_variation=&"SectionLabel"
			heading.set_meta("group",entry.group)
			%Fields.add_child(heading)
			headings.append(heading)
		var row=ROW.instantiate()
		%Fields.add_child(row)
		row.show_field(entry)
		row.changed.connect(_field_changed)
		rows[entry.key]=row
	for i in COLOR_SWATCHES.size():
		var swatch=SWATCH.instantiate()
		swatch.name="Color"+str(i)
		%PlayerColors.add_child(swatch)
		var color=Color(COLOR_SWATCHES[i][1])
		swatch.show_color(color,COLOR_SWATCHES[i][0])
		swatch.pressed.connect(func():_remember();preview_color=color;_changed())
		color_buttons.append(swatch)
	night_glow=StandardMaterial3D.new()
	night_glow.albedo_color=Color("ffd092")
	night_glow.emission_enabled=true
	night_glow.emission=Color("ffb55d")
	night_glow.emission_energy_multiplier=2.6
	resized.connect(_layout)
	_layout()
	select_section("homes")

## A tall card with a picture on top, for presets and Surprise me.
func _card(node_name: String,text: String,tip: String) -> Button:
	var button=Button.new()
	button.name=node_name
	button.text=text
	button.tooltip_text=tip
	button.custom_minimum_size=Vector2(0,120)
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP
	button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
	button.clip_text=true
	# The theme tints icons brown to match text; pictures keep their own colors.
	for state in ["normal","hover","pressed","hover_pressed","focus"]:
		button.add_theme_color_override("icon_%s_color"%state,Color.WHITE)
	%Presets.add_child(button)
	return button

## Fields grouped for the editor: a field added in a later version sits beside
## the one it names in "after" rather than at the end.
func _display_order() -> Array:
	var order=[]
	for entry in CatanAppearance.FIELDS:
		if not entry.has("after"):order.append(entry)
	for entry in CatanAppearance.FIELDS:
		if not entry.has("after"):continue
		var at=order.size()
		for i in order.size():
			if order[i].key==entry.after:at=i+1
		order.insert(at,entry)
	return order

func _layout():
	var side=maxi(20,int((size.x-CARD.x)/2))
	var top=maxi(20,int((size.y-CARD.y)/2))
	for edge in ["left","right"]:%Margin.add_theme_constant_override("margin_"+edge,side)
	for edge in ["top","bottom"]:%Margin.add_theme_constant_override("margin_"+edge,top)

## Draws each preset once into its card, in the color being previewed.
func _render_thumbnails():
	if preview_color.is_equal_approx(thumbnail_color):return
	thumbnail_color=preview_color
	for i in preset_buttons.size():
		if thumbnails.size()<=i:
			var viewport=SubViewport.new()
			viewport.name="Thumbnail%d"%i
			viewport.own_world_3d=true
			viewport.size=THUMBNAIL
			viewport.msaa_3d=Viewport.MSAA_4X
			var world=WorldEnvironment.new()
			# Its own copy, so the night preview never darkens the cards.
			world.environment=%WorldEnvironment.environment.duplicate()
			viewport.add_child(world)
			viewport.add_child(%Sun.duplicate())
			viewport.add_child(%Fill.duplicate())
			var ground=%Ground.duplicate()
			viewport.add_child(ground)
			var eye=Camera3D.new()
			eye.projection=Camera3D.PROJECTION_ORTHOGONAL
			eye.keep_aspect=Camera3D.KEEP_WIDTH
			eye.size=.72
			eye.far=20
			viewport.add_child(eye)
			add_child(viewport)
			var focus=Vector3(0,.06,0)
			eye.look_at_from_position(focus+Basis(Vector3.UP,-.35)*Vector3(0,.9,1.25),focus)
			preset_buttons[i].icon=viewport.get_texture()
			thumbnails.append(viewport)
		var viewport: SubViewport=thumbnails[i]
		var old=viewport.get_node_or_null("Town")
		if old:old.free()
		var town=CatanPieceBuilder.town(CatanAppearance.encode(CatanAppearance.preset(i)),preview_color,false,0,true)
		town.name="Town"
		viewport.add_child(town)
		viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

func setup(settings: CatanSettings,net: CatanNetwork):
	preferences=settings;network=net
	network.changed.connect(refresh_roster)
	refresh_roster()
	_load()

func refresh_roster():
	updating=true
	choices.clear()
	choices.add_item(tr("Your pieces"))
	choices.set_item_metadata(0,network.seat)
	if network.is_controller():
		for i in network.roster.size():
			if network.roster[i].get("bot",false):
				choices.add_item(network.roster[i].name+tr(" · Bot"))
				choices.set_item_metadata(choices.item_count-1,i)
	var found=0
	for i in choices.item_count:
		if choices.get_item_metadata(i)==target:found=i;break
	choices.select(found)
	target=choices.get_item_metadata(found)
	choices.visible=choices.item_count>1
	updating=false
	_status()

func _target_changed(index: int):
	if updating:return
	_keep_draft()
	target=choices.get_item_metadata(index)
	history.clear()
	_load()

func _equipped() -> PackedByteArray:
	if target>=0 and target<network.roster.size():return network.player_look(target)
	return preferences.look()

## Opens this seat's unapplied draft if there is one, else the pieces in use.
func _load():
	var draft: Dictionary=drafts.get(target,{})
	if draft.is_empty():
		values=CatanAppearance.decode(_equipped())
		preview_color=network.player_color(target)
	else:
		values=draft.values.duplicate()
		preview_color=draft.color
	_changed()

## Discards edits and shows the pieces this seat currently uses. Undo brings the edits back.
func revert(from_button: bool=false):
	if from_button:_remember()
	drafts.erase(target)
	values=CatanAppearance.decode(_equipped())
	preview_color=network.player_color(target)
	_changed()

func _keep_draft():
	if not is_instance_valid(network):return
	if _is_equipped():drafts.erase(target)
	else:drafts[target]={"values":values.duplicate(),"color":preview_color}

## Saves the current look so Undo can return to it. Edits to the same field in
## quick succession, like a slider drag, share one step.
func _remember(key: String=""):
	var now=Time.get_ticks_msec()/1000.0
	if not key.is_empty() and key==last_edit.key and now-last_edit.time<MERGE_SECONDS:
		last_edit.time=now
		return
	last_edit={"key":key,"time":now}
	history.append({"values":values.duplicate(),"color":preview_color})
	if history.size()>HISTORY_LIMIT:history.pop_front()

func undo():
	if history.is_empty():return
	var step: Dictionary=history.pop_back()
	values=step.values
	preview_color=step.color
	last_edit={"key":"","time":0.0}
	_changed()

func _unhandled_key_input(event: InputEvent):
	if event.is_action_pressed("ui_undo"):
		undo()
		get_viewport().set_input_as_handled()

func use_preset(index: int):
	_remember()
	var variation=values.seed
	values=CatanAppearance.preset(index)
	values.seed=variation
	_changed()

func _on_surprise_pressed():
	_remember()
	values=CatanAppearance.random(rng)
	values.seed=rng.randi_range(0,255)
	_changed()

## Rolls new values for the open section and leaves the others alone.
func shuffle_section():
	_remember()
	var rolled=CatanAppearance.random(rng)
	rolled.seed=rng.randi_range(0,255)
	for entry in CatanAppearance.FIELDS:
		if entry.group==section:values[entry.key]=rolled[entry.key]
	_changed()

func _field_changed(key: String,value: Variant):
	_remember(key)
	values[key]=value
	rows[key].show_value(value)
	_changed(false)

func select_section(group: String):
	section=group
	for key in section_buttons:section_buttons[key].set_pressed_no_signal(key==group)
	for key in rows:rows[key].visible=CatanAppearance.field(key).group==group
	for heading in headings:heading.visible=heading.get_meta("group")==group
	%PlayerColorBox.visible=group=="colors"
	%ShuffleSection.tooltip_text=tr("Roll new choices for %s only")%tr(section_buttons[group].text)
	%FieldScroll.scroll_vertical=0
	if group=="city":show_piece("city")
	elif group=="roads":show_piece("road")
	# Town dressing only shows on settlements; cities trade it for walls.
	elif group=="town" or (group=="homes" and piece=="road"):show_piece("settlement")

func show_piece(kind: String):
	piece=kind
	%ShowSettlement.set_pressed_no_signal(kind=="settlement")
	%ShowCity.set_pressed_no_signal(kind=="city")
	%ShowRoad.set_pressed_no_signal(kind=="road")
	_rebuild()

## Refreshes controls and queues a preview rebuild after any edit.
func _changed(refresh_controls: bool=true):
	if refresh_controls:
		for key in rows:rows[key].show_value(values[key])
	var chosen=CatanAppearance.preset_of(CatanAppearance.encode(values))
	for i in preset_buttons.size():preset_buttons[i].set_pressed_no_signal(i==chosen)
	var color_label=tr("Custom")
	for i in color_buttons.size():
		var active=preview_color.is_equal_approx(Color(COLOR_SWATCHES[i][1]))
		color_buttons[i].set_pressed_no_signal(active)
		color_buttons[i].text="✓" if active else ""
		if active:color_label=tr(COLOR_SWATCHES[i][0])
	%SelectedColor.text=tr("Player color: %s. Banners, the town rim and road edges use it.")%color_label
	rebuild_clock=REBUILD_DELAY
	_render_thumbnails()
	_status()

func _process(delta: float):
	if rebuild_clock<0:return
	rebuild_clock-=delta
	if rebuild_clock<0:_rebuild()

func _rebuild():
	rebuild_clock=-1.0
	for child in display_root.get_children():child.free()
	var bytes=CatanAppearance.encode(values)
	match piece:
		"road":
			for i in 3:
				var builder=CatanPieceBuilder.new(bytes,preview_color,true)
				builder.build_road()
				var road=CatanPieceBuilder.instance(builder.parts(),"PreviewRoad%d"%i)
				var angle=deg_to_rad(90+120*i)
				road.position=Vector3(cos(angle),0,sin(angle))*.4
				road.rotation.y=atan2(cos(angle),sin(angle))
				display_root.add_child(road)
			var joint=CatanPieceBuilder.new(bytes,preview_color,true)
			joint.build_joint()
			display_root.add_child(CatanPieceBuilder.instance(joint.parts(),"PreviewJoint"))
		_:
			var builder=CatanPieceBuilder.new(bytes,preview_color,true)
			builder.build_town(piece=="city",0)
			display_root.add_child(CatanPieceBuilder.instance(builder.parts(),"PreviewCity" if piece=="city" else "PreviewSettlement"))
	_frame()
	_apply_night()

func _frame():
	var framing: Array=FRAMING[piece]
	var focus=Vector3(0,framing[0],0)
	var offset=Basis(Vector3.UP,yaw)*Vector3(0,.9,1.25)
	camera.look_at_from_position(focus+offset,focus)
	camera.size=framing[1]/zoom

func _on_night_toggled(on: bool):
	night=on
	_apply_night()

func _apply_night():
	var environment: Environment=%WorldEnvironment.environment
	environment.background_color=Color("07121a") if night else Color("102b36")
	environment.ambient_light_energy=.12 if night else .45
	%Sun.light_energy=.08 if night else 1.2
	%Fill.light_energy=.18 if night else .25
	for windows in display_root.find_children("NightWindows","MeshInstance3D",true,false):
		windows.material_override=night_glow if night else null
	for lamp in display_root.find_children("NightLight*","OmniLight3D",true,false):
		# The board is 25 times larger, so its lamp energy would blind the preview.
		lamp.light_energy=.012 if night else 0.0
		lamp.omni_range=.16
		lamp.omni_attenuation=1.5
		lamp.light_color=Color("ffb765")

func _preview_input(event: InputEvent):
	if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
		yaw-=event.relative.x*.008
		_frame()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		zoom=clampf(zoom*(1.1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1/1.1),.8,3.0)
		_frame()
	elif event is InputEventMagnifyGesture:
		zoom=clampf(zoom*event.factor,.8,3.0)
		_frame()

func _on_use_seat_color_pressed():
	_remember()
	preview_color=CatanBoard.PLAYERS[maxi(0,target)]
	_changed()

func _is_equipped() -> bool:
	return CatanAppearance.encode(values)==_equipped() and preview_color.is_equal_approx(network.player_color(target))

func _status():
	if not is_instance_valid(network):return
	var equipped=_is_equipped()
	%ApplyLook.disabled=equipped
	%ApplyLook.text=tr("Applied") if equipped else tr("Apply")
	%Revert.disabled=equipped
	%Undo.disabled=history.is_empty()
	var chosen=CatanAppearance.preset_of(CatanAppearance.encode(values))
	var title=tr(CatanAppearance.PRESETS[chosen].name) if chosen>=0 else tr("Custom pieces")
	%Status.text=title+(tr(" · In use") if equipped else tr(" · Not applied yet"))

func apply():
	var bytes=CatanAppearance.encode(values)
	var chosen=preview_color.to_html(false)
	if target==network.seat or target<0:
		preferences.set_value("appearance",bytes.hex_encode())
		preferences.set_value("player_color",chosen)
		network.my_look=bytes
	network.choose_look(bytes,target)
	network.choose_color(chosen,target)
	drafts.erase(target)
	_status()

func _exit_tree():
	_keep_draft()
	if is_instance_valid(network) and network.changed.is_connected(refresh_roster):network.changed.disconnect(refresh_roster)
