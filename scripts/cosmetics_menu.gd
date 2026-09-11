extends Control
signal close_requested
var preferences: CatanSettings
var network: CatanNetwork
var catalog=CatanCosmetics.new()
var selected=0
var target=-1
var choices: OptionButton
var style_buttons=[]
var equip: Button
var status: Label
var viewport: SubViewport
var display_root: Node3D
var preview_camera: Camera3D
var preview_color=Color("ed815d")
var drag_area: SubViewportContainer
var turn=0.0
var updating=false
var color_picker: ColorPickerButton

func label(parent: Node,text: String,size: int,color: Color=Color("f4e8ce")) -> Label:
	var n=Label.new();n.text=tr(text);n.add_theme_font_size_override("font_size",size);n.add_theme_color_override("font_color",color);parent.add_child(n);return n
func button(parent: Node,text: String) -> Button:
	var n=Button.new();n.text=tr(text);n.custom_minimum_size.y=42;parent.add_child(n);return n

func setup(settings: CatanSettings,net: CatanNetwork):
	preferences=settings;network=net
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade=ColorRect.new();shade.color=Color(0,0,0,.70);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
	var panel=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left=20;panel.offset_top=20;panel.offset_right=-20;panel.offset_bottom=-20;add_child(panel)
	var margin=MarginContainer.new()
	for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,8)
	panel.add_child(margin)
	var layout=VBoxContainer.new();layout.add_theme_constant_override("separation",16);margin.add_child(layout)

	var heading=HBoxContainer.new();layout.add_child(heading)
	var title=label(heading,tr("Player appearance"),28);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	choices=OptionButton.new();choices.name="CosmeticPlayer";choices.custom_minimum_size=Vector2(180,40);heading.add_child(choices)
	choices.item_selected.connect(_target_changed)

	var content=HBoxContainer.new();content.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",24);layout.add_child(content)
	var preview_box=VBoxContainer.new();preview_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_child(preview_box)
	drag_area=SubViewportContainer.new();drag_area.name="PiecePreview";drag_area.stretch=true;drag_area.size_flags_vertical=Control.SIZE_EXPAND_FILL;drag_area.custom_minimum_size=Vector2(0,180);preview_box.add_child(drag_area)
	viewport=SubViewport.new();viewport.size=Vector2i(760,500);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE;drag_area.add_child(viewport)
	var env_node=WorldEnvironment.new();var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("102b36");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("b9d8df");env.ambient_light_energy=.35;env.tonemap_mode=Environment.TONE_MAPPER_ACES;env_node.environment=env;viewport.add_child(env_node)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-35,0);sun.light_color=Color("ffe7c2");sun.light_energy=1.15;sun.shadow_enabled=true;viewport.add_child(sun)
	var fill=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-30,140,0);fill.light_color=Color("84b9ce");fill.light_energy=.22;viewport.add_child(fill)
	preview_camera=Camera3D.new();preview_camera.position=Vector3(.82,1.02,2.55);preview_camera.projection=Camera3D.PROJECTION_ORTHOGONAL;preview_camera.keep_aspect=Camera3D.KEEP_WIDTH;preview_camera.size=2.25;viewport.add_child(preview_camera);preview_camera.look_at(Vector3(0,.22,0))
	display_root=Node3D.new();viewport.add_child(display_root)
	drag_area.gui_input.connect(_preview_input)
	label(preview_box,tr("Road · Settlement · City"),14,Color("dcb978")).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label(preview_box,tr("Drag the preview to turn the pieces"),14,Color("9ab4be")).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var styles=VBoxContainer.new();styles.custom_minimum_size.x=210;styles.add_theme_constant_override("separation",12);content.add_child(styles)
	for i in CatanCosmetics.SETS.size():
		var choose=button(styles,CatanCosmetics.SETS[i]);choose.name="Style"+str(i);choose.toggle_mode=true;choose.alignment=HORIZONTAL_ALIGNMENT_LEFT;choose.add_theme_font_size_override("font_size",21);choose.pressed.connect(func():select_style(i));style_buttons.append(choose)
		choose.tooltip_text=CatanCosmetics.SET_DESCRIPTIONS[i]
	label(styles,tr("Player color"),17)
	color_picker=ColorPickerButton.new();color_picker.name="PlayerColor";color_picker.edit_alpha=false;color_picker.custom_minimum_size.y=42;styles.add_child(color_picker)
	color_picker.color_changed.connect(func(value):preview_color=Color(value,1.0);select_style(selected))
	button(styles,tr("Use seat color")).pressed.connect(func():preview_color=CatanBoard.PLAYERS[maxi(0,target)];color_picker.color=preview_color;select_style(selected))
	var bottom=HBoxContainer.new();bottom.add_theme_constant_override("separation",16);layout.add_child(bottom)
	status=label(bottom,"",16,Color("dcb978"));status.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	equip=button(bottom,tr("Apply appearance"));equip.name="EquipSet";equip.custom_minimum_size.x=130;equip.pressed.connect(_equip)
	var close=button(bottom,"Done");close.name="CloseCosmetics";close.custom_minimum_size.x=100;close.pressed.connect(func():close_requested.emit())
	network.changed.connect(refresh_roster)
	refresh_roster()
	select_style(_equipped())

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
	var found=-1
	for i in choices.item_count:
		if choices.get_item_metadata(i)==target:found=i;break
	if found<0:found=0
	choices.select(found);target=choices.get_item_metadata(found)
	preview_color=network.player_color(target)
	color_picker.color=preview_color
	updating=false
	if is_instance_valid(equip):select_style(selected)

