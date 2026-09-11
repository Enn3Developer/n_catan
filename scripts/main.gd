extends Node3D

const INK=Color("102938")
const MUTED=Color("9ab4be")
const CREAM=Color("f4e8ce")
const GOLD=Color("dcb978")
var net: CatanNetwork
var board: CatanBoard
var ui: Control
var screen: Control
var toast: Label
var modal: Control
var state={}
var mode=""
var name_field: LineEdit
var address_field: LineEdit
var password_field: LineEdit
var host_password_field: LineEdit
var selected_give: OptionButton
var selected_get: OptionButton
var amount_give: SpinBox
var amount_get: SpinBox
var server_only=false
var connection_status=""
var preferences=CatanSettings.new()
var audio: CatanAudio
var guide: CatanTutorial
var tutorial_panel: Control
var invite_address=""
var inspection_mode=false
var inspection_hint: Label
var layout_queued=false
var trade_players=false
var trade_give=0
var trade_get=1
var music_dialog_widgets={}
var music_ui_clock=0.0
var music_volume_before_mute=.42
var updater
var notifications
var notified_updates={}
var turn_banner: Label
var turn_banner_timer: Timer
var active_language=-1

func _ready():
	CatanI18n.apply(preferences.values.language)
	active_language=preferences.values.language
	net=$Network
	net.my_style=preferences.values.piece_style
	net.my_color=preferences.values.player_color
	net.changed.connect(_network_changed)
	net.received.connect(_received)
	net.notice.connect(_notice)
	if "--server" in OS.get_cmdline_user_args():
		server_only=true
		var password=""
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--password="): password=arg.trim_prefix("--password=")
		var err=net.host("Server",password,true)
		print("CATAN_SERVER_READY port=24567" if err==OK else "SERVER_FAILED %s" % err)
		if err==OK:
			var address="127.0.0.1:24567"
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--address="):address=arg.trim_prefix("--address=")
			print("CATAN_SECURE_INVITE "+net.secure_invite(address))
		return
	board=$Board
	board.picked.connect(func(kind,id): net.act({"type":kind,"id":id}))
	var preview=CatanRules.new()
	board.build(preview.create(["Voyager","Mariner"],8426))
	audio=$Audio
	net.applied.connect(_action_applied)
	var canvas=CanvasLayer.new()
	canvas.layer=2
	add_child(canvas)
	ui=Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.theme=_theme()
	canvas.add_child(ui)
	toast=Label.new()
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast.offset_left=-470
	toast.offset_right=470
	toast.offset_top=-62
	toast.offset_bottom=-20
	toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_color",GOLD)
	toast.add_theme_stylebox_override("normal",_style(Color("173443"),12))
	toast.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	toast.hide()
	ui.add_child(toast)
	notifications=preload("res://scripts/notifications.gd").new()
	notifications.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	ui.add_child(notifications)
	get_viewport().size_changed.connect(_queue_layout)
	inspection_hint=Label.new()
	inspection_hint.text=tr("Right-drag to orbit · Scroll to zoom · H / Esc to return")
	inspection_hint.add_theme_font_size_override("font_size",15)
	inspection_hint.add_theme_color_override("font_outline_color",INK)
	inspection_hint.add_theme_constant_override("outline_size",6)
	inspection_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	inspection_hint.offset_top=-40
	inspection_hint.offset_bottom=-12
	inspection_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	inspection_hint.hide()
	ui.add_child(inspection_hint)
	_apply_preferences()
	updater=preload("res://scripts/updater.gd").new()
	add_child(updater)
	updater.changed.connect(_updates_changed)
	_home()
	if updater.supported:updater.check_updates.call_deferred()
	_update_health_ready()

func _style(color: Color,radius: int=10) -> StyleBoxFlat:
	var s=StyleBoxFlat.new()
	s.bg_color=color
	s.corner_radius_top_left=radius
	s.corner_radius_top_right=radius
	s.corner_radius_bottom_left=radius
	s.corner_radius_bottom_right=radius
	s.content_margin_left=16
	s.content_margin_right=16
	s.content_margin_top=8
	s.content_margin_bottom=8
	return s

func _theme() -> Theme:
	return load("res://assets/ui_theme.tres")

func _clear(scene_path: String=""):
	if is_instance_valid(screen): screen.free()
	var keep_modal=is_instance_valid(modal) and (modal.name in ["Settings","Cosmetics","MusicLibrary","Updates"] or (scene_path=="res://scenes/ui/hud.tscn" and modal.name in ["Guide","GameLog","LeaveConfirm"]))
	if is_instance_valid(modal) and not keep_modal: modal.free()
	if scene_path.is_empty():
		screen=Control.new()
		screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		screen.mouse_filter=Control.MOUSE_FILTER_IGNORE
	else: screen=load(scene_path).instantiate()
	ui.add_child(screen)
	_apply_text(screen)
	ui.move_child(toast,ui.get_child_count()-1)
	if keep_modal: ui.move_child(modal,ui.get_child_count()-1)
	if is_instance_valid(notifications):ui.move_child(notifications,ui.get_child_count()-1)
	_queue_layout()

func _label(parent: Node,text: String,size: int=16,color: Color=CREAM,translate: bool=true) -> Label:
	var node=Label.new()
	node.auto_translate_mode=Node.AUTO_TRANSLATE_MODE_DISABLED if not translate else Node.AUTO_TRANSLATE_MODE_INHERIT
	node.text=CatanI18n.render(text) if translate else text
	node.set_meta("base_font_size",size)
	node.add_theme_font_size_override("font_size",maxi(size,16 if preferences.values.large_text else 14))
	node.add_theme_color_override("font_color",color)
	parent.add_child(node)
	return node

func _button(parent: Node,text: String,callback: Callable,primary: bool=false) -> Button:
	var button=Button.new()
	button.text=tr(text)
	button.custom_minimum_size.y=38
	button.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	if primary:
		button.add_theme_stylebox_override("normal",_style(GOLD))
		button.add_theme_stylebox_override("hover",_style(GOLD.lightened(0.12)))
		button.add_theme_color_override("font_color",INK)
		button.add_theme_color_override("font_hover_color",INK)
		button.add_theme_color_override("icon_normal_color",INK)
		button.add_theme_color_override("icon_hover_color",INK)
	button.pressed.connect(func():
		if is_instance_valid(audio): audio.play("click")
		callback.call(),CONNECT_DEFERRED)
	parent.add_child(button)
	return button


func _home():
	if is_instance_valid(turn_banner):turn_banner.hide()
	if is_instance_valid(notifications):
		notifications.dismiss("trade")
		notifications.dismiss("trade_result")
	inspection_mode=false
	if is_instance_valid(inspection_hint):inspection_hint.hide()
	board.show_labels=true
	board.reset_camera()
	_clear("res://scenes/ui/home.tscn")
	_node("Version").text=CatanBuildInfo.VERSION
	state={}
	guide=null
	if is_instance_valid(tutorial_panel): tutorial_panel.free()
	board.set_mode("",-1)
	board.camera.h_offset=-2.4
	board.show_labels=false
	board.camera.v_offset=0
	board.camera.fov=35
	name_field=_node("PlayerName")
	name_field.text=preferences.values.player_name
	address_field=_node("ServerAddress")
	password_field=_node("RoomPassword")
	host_password_field=_node("HostPassword")
	var online_group=ButtonGroup.new()
	_node("HostTab").button_group=online_group;_node("JoinTab").button_group=online_group
	_node("HostTab").pressed.connect(func():_online_mode(true))
	_node("JoinTab").pressed.connect(func():_online_mode(false))
	_bind("Singleplayer",_solo)
	_bind("ShowOnline",func():pass,true)
	_bind("Learn",_tutorial_start)
	_bind("HostOnline",_host)
	_bind("JoinOnline",_join)
	_bind("OpenSettings",_open_settings)
	_bind("ExitDesktop",_exit_desktop)
	_bind("CheckUpdates",_open_updates)
	_updates_changed()
	CatanIcons.button_icon(_node("OpenSettings"),"settings")
	_node("ShowOnline").toggled.connect(func(value):_node("OnlineForm").visible=value;_queue_layout())
	_node("MenuItems").minimum_size_changed.connect(_queue_layout)
	_bind("OpenCosmetics",_open_cosmetics)
	var music_button=_button(_node("MenuItems"),"Music",_open_music)
	music_button.name="OpenMusic";CatanIcons.button_icon(music_button,"music")
	_bind("Reconnect",func():
		net.reconnect_password=password_field.text
		net.reconnect())
	_node("Reconnect").visible=not net.reconnect_token.is_empty()
	if not net.reconnect_token.is_empty():
		address_field.text=net.reconnect_address
		password_field.text=net.reconnect_password
		_node("ShowOnline").button_pressed=true
		_online_mode(false)

