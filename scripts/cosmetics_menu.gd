extends Control
signal close_requested
var preferences: CatanSettings
var network: CatanNetwork
var catalog=CatanCosmetics.new()
var selected=0
var target=-1
var style_buttons=[]
var preview_color=Color("ed815d")
var turn=0.0
var updating=false
const COLOR_SWATCHES=[
	["Coral","ed815d"],["Red","c94c4c"],["Orange","df903d"],["Gold","d9b76c"],["Yellow","ebd85b"],
	["Lime","a7cf54"],["Green","7dcc83"],["Forest","39825b"],["Teal","329c91"],["Cyan","65bfcb"],
	["Sky","6ca9df"],["Blue","426ec4"],["Indigo","5956a8"],["Purple","9062bd"],["Lavender","b697d7"],
	["Pink","df89b3"],["Sand","d1aa87"],["Brown","946549"],["Ivory","e9e4d4"],["Slate","536578"]]
var color_buttons=[]
const SWATCH=preload("res://scenes/ui/color_swatch.tscn")
@onready var choices: OptionButton=%CosmeticPlayer
@onready var equip: Button=%EquipSet
@onready var status: Label=%Status
@onready var display_root: Node3D=%Display
@onready var color_name: Label=%SelectedColor

func _ready():
	var template: Button=%StyleList.get_node("StyleTemplate")
	for i in CatanCosmetics.SETS.size():
		var choose: Button=template.duplicate()
		choose.name="Style"+str(i)
		choose.text=tr(CatanCosmetics.SETS[i])
		choose.tooltip_text=tr(CatanCosmetics.SET_DESCRIPTIONS[i])
		choose.show()
		choose.pressed.connect(func():select_style(i))
		%StyleList.add_child(choose)
		style_buttons.append(choose)
	for i in COLOR_SWATCHES.size():
		var swatch=SWATCH.instantiate()
		swatch.name="Color"+str(i)
		%PlayerColors.add_child(swatch)
		var color=Color(COLOR_SWATCHES[i][1])
		swatch.show_color(color,COLOR_SWATCHES[i][0])
		swatch.pressed.connect(func():preview_color=color;select_style(selected))
		color_buttons.append(swatch)

func setup(settings: CatanSettings,net: CatanNetwork):
	preferences=settings;network=net
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
	updating=false
	if is_instance_valid(equip):select_style(selected)

func _target_changed(index: int):
	if updating:return
	target=choices.get_item_metadata(index);preview_color=network.player_color(target)
	select_style(_equipped())

func _equipped() -> int:
	if target>=0 and target<network.roster.size():return int(network.roster[target].get("piece_style",0))
	return preferences.values.piece_style

func select_style(index: int):
	selected=index
	color_name.text=tr("Custom")
	for i in color_buttons.size():
		var active=preview_color.is_equal_approx(Color(COLOR_SWATCHES[i][1]))
		color_buttons[i].set_pressed_no_signal(active)
		color_buttons[i].text="✓" if active else ""
		if active:color_name.text=tr(COLOR_SWATCHES[i][0])
	color_name.text=tr("Player color: %s")%color_name.text
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

func _on_use_seat_color_pressed():
	preview_color=CatanBoard.PLAYERS[maxi(0,target)]
	select_style(selected)

func _exit_tree():
	if is_instance_valid(network) and network.changed.is_connected(refresh_roster):network.changed.disconnect(refresh_roster)