func _target_changed(index: int):
	if updating:return
	target=choices.get_item_metadata(index);preview_color=network.player_color(target)
	color_picker.color=preview_color
	select_style(_equipped())

func _equipped() -> int:
	if target>=0 and target<network.roster.size():return int(network.roster[target].get("piece_style",0))
	return preferences.values.piece_style

func select_style(index: int):
	selected=index
	color_picker.color=preview_color
	for i in style_buttons.size():style_buttons[i].set_pressed_no_signal(i==selected)
	for child in display_root.get_children():child.free()
	for i in 3:
		var pedestal=Node3D.new();pedestal.position.x=(i-1)*.67;pedestal.rotation.y=turn;display_root.add_child(pedestal)
		catalog.round_part(pedestal,Vector3(0,-.065,0),.285,.08,Color("29434b"),-1,64)
		var piece=catalog.road(selected,preview_color) if i==0 else catalog.settlement(selected,preview_color,i==2)
		piece.name="Preview"+["Road","Settlement","City"][i]
		if i==0:piece.rotation.y=PI*.28;piece.scale=Vector3.ONE*.75
		pedestal.add_child(piece)
	_status()

func _status():
	var equipped=_equipped()==selected and preview_color.is_equal_approx(network.player_color(target))
	equip.disabled=equipped
	equip.text=tr("Equipped") if equipped else tr("Apply appearance")
	status.text=tr(CatanCosmetics.SETS[selected])+(tr(" · Equipped") if equipped else tr(" · Preview"))

func _equip():
	if target==network.seat or target<0:
		preferences.set_value("piece_style",selected)
		network.my_style=selected
	var chosen=preview_color.to_html(false)
	if target==network.seat or target<0:preferences.set_value("player_color",chosen)
	# Broadcasting style refreshes the preview, so retain the chosen color first.
	network.choose_piece_style(selected,target)
	network.choose_color(chosen,target)
	_status()

func _preview_input(event: InputEvent):
	if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
		turn+=event.relative.x*.009
		for pedestal in display_root.get_children():pedestal.rotation.y=turn

func _exit_tree():
	if is_instance_valid(network) and network.changed.is_connected(refresh_roster):network.changed.disconnect(refresh_roster)