func _online_mode(hosting: bool):
	_node("HostOptions").visible=hosting
	_node("JoinOptions").visible=not hosting
	_node("HostTab").set_pressed_no_signal(hosting)
	_node("JoinTab").set_pressed_no_signal(not hosting)
	_queue_layout()

func _host():
	var pname=name_field.text.strip_edges()
	if pname.is_empty(): pname="Voyager"
	preferences.set_value("player_name",pname)
	var err=net.host(pname,host_password_field.text)
	if err!=OK: _notice(tr("Could not host on UDP 24567. Another server may be running."))

func _join():
	var pname=name_field.text.strip_edges()
	if pname.is_empty(): pname="Voyager"
	preferences.set_value("player_name",pname)
	var address=address_field.text
	var password=password_field.text
	var err=net.join_room(address,pname,password)
	if err!=OK:
		_home()
		_notice(tr("Paste the complete secure invite from the host."))
	else: _notice(tr("Connecting to the island…"))

func _network_changed():
	if server_only or not is_instance_valid(ui): return
	if not net.online:
		_home()
	elif not net.started:
		_lobby()
	elif not state.is_empty():
		_hud()

func _lobby():
	_clear("res://scenes/ui/lobby.tscn")
	var music_button=_music_icon_button(_node("LobbySettings").get_parent(),"music","Music",_open_music)
	music_button.name="OpenMusic"
	board.camera.h_offset=0
	_node("LobbyTitle").text=tr("Solo game") if net.solo else tr("Online room")
	_node("PlayerCount").text="%d / 6" % net.roster.size()
	_node("RoomType").text="SOLO" if net.solo else "ONLINE"
	var controller=net.is_controller()
	var slots=_node("PlayerSlots")
	_node("RoomSummary").text=tr("30 hexes · Paired turns") if net.roster.size()>4 else tr("19 hexes · Classic")
	if not net.solo:_node("RoomSummary").text+="\n"+(tr("Password required to join") if not net.room_password.is_empty() else tr("Open room · no password"))
	for i in CatanNetwork.MAX_PLAYERS:
		var slot=load("res://scenes/ui/player_slot.tscn").instantiate()
		slots.add_child(slot)
		slot.add_theme_stylebox_override("panel",_style(Color("102a36"),12))
		var occupied=i<net.roster.size()
		var bot=occupied and net.roster[i].get("bot",false)
		slot.get_node("Row/Accent").color=net.player_color(i) if occupied else Color("38505a")
		slot.get_node("Row/Details/PlayerName").auto_translate_mode=Node.AUTO_TRANSLATE_MODE_DISABLED
		slot.get_node("Row/Details/PlayerName").text=net.roster[i].name if occupied else tr("Open seat")
		var info=""
		if occupied: info=tr("Bot") if bot else tr("You") if i==net.seat else tr("Player")
		if occupied:info+=" · "+tr(CatanCosmetics.SETS[clampi(int(net.roster[i].get("piece_style",0)),0,3)])
		slot.get_node("Row/Details/PlayerInfo").text=info
		var status=slot.get_node("Row/Controls/Status")
		status.text=tr("Ready") if occupied and net.roster[i].ready else tr("Waiting") if occupied else ""
		status.visible=occupied and not bot
		status.add_theme_font_size_override("font_size",13)
		status.add_theme_color_override("font_color",GOLD if occupied and net.roster[i].ready else MUTED)
		var difficulty=slot.get_node("Row/Controls/Difficulty")
		difficulty.visible=bot
		if bot:
			for level in CatanBot.LEVELS: difficulty.add_item(level)
			difficulty.select(net.roster[i].difficulty)
			difficulty.disabled=not controller
			difficulty.item_selected.connect(func(value):net.configure_bot("difficulty",i,value),CONNECT_DEFERRED)
		var remove=slot.get_node("Row/Controls/Remove")
		remove.visible=bot and controller
		remove.pressed.connect(func():net.configure_bot("remove",i),CONNECT_DEFERRED)
	_bind("AddBot",func():net.configure_bot("add"))
	_node("AddBot").disabled=not controller or net.roster.size()>=CatanNetwork.MAX_PLAYERS
	_bind("ReadyButton",net.ready_up)
	_node("ReadyButton").text=tr("Not ready") if net.seat>=0 and net.roster[net.seat].ready else tr("I'm ready")
	_node("ReadyButton").disabled=net.seat<0
	_bind("StartGame",net.start_game,true)
	var all_ready=net.roster.size()>=CatanNetwork.MIN_PLAYERS and net.roster.size()<=CatanNetwork.MAX_PLAYERS
	for row in net.roster:
		if not row.ready: all_ready=false
	_node("StartGame").disabled=not controller or not all_ready
	_node("LobbyStatus").text=tr("Ready to play") if all_ready else tr("Add %d more player(s)") % (CatanNetwork.MIN_PLAYERS-net.roster.size()) if net.roster.size()<CatanNetwork.MIN_PLAYERS else tr("Waiting for players")
	_bind("LeaveRoom",net.leave)
	_bind("LobbySettings",_open_settings)
	CatanIcons.button_icon(_node("LobbySettings"),"settings")
	_bind("LobbyCosmetics",_open_cosmetics)
	_bind("MapRouter",net.map_router)
	_bind("CopyInvite",func():
		var address=_node("InviteAddress").text.strip_edges()
		if address.is_empty(): _notice(tr("Enter your public address first, or use Map router."))
		else: DisplayServer.clipboard_set(net.secure_invite(address)); _notice(tr("Secure invite copied. Share it with your guests.")))
	_node("InviteAddress").text=invite_address if net.multiplayer.is_server() else net.reconnect_address
	_node("InviteAddress").editable=net.multiplayer.is_server()
	_node("InviteAddress").text_changed.connect(func(text):invite_address=text)
	for node_name in ["InviteHeading","InviteAddress","InviteActions"]: _node(node_name).visible=not net.solo
	_node("MapRouter").disabled=not net.multiplayer.is_server()
	_node("ConnectionHelp").text=tr("Choose each bot’s difficulty.") if net.solo else tr("Share the secure invite. Host: open UDP 24567.")
	if not connection_status.is_empty() and not net.solo: _node("ConnectionHelp").text=CatanI18n.render(connection_status)
func _received(data: Dictionary):
	if server_only: return
	var previous_trade=state.get("trade_event",{})
	var previous_offer=state.get("offer",{})
	var trading=is_instance_valid(modal) and modal.name=="TradeDialog"
	var fresh=state.is_empty()
	var new_turn=fresh or state.get("turn",-1)!=data.turn or state.get("setup",-1)!=data.get("setup",-1) or state.get("paired",false)!=data.get("paired",false)
	var produced=not fresh and data.rolled and (not state.rolled or state.dice!=data.dice)
	if is_instance_valid(audio): audio.transition(state,data,net.seat)
	state=data
	board.camera.h_offset=0
	board.camera.v_offset=1.8 if guide!=null else 0.0
	if guide!=null: board.camera.fov=42
	board.show_labels=not inspection_mode
	if fresh: board.build(state)
	else: board.refresh(state)
	board.day_seconds=state.get("world_seconds",board.day_seconds)
	board.advance_day(0)
	if produced: board.throw_dice(state.dice)
	mode=""
	if state.turn==net.seat:
		if state.phase=="setup_settlement": mode="settlement"
		if state.phase in ["setup_road","free_roads"]: mode="road"
		if state.phase=="robber": mode="robber"
	if guide!=null and guide.completed: mode=""
	board.set_mode("" if inspection_mode else mode,-1 if inspection_mode else net.seat)
	_hud()
	_trade_notifications(previous_trade,previous_offer,fresh)
	if new_turn and state.turn==net.seat and state.winner==-1:_show_turn_banner()
	elif state.turn!=net.seat or state.winner!=-1:
		if is_instance_valid(turn_banner):turn_banner.hide()
	if trading and state.phase=="play" and state.turn==net.seat and state.winner==-1:
		if not state.offer.is_empty() and state.offer.from==net.seat:_view_offer()
		else:_trade(false)

func _process(delta):
	if not server_only and is_instance_valid(audio):
		var soundtrack=net.music_state()
		audio.follow_soundtrack(soundtrack,delta)
		music_ui_clock-=delta
		if music_ui_clock<=0:
			music_ui_clock=.15
			_refresh_music_widgets(music_dialog_widgets,soundtrack)
	if not server_only and is_instance_valid(board) and net.started and not net.paused and net.roster.all(func(player):return player.connected):
		board.advance_day(delta)

func _hud():
	_clear("res://scenes/ui/hud.tscn")
	screen.visible=not inspection_mode
	var row=HBoxContainer.new()
	_node("TopBody").add_child(row)
	_label(row,"CATAN",23,GOLD)
	var turn=state.players[state.turn]
	var turn_label=_label(row,turn.name+" · "+(tr("Your turn") if state.turn==net.seat else tr("Playing")),16,board.player_color(state.turn))
	turn_label.name="TurnLabel"
	turn_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	turn_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	var phase=_label(row,tr("Paired turn") if state.get("paired",false) else _phase_text(),14,MUTED)
	phase.name="PhaseLabel"
	for action in [["inspect",tr("Inspect board (H)"),_toggle_inspection],["journal",tr("Game log"),_journal],["help","Guide",_help],["music","Music",_open_music],["settings","Settings",_open_settings],["leave",tr("Leave game"),_confirm_leave]]:
		var button=_button(row,"",action[2])
		button.custom_minimum_size=Vector2(44,40)
		if action[0]=="music":button.name="OpenMusic"
		button.tooltip_text=tr(action[1])
		CatanIcons.button_icon(button,action[0],20)
	var players=_node("PlayersBody")
	for i in state.players.size():
		var player=state.players[i]
		var scoring=CatanRules.new();scoring.s=state
		var score=scoring.visible_points(i)
		var chip=PanelContainer.new()
		chip.name="PlayerChip%d" % i
		var style=_style(Color("112630"),8)
		style.content_margin_left=10;style.content_margin_right=10
		style.set_border_width_all(1)
		style.border_color=net.player_color(i) if i==state.turn else Color("30434a")
		chip.add_theme_stylebox_override("panel",style)
		chip.tooltip_text=tr("%s%s\n%d points · %d resources · %d development cards\nRoad length %d · %d knights%s%s") % [player.name,tr(" (you)") if i==net.seat else "",score,player.resource_count,player.card_count,player.road_length,player.knights,tr("\nLongest road +2") if state.longest==i else "",tr("\nLargest army +2") if state.army==i else ""]
		players.add_child(chip)
		var column=VBoxContainer.new();chip.add_child(column)
		var line=HBoxContainer.new();line.add_theme_constant_override("separation",5);column.add_child(line)
		var name_label=_label(line,player.name,14,net.player_color(i),false)
		name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var hidden_points=player.cards[4]+player.new_cards[4] if player.cards.size()==5 else 0
		chip.tooltip_text+=tr("\n%d public points + %d victory-point cards = %d total") % [player.points,hidden_points,score] if player.cards.size()==5 else tr("\nVictory-point cards stay private until game end.")
		var stats=HFlowContainer.new();stats.add_theme_constant_override("h_separation",6);column.add_child(stats)
		for stat in [["star",score,tr("Victory points")],["hand",player.resource_count,"Resources"],["cards",player.card_count,tr("Development cards")],["road",player.road_length,tr("Longest road length")],["knight",player.knights,tr("Played knights")]]:
			var badge=HBoxContainer.new();badge.tooltip_text=tr(stat[2])+": "+str(stat[1]);stats.add_child(badge)
			if stat[0]=="star":badge.tooltip_text=chip.tooltip_text
			CatanIcons.icon(badge,stat[0],16)
			_label(badge,str(stat[1]),14).mouse_filter=Control.MOUSE_FILTER_IGNORE
	var right=_node("ActionsBody")
	var instruction=_node("Instruction")
	instruction.text=_instruction()
	instruction.tooltip_text=tr("Paired turns allow building, cards and bank trading.") if state.get("paired",false) else ""
	var mine=state.turn==net.seat and state.winner==-1
	var play=mine and state.phase=="play"
	var roll=_button(right,tr("Roll") if state.dice[0]==0 else "%d + %d" % state.dice,func():net.act({"type":"roll"}),true)
	roll.name="RollDice"
	roll.tooltip_text=tr("Roll dice") if state.dice[0]==0 else tr("Last roll: %d") % (state.dice[0]+state.dice[1])
	roll.disabled=not play or state.rolled
	CatanIcons.button_icon(roll,"dice")
	var rules=CatanRules.new();rules.s=state
	for kind in ["road","settlement","city"]:
		var action=VBoxContainer.new()
		action.add_theme_constant_override("separation",2)
		right.add_child(action)
		var button=_button(action,kind.capitalize(),func():_choose(kind))
		button.name=kind.capitalize()+"Action"
		button.toggle_mode=true;button.button_pressed=mode==kind
		button.tooltip_text=tr(kind.capitalize())+": "+_resource_text(CatanRules.COST[kind])
		CatanIcons.button_icon(button,kind,20)
		var sites=rules.build_sites(net.seat,kind)
		button.disabled=not play or not state.rolled or not rules.can_pay(net.seat,CatanRules.COST[kind]) or sites.is_empty()
		if rules.pieces(net.seat,kind)>={"road":15,"settlement":5,"city":4}[kind]:
			button.tooltip_text+="\n"+tr({"road":"All 15 of your roads are on the board. You have none left to place.","settlement":"All 5 of your settlements are on the board. Upgrade one to a city to free a settlement piece.","city":"All 4 of your cities are on the board. You have none left to place."}[kind])
		elif not rules.can_pay(net.seat,CatanRules.COST[kind]):
			button.tooltip_text+="\n"+CatanI18n.render(rules.cost_error(net.seat,kind))
		elif sites.is_empty():button.tooltip_text+="\n"+tr("No legal space to build a %s.") % tr(kind)
		var cost=CatanIcons.resources(action,CatanRules.COST[kind],18)
		cost.alignment=BoxContainer.ALIGNMENT_CENTER
	var trade=_button(right,"Trade",_trade);trade.name="TradeAction";CatanIcons.button_icon(trade,"trade")
	trade.disabled=not play or not state.rolled
	_card_section(play)
	var end=_button(right,tr("End"),func():net.act({"type":"end"}),true)
	end.name="EndTurn";CatanIcons.button_icon(end,"arrow");end.disabled=not play or not state.rolled
	if state.phase=="free_roads" and mine:_button(right,tr("Finish roads"),func():net.act({"type":"finish_roads"}))
	if state.phase=="discard" and state.discards.has(str(net.seat)):_button(right,tr("Discard %d") % state.discards[str(net.seat)],_discard,true)
	if state.phase=="steal" and mine:
		for p in state.victims:_button(right,tr("Steal: ")+state.players[p].name,func():net.act({"type":"steal","id":p}),true)
	if not state.offer.is_empty():_button(right,tr("Trade offer"),_view_offer,true)
	var resources=CatanIcons.resources(_node("HandBody"),state.players[net.seat].hand,38,true)
	resources.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	_node("Bottom").minimum_size_changed.connect(_queue_layout)
	players.minimum_size_changed.connect(_queue_layout)
	if state.winner!=-1:
		var box=_dialog("Victory")
		_label(box,state.players[state.winner].name+tr(" wins!"),30,GOLD)
		_button(box,tr("Back to menu"),net.leave,true)
	if guide!=null:_tutorial_ui()
	for row_player in net.roster:
		if not row_player.connected:_notice(row_player.name+tr(" disconnected. Waiting to reconnect."))
	_queue_layout()

func _music_icon_button(parent: Node,key: String,tip: String,callback: Callable) -> Button:
	var button=_button(parent,"",callback)
	for variant in ["normal","hover","pressed"]:
		var style=_style(Color("203e4c") if variant=="normal" else Color("365765"),6)
		style.content_margin_left=8;style.content_margin_right=8
		style.content_margin_top=4;style.content_margin_bottom=4
		button.add_theme_stylebox_override(variant,style)
	button.custom_minimum_size=Vector2(34,30)
	button.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	button.tooltip_text=tr(tip);CatanIcons.button_icon(button,key,18)
	return button

func _music_buttons(row: Node) -> Dictionary:
	var widgets={}
	widgets.previous=_music_icon_button(row,"previous",tr("Previous track / restart"),func():net.music_control("previous"))
	widgets.toggle=_music_icon_button(row,"pause",tr("Pause soundtrack"),func():net.music_control("toggle"))
	widgets.next=_music_icon_button(row,"next",tr("Next track"),func():net.music_control("next"))
	return widgets

func _music_volume(row: Node,widgets: Dictionary):
	widgets.mute=_music_icon_button(row,"volume",tr("Mute music for you"),_toggle_music_mute)
	var slider=HSlider.new();slider.min_value=0;slider.max_value=1;slider.step=.01
	slider.custom_minimum_size=Vector2(72,24);slider.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	slider.tooltip_text=tr("Your music volume · does not affect other players")
	slider.value=preferences.values.music;row.add_child(slider)
	slider.value_changed.connect(_set_music_volume)
	widgets.volume=slider

func _set_music_volume(value: float):
	preferences.set_value("music",value)
	audio.apply(preferences.values)

func _toggle_music_mute():
	if preferences.values.music>0:
		music_volume_before_mute=preferences.values.music;_set_music_volume(0)
	else:_set_music_volume(maxf(.1,music_volume_before_mute))

func _open_music():
	var box=_dialog("Music")
	modal.name="MusicLibrary"
	var title=_label(box,"",20,GOLD);title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var description=_label(box,"",14,MUTED);description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var timeline=HBoxContainer.new();box.add_child(timeline)
	var progress=ProgressBar.new();progress.show_percentage=false
	progress.custom_minimum_size=Vector2(80,8);progress.size_flags_horizontal=Control.SIZE_EXPAND_FILL;progress.size_flags_vertical=Control.SIZE_SHRINK_CENTER;timeline.add_child(progress)
	var clock_label=_label(timeline,"0:00 / 0:00",14,MUTED)
	var controls=HBoxContainer.new();box.add_child(controls)
	music_dialog_widgets=_music_buttons(controls)
	_music_volume(controls,music_dialog_widgets)
	music_dialog_widgets.root=box;music_dialog_widgets.title=title;music_dialog_widgets.description=description;music_dialog_widgets.clock=clock_label;music_dialog_widgets.progress=progress
	music_dialog_widgets.status=_label(box,"",14,MUTED)
	music_dialog_widgets.status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	music_dialog_widgets.tracks=[]
	for i in CatanSoundtrack.TRACKS.size():
		var track=CatanSoundtrack.TRACKS[i]
		var row=HBoxContainer.new();box.add_child(row)
		var button=_button(row,track.title,func():net.music_control("select",i))
		button.name="MusicTrack%d" % i;button.toggle_mode=true;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.add_theme_stylebox_override("pressed",_style(Color("3a535d"),8))
		button.tooltip_text=track.mood
		_label(row,CatanSoundtrack.time_text(track.duration),14,MUTED)
		music_dialog_widgets.tracks.append(button)
	_label(box,tr("Original instrumental music · automatically plays through all five tracks."),14,MUTED).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_button(box,"Close",_close_modal)
	_refresh_music_widgets(music_dialog_widgets,net.music_state())

func _refresh_music_widgets(widgets: Dictionary,sample: Dictionary):
	if widgets.is_empty() or not is_instance_valid(widgets.get("root")):return
	var track=CatanSoundtrack.TRACKS[int(sample.track)]
	var ready=sample.get("ready",true)
	widgets.title.text=(tr("Paused · ") if sample.paused else "")+track.title if ready else tr("Joining room soundtrack…")
	widgets.title.tooltip_text=track.title+" · "+tr(track.mood)
	widgets.clock.text=CatanSoundtrack.time_text(sample.position)+" / "+CatanSoundtrack.time_text(track.duration)
	var controller=net.can_control_music() and ready
	for key in ["previous","toggle","next"]:
		widgets[key].disabled=not controller
	CatanIcons.button_icon(widgets.toggle,"play" if sample.paused else "pause",18)
	widgets.toggle.tooltip_text=(tr("Resume soundtrack") if sample.paused else tr("Pause soundtrack")) if controller else tr("The host controls room playback")
	widgets.volume.set_value_no_signal(preferences.values.music)
	CatanIcons.button_icon(widgets.mute,"muted" if preferences.values.music<=0 else "volume",18)
	widgets.mute.tooltip_text=tr("Unmute music for you") if preferences.values.music<=0 else tr("Mute music for you")
	if widgets.has("progress"):
		widgets.description.text=track.mood
		widgets.progress.max_value=track.duration;widgets.progress.value=sample.position
		widgets.status.text=tr("Shared with the room · ")+(tr("You control playback. Everyone keeps their own volume.") if controller else tr("The host controls playback. Your volume is personal.")) if net.online and not net.solo else tr("Your soundtrack · choose a track or let the playlist continue.")
		for i in widgets.tracks.size():
			widgets.tracks[i].set_pressed_no_signal(i==int(sample.track))
			widgets.tracks[i].disabled=not controller

func _journal():
	var box=_dialog(tr("Game log"))
	modal.name="GameLog"
	for line in state.log.slice(maxi(0,state.log.size()-30)):
		_label(box,line,15,MUTED).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_button(box,"Close",_close_modal)

func _phase_text() -> String:
	return {"setup_settlement":"Setup","setup_road":"Setup","play":tr("Build & trade") if state.rolled else tr("Roll dice"),"discard":tr("Discard"),"robber":tr("Robber"),"steal":tr("Steal"),"free_roads":tr("Free roads")}.get(state.phase,"")

func _instruction() -> String:
	if state.winner!=-1: return tr("The expedition is complete.")
	if state.phase=="discard" and state.discards.has(str(net.seat)): return tr("Choose half your resources to return to the bank.")
	if state.turn!=net.seat: return tr("Watch the island grow. Your turn is coming.")
	if state.get("paired",false) and state.phase=="play": return tr("Build, play a card, or trade with the bank.")
	return {"setup_settlement":tr("Place a settlement"),"setup_road":tr("Place an adjoining road"),"play":tr("Build, trade or play a card") if state.rolled else tr("Roll to collect resources"),"discard":tr("Waiting for players to discard."),"robber":tr("Move the robber to a hex"),"steal":tr("Choose a player to steal from."),"free_roads":tr("Place up to two connected roads for free.")}.get(state.phase,"")

func _choose(kind: String):
	var rules=CatanRules.new();rules.s=state
	if state.phase=="play" and rules.build_sites(net.seat,kind).is_empty():
		_notice(tr("No legal space to build a %s.") % tr(kind))
		return
	mode=kind
	board.set_mode(mode,net.seat)
	_hud()
	_notice(tr("Choose a glowing %s on the board.") % (tr("edge") if kind=="road" else tr("corner")))

func _notice(message: String):
	print(message)
	if server_only or not is_instance_valid(toast): return
	if is_instance_valid(audio) and ("failed" in message.to_lower() or "not enough" in message.to_lower()): audio.play("error")
	if message.begins_with("Router") or message.begins_with("Automatic mapping"):
		if "Invite address: " in message: invite_address=message.get_slice("Invite address: ",1)
		connection_status=message
		if net.online and not net.started: _lobby()
	toast.text=CatanI18n.render(message)
	toast.show()
	var old=toast.text
	get_tree().create_timer(8).timeout.connect(func():
		if is_instance_valid(toast) and toast.text==old: toast.hide())

func _dialog(title: String) -> VBoxContainer:
	if is_instance_valid(modal): modal.free()
	modal=Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(modal)
	var shade=ColorRect.new()
	shade.color=Color(0.01,0.035,0.05,0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	var center=MarginContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right"]:center.add_theme_constant_override("margin_"+edge,maxi(20,int((ui.size.x-580)/2)))
	for edge in ["top","bottom"]:center.add_theme_constant_override("margin_"+edge,32)
	modal.add_child(center)
	center.name="DialogMargin"
	var panel=PanelContainer.new();panel.size_flags_vertical=Control.SIZE_SHRINK_CENTER;center.add_child(panel)
	var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(scroll)
	scroll.name="DialogScroll"
	var box=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(box)
	box.minimum_size_changed.connect(func():
		if is_instance_valid(scroll):scroll.custom_minimum_size.y=minf(box.get_combined_minimum_size().y,ui.size.y-96))
	_label(box,title,28,GOLD)
	_queue_layout()
	return box

func _close_modal():
	net.paused=net.solo and inspection_mode
	if is_instance_valid(modal): modal.free()

func _options(parent: Node) -> OptionButton:
	var option=OptionButton.new()
	for r in 5:
		option.add_icon_item(CatanIcons.resource_icon(r),tr(CatanRules.RES[r]))
		option.get_popup().set_item_icon_max_width(r,26)
	option.custom_minimum_size=Vector2(180,44)
	option.expand_icon=true
	option.add_theme_constant_override("icon_max_width",28)
	option.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(option)
	return option

func _spin(parent: Node,limit: int=24) -> SpinBox:
	var spin=SpinBox.new()
	spin.min_value=1
	spin.max_value=limit
	spin.value=1
	spin.custom_minimum_size=Vector2(84,44)
	spin.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	parent.add_child(spin)
	spin.get_line_edit().add_theme_font_size_override("font_size",20)
	spin.get_line_edit().add_theme_color_override("font_uneditable_color",CREAM)
	spin.get_line_edit().alignment=HORIZONTAL_ALIGNMENT_CENTER
	return spin

func _trade(reset: bool=true):
	if reset:trade_players=false
	var box=_dialog("Trade")
	modal.name="TradeDialog"
	_label(box,tr("Your resources"),14,MUTED)
	CatanIcons.resources(box,state.players[net.seat].hand,24,true)
	var tabs=HBoxContainer.new();box.add_child(tabs)
	var group=ButtonGroup.new()
	var bank_tab=Button.new();bank_tab.text="Bank";bank_tab.toggle_mode=true;bank_tab.button_group=group;bank_tab.button_pressed=not trade_players or state.get("paired",false);tabs.add_child(bank_tab)
	var player_tab=Button.new();player_tab.text="Players";player_tab.toggle_mode=true;player_tab.button_group=group;player_tab.disabled=state.get("paired",false);player_tab.button_pressed=trade_players and not player_tab.disabled;tabs.add_child(player_tab)
	player_tab.tooltip_text=tr("Unavailable during a paired turn") if player_tab.disabled else tr("Offer a trade to the other players")
	_label(box,"Give",14,MUTED)
	var row=HBoxContainer.new();box.add_child(row)
	selected_give=_options(row);selected_give.select(trade_give);amount_give=_spin(row)
	_label(box,"Receive",14,MUTED)
	var row2=HBoxContainer.new();box.add_child(row2)
	selected_get=_options(row2);selected_get.select(trade_get);amount_get=_spin(row2)
	var preview=_label(box,"",18,GOLD)
	preview.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var reason=_label(box,"",14,MUTED)
	reason.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var rules=CatanRules.new();rules.s=state
	var give_choices=_trade_choices(row,selected_give,true)
	var get_choices=_trade_choices(row2,selected_get,false)
	var bank=_button(box,tr("Bank trade"),func():net.act({"type":"bank_trade","give":selected_give.selected,"receive":selected_get.selected}),true)
	var offer_button=_button(box,tr("Offer to all players"),func():
		var give=[0,0,0,0,0];var receive=[0,0,0,0,0]
		give[selected_give.selected]=int(amount_give.value);receive[selected_get.selected]=int(amount_get.value)
		net.act({"type":"offer_trade","give":give,"receive":receive}),true)
	var refresh_trade=func():
		var banking=bank_tab.button_pressed
		trade_players=not banking;trade_give=selected_give.selected;trade_get=selected_get.selected
		for r in 5:
			give_choices[r].button_pressed=r==trade_give
			get_choices[r].button_pressed=r==trade_get
			give_choices[r].tooltip_text=tr("%s · You have %d · Bank rate %d:1") % [tr(CatanRules.RES[r]),state.players[net.seat].hand[r],rules.rate(net.seat,r)]
			get_choices[r].tooltip_text=tr("%s · Bank has %d") % [tr(CatanRules.RES[r]),state.bank[r]]
		bank.visible=banking;offer_button.visible=not banking
		amount_give.editable=not banking;amount_get.editable=not banking
		if banking:
			amount_give.set_value_no_signal(rules.rate(net.seat,selected_give.selected));amount_get.set_value_no_signal(1)
			bank.text=tr("Bank trade · %d:1") % rules.rate(net.seat,selected_give.selected)
		var available=state.players[net.seat].hand[selected_give.selected]>=int(amount_give.value)
		var different=selected_give.selected!=selected_get.selected
		bank.disabled=not available or not different or state.bank[selected_get.selected]<1
		offer_button.disabled=not available or not different or state.get("paired",false)
		preview.text="%d %s → %d %s" % [int(amount_give.value),tr(CatanRules.RES[trade_give]),int(amount_get.value),tr(CatanRules.RES[trade_get])]
		reason.text=tr("Choose different resources.") if not different else (tr("You need %d more %s.") % [int(amount_give.value)-state.players[net.seat].hand[trade_give],tr(CatanRules.RES[trade_give])] if not available else (tr("The bank has none of that resource.") if banking and state.bank[trade_get]==0 else (tr("Your best port rate: %d:1 · Bank stock: %d") % [rules.rate(net.seat,trade_give),state.bank[trade_get]] if banking else tr("Any player who can afford this offer may accept it."))))
	selected_give.item_selected.connect(func(_value):refresh_trade.call())
	selected_get.item_selected.connect(func(_value):refresh_trade.call())
	bank_tab.pressed.connect(refresh_trade);player_tab.pressed.connect(refresh_trade)
	amount_give.value_changed.connect(func(_value):refresh_trade.call())
	amount_get.value_changed.connect(func(_value):refresh_trade.call())
	refresh_trade.call()
	_button(box,"Close",_close_modal)

func _trade_choices(parent: Node,selection: OptionButton,giving: bool) -> Array:
	selection.hide()
	var choices=HBoxContainer.new();choices.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(choices);parent.move_child(choices,0)
	var buttons=[]
	for r in 5:
		var b=_button(choices,str(state.players[net.seat].hand[r]) if giving else "",func():
			selection.select(r);selection.item_selected.emit(r))
		b.toggle_mode=true;b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("pressed",_style(GOLD,8))
		b.add_theme_color_override("font_pressed_color",INK)
		b.add_theme_color_override("icon_pressed_color",INK)
		CatanIcons.button_icon(b,CatanIcons.RESOURCES[r],24)
		buttons.append(b)
	return buttons

func _resource_text(a: Array) -> String:
	var parts=[]
	for r in 5:
		if a[r]>0: parts.append("%d %s" % [a[r],tr(CatanRules.RES[r])])
	return ", ".join(parts)

func _trade_notifications(previous: Dictionary,previous_offer: Dictionary,fresh: bool):
	var offer=state.get("offer",{})
	var event=state.get("trade_event",{})
	var changed=not event.is_empty() and event.get("id",0)!=previous.get("id",0)
	if offer.is_empty():notifications.dismiss("trade")
	if not offer.is_empty() and (fresh or offer!=previous_offer or changed and event.get("kind","")=="offered"):
		var sender=int(offer.from)
		var message=tr("%s offers %s for %s.") % [state.players[sender].name,_resource_text(offer.give),_resource_text(offer.receive)]
		if sender==net.seat:message=tr("Your trade offer: %s for %s.") % [_resource_text(offer.give),_resource_text(offer.receive)]
		else:
			var rules=CatanRules.new();rules.s=state
			if not rules.can_pay(net.seat,offer.receive):message+=tr(" You don't have the requested resources.")
		notifications.show_notice("trade",message,tr("View offer"),_view_offer)
	if fresh or not changed:return
	var actor=int(event.actor)
	var message=""
	match event.kind:
		"accepted":
			if actor==net.seat:message=tr("%s accepted your trade.") % state.players[event.other].name
			elif event.other==net.seat:message=tr("Trade completed with %s.") % state.players[actor].name
			else:message=tr("%s traded with %s.") % [state.players[actor].name,state.players[event.other].name]
		"withdrawn":message=tr("Trade offer withdrawn.") if actor==net.seat else tr("%s withdrew their trade offer.") % state.players[actor].name
		"bank":
			if actor==net.seat:message=tr("Bank trade completed.")
	if not message.is_empty():notifications.show_notice("trade_result",message,"",Callable(),8)

func _view_offer():
	if state.get("offer",{}).is_empty():return
	var box=_dialog(tr("A trade on the table"))
	_label(box,state.players[state.offer.from].name+tr(" offers:"),20)
	CatanIcons.resources(box,state.offer.give,38)
	_label(box,tr("In return for:"),20)
	CatanIcons.resources(box,state.offer.receive,38)
	if state.offer.from!=net.seat:
		var accept=_button(box,tr("Accept trade"),func(): net.act({"type":"accept_trade"}),true)
		var rules=CatanRules.new();rules.s=state
		accept.disabled=not rules.can_pay(net.seat,state.offer.receive)
		if accept.disabled:_label(box,CatanI18n.message("You need %s more to accept this offer.",[rules._missing(net.seat,state.offer.receive)]),14,MUTED).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	else: _button(box,tr("Withdraw offer"),func(): net.act({"type":"cancel_trade"}))
	_button(box,"Close",_close_modal)

func _discard():
	var box=_dialog(tr("The robber approaches"))
	var needed=state.discards[str(net.seat)]
	_label(box,tr("Return exactly %d resources to the bank.") % needed,18)
	var spins=[]
	for r in 5:
		var row=HBoxContainer.new()
		box.add_child(row)
		CatanIcons.icon(row,CatanIcons.RESOURCES[r],34)
		row.tooltip_text=tr(CatanRules.RES[r])
		var spin=_spin(row,state.players[net.seat].hand[r])
		spin.min_value=0
		spin.value=0
		spins.append(spin)
	_button(box,tr("Discard selected resources"),func():
		var cards=[]
		for spin in spins: cards.append(int(spin.value))
		net.act({"type":"discard","cards":cards}),true)
	_button(box,"Close",_close_modal)

func _card_section(play: bool):
	var box=_node("CardsBody")
	var player=state.players[net.seat]
	_label(_node("CardShop"),tr("Development cards"),16,GOLD).name="CardHeading"
	var buy=_button(_node("CardShop"),tr("Buy card"),func():net.act({"type":"buy_card"}))
	buy.name="BuyCard";CatanIcons.button_icon(buy,"cards",18)
	var rules=CatanRules.new();rules.s=state
	buy.disabled=not play or not state.rolled or not rules.can_pay(net.seat,CatanRules.COST.buy_card) or state.deck_count==0
	buy.tooltip_text=tr("Buy development card: 1 wool, 1 grain, 1 ore. %d left in deck.") % state.deck_count
	if state.deck_count==0:buy.tooltip_text+="\n"+tr("No development cards remain.")
	elif not rules.can_pay(net.seat,CatanRules.COST.buy_card):buy.tooltip_text+="\n"+CatanI18n.render(rules.cost_error(net.seat,"buy_card"))
	var names=["Knight","Roads","Plenty","Monopoly","Victory"]
	var tips=[tr("Move the robber and steal a resource."),tr("Build two roads for free."),tr("Take two resources from the bank."),tr("Take one resource type from every player."),tr("Already included in your score; never needs to be played.")]
	for i in 5:
		var count=player.cards[i]+player.new_cards[i]
		if count==0:continue
		var b=_button(box,"",func():
			if i<2:net.act({"type":"play_card","id":i})
			elif i<4:_resource_card(i))
		b.name="Card%d" % i
		b.custom_minimum_size=Vector2.ZERO
		b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		var accent=[Color("97654b"),Color("527e72"),Color("72904e"),Color("54768e"),Color("b28a36")][i]
		for variant in ["normal","hover","pressed","disabled","focus"]:
			var paper=_style(Color("eee1bb") if variant!="hover" else Color("fff1ce"),10)
			paper.set_border_width_all(2);paper.border_color=accent
			paper.shadow_color=Color(0,0,0,.32);paper.shadow_size=5;paper.shadow_offset=Vector2(-2,3)
			b.add_theme_stylebox_override(variant,paper)
		var face=VBoxContainer.new();face.name="CardFace"
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		face.offset_left=10;face.offset_right=-10;face.offset_top=8;face.offset_bottom=-8
		face.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(face)
		var header=HBoxContainer.new();face.add_child(header)
		var title=_label(header,tr(names[i]),16,Color("263c36"));title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		_label(header,"×%d" % count,16,accent)
		var picture=CenterContainer.new();picture.name="CardPicture";face.add_child(picture)
		var art=CatanIcons.icon(picture,["knight","road","hand","trade","star"][i],48)
		art.modulate=accent
		var effects=["Move the robber", "Build two free roads", "Take two resources", "Claim one resource type", "+1 victory point"]
		var effect=_label(face,tr(effects[i]),13,Color("44574b"));effect.name="CardEffect"
		effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;effect.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var space=Control.new();space.size_flags_vertical=Control.SIZE_EXPAND_FILL;face.add_child(space)
		var ready=player.cards[i]>0 and not state.card_played and play
		var status=tr("Victory points") if i==4 else (tr("Ready") if ready else (tr("Next turn") if player.cards[i]==0 else tr("Waiting")))
		var caption=_label(face,status,14,Color("44574b"));caption.name="CardStatus";caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		for child in face.find_children("*","Control",true,false):child.mouse_filter=Control.MOUSE_FILTER_IGNORE
		b.mouse_entered.connect(func():_card_preview(b,true))
		b.mouse_exited.connect(func():_card_preview(b,false))
		b.focus_entered.connect(func():_card_preview(b,true))
		b.focus_exited.connect(func():_card_preview(b,false))
		b.tooltip_text=tips[i]+tr("\n%d ready · %d bought this turn") % [player.cards[i],player.new_cards[i]]
		b.disabled=i==4 or not play or player.cards[i]==0 or state.card_played
		if i<4 and player.new_cards[i]>0:b.tooltip_text+=tr("\nNew action cards become playable next turn.")
		if i<4 and state.card_played:b.tooltip_text+=tr("\nYou have already played an action card this turn.")
	if box.get_child_count()==0:
		var empty=_label(box,tr("No development cards"),14,MUTED)
		empty.name="EmptyCards";empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		empty.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)

func _layout_cards(top: float,bottom: float):
	var rail=_node("CardsRail")
	rail.offset_top=top;rail.offset_bottom=bottom
	_node("CardHeading").visible=ui.size.x>=1000
	var body=_node("CardsBody")
	body.offset_top=_node("CardShop").get_combined_minimum_size().y+12
	var cards=body.get_children().filter(func(child):return child is Button)
	var available=maxf(100,rail.size.y-body.offset_top)
	var card_height=minf(180,maxf(76,available-32*maxi(0,cards.size()-1)))
	var step=minf(92,maxf(0,(available-card_height)/maxi(1,cards.size()-1)))
	for i in cards.size():
		cards[i].position=Vector2(0,i*step)
		cards[i].size=Vector2(rail.size.x,card_height)
		cards[i].set_meta("hand_rect",Rect2(cards[i].position,cards[i].size))
		_card_preview(cards[i],false)

func _card_preview(card: Button,expanded: bool):
	if not card.has_meta("hand_rect"):return
	var rest: Rect2=card.get_meta("hand_rect")
	card.z_index=2 if expanded else 0
	card.position=rest.position+Vector2(-12 if expanded else 0,0)
	card.size=Vector2(rest.size.x,180 if expanded else rest.size.y)
	if expanded:card.position.y=minf(card.position.y,card.get_parent().size.y-card.size.y)
	card.find_child("CardEffect",true,false).visible=card.size.y>=140
	card.find_child("CardStatus",true,false).visible=card.size.y>=110
	card.find_child("CardPicture",true,false).get_child(0).custom_minimum_size=Vector2.ONE*(48 if card.size.y>=140 else 32)

func _cards():
	# Compatibility for tutorial shortcuts: cards are always present in the HUD.
	_close_modal()

func _sum(a: Array) -> int:
	var result=0
	for n in a: result+=n
	return result

func _resource_card(id: int):
	var box=_dialog(tr("Year of plenty") if id==2 else "Monopoly")
	var first=_options(box)
	var second: OptionButton
	if id==2: second=_options(box)
	_button(box,tr("Play card"),func():
		var a={"type":"play_card","id":id,"resource":first.selected}
		if id==2:
			var cards=[0,0,0,0,0]
			cards[first.selected]+=1
			cards[second.selected]+=1
			a.cards=cards
		net.act(a),true)
	_button(box,"Back",_close_modal)

func _confirm_leave():
	var box=_dialog(tr("Leave the expedition?"))
	modal.name="LeaveConfirm"
	_label(box,tr("Leave this solo expedition?") if net.solo else tr("Leaving pauses this match for the other players.\nIf you host, the room will close."),18)
	_button(box,"Stay",_close_modal,true)
	_button(box,tr("Leave game"),net.leave)

func _help():
	var box=_dialog(tr("Your guide to the island"))
	modal.name="Guide"
	var text=tr("1. Gather 3–6 players (humans or bots). Everyone readies up.\n2. Place two settlements and roads in snake order.\n3. Roll: neighboring settlements collect 1 resource; cities 2.\n4. Connect roads, build settlements, upgrade to cities.\n5. Trade with players or the bank; coastal ports give better rates.\n6. A seven means discarding half if you have more than seven,\n    then moving the robber and stealing from a neighbor.\n7. Buy development cards; play at most one per turn.\n8. Reach 10 points on your turn to win. Settlements give 1,\n    cities 2, longest road and largest army 2 each.\n\nClick glowing board markers to build. Right-drag to orbit.\nScroll to zoom; middle-drag pans; F focuses a tile.\nH hides the interface; Home fits the board. Hover for costs.\n\n5–6 players: 30 hexes and paired turns. After the main turn,\n the player 3 seats ahead builds, plays cards and trades only\n with the bank. Then the next main player rolls.\n\nOnline hosts need UDP 24567 reachable from the internet.\nUse router mapping, port forwarding, or a dedicated server.")
	_label(box,text,16).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_button(box,tr("Chart a course  →"),_close_modal,true)

func _node(node_name: String) -> Node:
	return screen.find_child(node_name,true,false)

func _bind(node_name: String,callback: Callable,primary: bool=false):
	var button=_node(node_name) as Button
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	if primary:
		button.add_theme_stylebox_override("normal",_style(GOLD))
		button.add_theme_stylebox_override("hover",_style(GOLD.lightened(0.1)))
		button.add_theme_color_override("font_color",INK)
		button.add_theme_color_override("font_hover_color",INK)
		button.add_theme_color_override("icon_normal_color",INK)
		button.add_theme_color_override("icon_hover_color",INK)
	button.pressed.connect(func():
		if is_instance_valid(audio): audio.play("click")
		callback.call(),CONNECT_DEFERRED)

func _solo():
	var pname=preferences.values.player_name
	if is_instance_valid(name_field): pname=name_field.text.strip_edges()
	if pname.is_empty(): pname="Voyager"
	preferences.set_value("player_name",pname)
	net.host_solo(pname)
	net.configure_bot("add",-1,1)
	net.configure_bot("add",-1,1)

func _apply_preferences():
	var language_changed=active_language!=preferences.values.language
	active_language=preferences.values.language
	CatanI18n.apply(active_language)
	if language_changed:call_deferred("_refresh_language")
	preferences.apply_display(get_viewport())
	if is_instance_valid(board): board.apply_preferences(preferences.values)
	if is_instance_valid(audio): audio.apply(preferences.values)
	net.bot_delay=[1.25,0.7,0.2][preferences.values.bot_speed]
	net.my_style=preferences.values.piece_style
	net.my_color=preferences.values.player_color
	if net.online and net.seat>=0 and net.seat<net.roster.size() and int(net.roster[net.seat].get("piece_style",0))!=net.my_style:
		net.choose_piece_style(net.my_style)
	if net.online and net.seat>=0 and net.seat<net.roster.size() and str(net.roster[net.seat].get("color",""))!=net.my_color:
		net.choose_color(net.my_color)
	if is_instance_valid(ui): _apply_text(ui)

func _open_settings():
	if is_instance_valid(modal): modal.free()
	modal=load("res://scenes/ui/settings.tscn").instantiate()
	ui.add_child(modal)
	_apply_text(modal)
	net.paused=net.solo
	modal.setup(preferences)
	_button(modal.get_node("%Navigation"),"Updates",_open_updates)
	_button(modal.get_node("%Navigation"),"Appearance",_open_cosmetics)
	modal.find_child("ExitDesktop",true,false).pressed.connect(_exit_desktop)
	modal.preferences_changed.connect(_apply_preferences)
	modal.close_requested.connect(_close_modal,CONNECT_DEFERRED)
	_apply_text(modal)

func _open_cosmetics():
	if is_instance_valid(modal):modal.free()
	modal=load("res://scenes/ui/cosmetics.tscn").instantiate()
	ui.add_child(modal)
	modal.setup(preferences,net)
	modal.close_requested.connect(_close_modal,CONNECT_DEFERRED)
	net.paused=net.solo
	_apply_text(modal)

func _tutorial_start():
	var pname=preferences.values.player_name
	if is_instance_valid(name_field) and not name_field.text.strip_edges().is_empty(): pname=name_field.text.strip_edges()
	preferences.set_value("player_name",pname)
	net.host_solo(pname)
	net.roster.append({"id":-1,"name":"Guide","ready":true,"connected":true,"bot":true,"difficulty":0})
	guide=CatanTutorial.new()
	guide.load_lesson(net,pname)

func _action_applied(_player: int,action: Dictionary):
	if guide!=null: guide.observe(action,net)

func _tutorial_ui():
	if is_instance_valid(tutorial_panel): tutorial_panel.free()
	tutorial_panel=load("res://scenes/ui/tutorial.tscn").instantiate()
	ui.add_child(tutorial_panel)
	tutorial_panel.find_child("Progress",true,false).text=tr("LESSON %d / %d") % [guide.step+1,CatanTutorial.LESSONS.size()]
	tutorial_panel.find_child("LessonTitle",true,false).text=guide.current().title
	tutorial_panel.find_child("LessonBody",true,false).text=guide.current().body
	tutorial_panel.find_child("LessonStatus",true,false).text=tr("WELL DONE") if guide.completed and not guide.current().action.is_empty() else tr("GUIDED PRACTICE")
	var next=tutorial_panel.find_child("NextLesson",true,false)
	next.disabled=not guide.completed
	next.text=tr("Play solo  →") if guide.step==CatanTutorial.LESSONS.size()-1 else tr("Continue  →")
	next.pressed.connect(func():_tutorial_step(1),CONNECT_DEFERRED)
	var previous=tutorial_panel.find_child("PreviousLesson",true,false)
	previous.disabled=guide.step==0
	previous.pressed.connect(func():_tutorial_step(-1),CONNECT_DEFERRED)
	tutorial_panel.find_child("RestartLesson",true,false).pressed.connect(func():guide.load_lesson(net,preferences.values.player_name),CONNECT_DEFERRED)
	tutorial_panel.find_child("SkipLesson",true,false).pressed.connect(func():_tutorial_step(1),CONNECT_DEFERRED)

func _tutorial_step(direction: int):
	if guide.step+direction>=CatanTutorial.LESSONS.size():
		_solo()
		return
	guide.step=clampi(guide.step+direction,0,CatanTutorial.LESSONS.size()-1)
	guide.load_lesson(net,preferences.values.player_name)

func _apply_text(root: Node):
	for label in root.find_children("*","Label",true,false):
		if not label.has_meta("base_font_size"): label.set_meta("base_font_size",label.get_theme_font_size("font_size"))
		label.add_theme_font_size_override("font_size",maxi(int(label.get_meta("base_font_size")),16 if preferences.values.large_text else 14))

func _toggle_inspection():
	if state.is_empty():return
	inspection_mode=not inspection_mode
	screen.visible=not inspection_mode
	inspection_hint.visible=inspection_mode
	board.show_labels=not inspection_mode
	_queue_layout()
	board.set_mode("" if inspection_mode else mode,-1 if inspection_mode else net.seat)
	if net.solo:net.paused=inspection_mode

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE and is_instance_valid(modal):
			_close_modal()
			get_viewport().set_input_as_handled()
		elif (event.keycode==KEY_H or (event.keycode==KEY_ESCAPE and inspection_mode)) and not is_instance_valid(modal):
			_toggle_inspection()
			get_viewport().set_input_as_handled()

func _queue_layout():
	if layout_queued:return
	layout_queued=true
	call_deferred("_layout_screen")

func _layout_screen():
	layout_queued=false
	if not is_instance_valid(ui) or not is_instance_valid(screen):return
	var width=ui.size.x
	var height=ui.size.y
	toast.offset_left=-minf(470,width*.5-20)
	toast.offset_right=minf(470,width*.5-20)
	if is_instance_valid(notifications):
		notifications.offset_left=-minf(420,width-32)
		notifications.offset_right=-16
		notifications.offset_top=132 if screen.name=="GameHUD" else 72
	if screen.name=="MainMenu":
		var panel=_node("Expedition")
		panel.offset_right=minf(390,width-90)
		var fixed_height=panel.get_theme_stylebox("panel").get_minimum_size().y+30
		for name in ["Brand","Title","MenuNote"]:fixed_height+=_node(name).get_combined_minimum_size().y
		var scroll_height=minf(_node("MenuItems").get_combined_minimum_size().y,height-48-fixed_height)
		_node("MenuScroll").custom_minimum_size.y=maxf(0,scroll_height)
		panel.offset_top=-(fixed_height+scroll_height)*.5
		panel.offset_bottom=(fixed_height+scroll_height)*.5
		board.view_region=Rect2(minf(410,width*.42),24,maxf(300,width-430),height-48)
	elif screen.name=="GameHUD":
		_node("PhaseLabel").visible=width>=1120
		var players=_node("PlayersBody")
		for chip in players.get_children():chip.custom_minimum_size.x=minf(180,(width-32-(state.players.size()-1)*6)/state.players.size())
		var bottom=_node("Bottom")
		bottom.offset_left=16
		bottom.offset_right=-16
		var bottom_height=maxf(116,bottom.get_combined_minimum_size().y)
		bottom.offset_top=-12-bottom_height
		_node("Players").offset_bottom=76+players.get_combined_minimum_size().y
		var top=maxf(132,76+players.get_combined_minimum_size().y+10)
		if guide!=null and is_instance_valid(tutorial_panel):
			top=tutorial_panel.find_child("LessonPanel",true,false).get_global_rect().end.y+10
		notifications.offset_top=top
		_layout_cards(top,height-bottom_height-26)
		board.view_region=Rect2(20,top,width-236,maxf(100,height-top-bottom_height-30))
	elif screen.name=="Lobby":
		_node("Voyage").custom_minimum_size.x=280 if width<1100 else 340
		board.view_region=Rect2(0,0,width,height)
	if inspection_mode:board.view_region=Rect2(16,16,width-32,height-64)
	board._update_camera()
	if is_instance_valid(modal) and modal.has_node("DialogMargin"):
		var margin=modal.get_node("DialogMargin")
		for edge in ["left","right"]:margin.add_theme_constant_override("margin_"+edge,maxi(20,int((width-580)/2)))
		var scroll=modal.find_child("DialogScroll",true,false)
		scroll.custom_minimum_size.y=minf(scroll.get_child(0).get_combined_minimum_size().y,height-96)

func _exit_tree():
	CatanIcons.textures.clear()
	CatanMiniature.boxes.clear()

func _exit_desktop():
	net.leave()
	get_tree().quit()

func _open_updates():
	var box=_dialog(tr("Game updates"))
	modal.name="Updates"
	net.paused=net.solo
	_label(box,tr("Installed: %s · Multiplayer protocol %d") % [CatanBuildInfo.VERSION,CatanBuildInfo.PROTOCOL],16)
	var message=_label(box,"",18);message.name="UpdateMessage";message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var progress=ProgressBar.new();progress.name="UpdateProgress";progress.custom_minimum_size.y=20;box.add_child(progress)
	var details=_label(box,"",15);details.name="UpdateDetails";details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_button(box,tr("Check for updates"),updater.check_updates).name="UpdateCheck"
	_button(box,tr("Download update"),updater.download_update,true).name="UpdateDownload"
	_button(box,tr("Restart to update"),_install_update,true).name="UpdateInstall"
	_button(box,"Later",_close_modal)
	_updates_changed()

func _updates_changed():
	if updater==null:return
	var data=updater.status
	var stage=data.get("state","idle")
	var release_version=str(data.get("version",""))
	if stage in ["available","ready"] and not release_version.is_empty():
		var notification_key=stage+":"+release_version
		if not notified_updates.has(notification_key):
			notified_updates[notification_key]=true
			var message=tr("Update %s is available.") % release_version if stage=="available" else tr("Update %s is ready to install.") % release_version
			notifications.show_notice("update",message,tr("View update"),_open_updates)

	if is_instance_valid(screen):
		var button=screen.find_child("CheckUpdates",true,false)
		if button:button.text=tr("Update available") if stage=="available" else tr("Update ready") if stage=="ready" else tr("Game updates")
	if not is_instance_valid(modal) or modal.name!="Updates":return
	modal.find_child("UpdateMessage",true,false).text=CatanI18n.update_message(data)
	var details=tr("Updates are verified before installation. Downloads can run in the background.")
	if data.get("total",0)>0:
		details=tr("%s download · %.1f MiB") % [tr("Delta") if data.get("kind","")=="delta" else tr("Full"),float(data.total)/1048576.0]
	if data.has("version"):details+=tr("\nRelease %s · Protocol %d") % [data.version,data.get("protocol",CatanBuildInfo.PROTOCOL)]
	if data.get("protocol",CatanBuildInfo.PROTOCOL)!=CatanBuildInfo.PROTOCOL:details+=tr("\nThis release changes multiplayer compatibility. Your group should update together.")
	if net.online:details+=tr("\nLeave this room before installing; hosting an update would close it.")
	modal.find_child("UpdateDetails",true,false).text=details
	var bar=modal.find_child("UpdateProgress",true,false)
	bar.visible=stage in ["downloading","preparing"]
	bar.value=100.0*float(data.get("bytes",0))/maxf(1,float(data.get("total",0)))
	modal.find_child("UpdateCheck",true,false).disabled=not updater.supported or updater.busy()
	modal.find_child("UpdateDownload",true,false).visible=stage=="available"
	modal.find_child("UpdateDownload",true,false).disabled=updater.busy()
	modal.find_child("UpdateInstall",true,false).visible=stage=="ready"
	modal.find_child("UpdateInstall",true,false).disabled=net.online or updater.busy()

func _install_update():
	if updater.install_update(net.online):
		net.leave()
		get_tree().quit()

func _update_health_ready():
	# A one-use startup acknowledgement for the updater's rollback check.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--update-health="):
			var token=arg.trim_prefix("--update-health=")
			if token.length()!=32 or token.hex_decode().size()!=16:return
			var path=OS.get_executable_path().get_base_dir().path_join(".n-catan-health-"+token)
			var file=FileAccess.open(path,FileAccess.WRITE)
			if file:file.store_string(token);file.close()

func _show_turn_banner():
	if not is_instance_valid(turn_banner):
		turn_banner=Label.new()
		turn_banner.name="YourTurnBanner"
		turn_banner.mouse_filter=Control.MOUSE_FILTER_IGNORE
		turn_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		turn_banner.grow_horizontal=Control.GROW_DIRECTION_BOTH
		turn_banner.grow_vertical=Control.GROW_DIRECTION_BOTH
		turn_banner.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		turn_banner.add_theme_font_size_override("font_size",48)
		turn_banner.add_theme_color_override("font_outline_color",Color("102938"))
		turn_banner.add_theme_constant_override("outline_size",12)
		ui.add_child(turn_banner)
		turn_banner_timer=Timer.new()
		turn_banner_timer.one_shot=true
		turn_banner_timer.wait_time=3.0
		turn_banner.add_child(turn_banner_timer)
		turn_banner_timer.timeout.connect(turn_banner.hide)
	turn_banner.text=tr("Your turn")
	turn_banner.add_theme_color_override("font_color",board.player_color(net.seat))
	turn_banner.show()
	ui.move_child(turn_banner,ui.get_child_count()-1)
	turn_banner_timer.start()

func _refresh_language():
	if server_only:return
	if net.started and not state.is_empty():_hud()
	elif net.online:_lobby()
	else:_home()
	if is_instance_valid(modal) and modal.name=="Settings":
		modal.refresh()
	if is_instance_valid(turn_banner):turn_banner.text=tr("Your turn")
	if guide!=null:_tutorial_ui()
