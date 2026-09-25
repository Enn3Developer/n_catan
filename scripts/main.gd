extends Node3D

@onready var net: CatanNetwork=$Network
@onready var board: CatanBoard=$Board
@onready var audio: CatanAudio=$Audio
@onready var updater: CatanUpdater=$Updater
@onready var ui_day_night=$UIDayNight
@onready var ui: Control=%Root
@onready var screens: Control=%Screens
@onready var tutorial_layer: Control=%Tutorial
@onready var modals: Control=%Modals
@onready var toast: Label=%Toast
@onready var notifications=%Notifications
@onready var inspection_hint: Label=%InspectionHint
@onready var turn_banner: Label=%TurnBanner
@onready var turn_banner_timer: Timer=%TurnBanner/Timer
var screen: CatanScreen
var toast_generation=0
var modal: Control
var state={}
var mode=""
var name_field: LineEdit
var address_field: LineEdit
var password_field: LineEdit
var host_password_field: LineEdit
var server_only=false
var connection_status=""
var preferences=CatanSettings.new()
var guide: CatanTutorial
var tutorial_panel: Control
var invite_address=""
# A join in flight keeps the guest on the join form until the host seats them.
var joining=false
var join_draft={"address":"","password":""}
var inspection_mode=false
var layout_queued=false
## The trade dialog's choices, kept while the dialog is rebuilt for each snapshot.
var trade_draft={}
## Whether the board shows the menu's island rather than a game's.
var menu_island=false
var music_ui_clock=0.0
var music_volume_before_mute=.42
var notified_updates={}
var turn_clock_left=0.0
var turn_clock_limit=0.0
var active_language=-1
var quitting=false
## The whole game log. Snapshots carry only the newest lines, which are merged in here.
var game_log=[]
var log_pending=false
## Who the last away toast named, so it shows once per change.
var away_shown=""

func _ready():
	CatanDiagnostics.event("main.ready")
	get_tree().auto_accept_quit=false
	CatanI18n.apply(preferences.values.language)
	active_language=preferences.values.language
	net.my_look=preferences.look()
	net.my_color=preferences.values.player_color
	if "--server" in OS.get_cmdline_user_args():
		server_only=true
		set_process(false)
		var password=""
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--password="): password=arg.trim_prefix("--password=")
		var err=net.host("Server",password,true)
		print("CATAN_SERVER_READY port=24567" if err==OK else "SERVER_FAILED %s" % err)
		if err==OK:
			var address="127.0.0.1:24567"
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--address="):address=arg.trim_prefix("--address=")
			print("CATAN_INVITE "+net.invite(address))
		return
	ui_day_night.setup(ui)
	_apply_preferences()
	_home()
	if updater.supported:updater.check_updates.call_deferred()
	_update_health_ready()
	CatanDiagnostics.event("main.ready.complete")

func _clear(scene_path: String):
	CatanDiagnostics.event("ui.screen",scene_path)
	if is_instance_valid(screen): screen.free()
	var keep_modal=is_instance_valid(modal) and (modal.name in ["Settings","Cosmetics","MusicLibrary","Updates"] or (scene_path=="res://scenes/ui/hud.tscn" and modal.name in ["Guide","GameLog","LeaveConfirm","TradeOffer","Victory","Discard","ResourceCard"]))
	if is_instance_valid(modal) and not keep_modal: modal.free()
	screen=load(scene_path).instantiate()
	screens.add_child(screen)
	screen.layout_changed.connect(_queue_layout)
	_queue_layout()

func _home():
	turn_banner.hide()
	notifications.dismiss("trade")
	notifications.dismiss("trade_result")
	inspection_mode=false
	inspection_hint.hide()
	board.show_labels=true
	if not menu_island:_build_menu_island()
	board.reset_camera(true)
	_clear("res://scenes/ui/home.tscn")
	state={}
	game_log=[]
	log_pending=false
	away_shown=""
	turn_clock_limit=0.0
	turn_clock_left=0.0
	guide=null
	if is_instance_valid(tutorial_panel): tutorial_panel.free()
	board.set_mode("",-1)
	board.camera.h_offset=-2.4
	board.show_labels=false
	board.camera.v_offset=0
	board.camera.fov=35
	name_field=screen.name_field
	address_field=screen.address_field
	password_field=screen.password_field
	host_password_field=screen.host_password_field
	screen.setup(preferences.values.player_name,not net.reconnect_token.is_empty())
	_route(screen,{
		"solo_requested":_solo,
		"tutorial_requested":_tutorial_start,
		"host_requested":_host,
		"join_requested":_join,
		"join_cancel_requested":_cancel_join,
		"reconnect_requested":_reconnect,
		"settings_requested":_open_settings,
		"cosmetics_requested":_open_cosmetics,
		"music_requested":_open_music,
		"updates_requested":_open_updates,
		"exit_requested":_exit_desktop,
	})
	_updates_changed()
	_apply_text(screen)

## The main menu floats over an island dealt from a new random seed at every
## launch and after every game; a language change keeps the current one.
func _build_menu_island():
	board.build(CatanRules.new().create(["Voyager","Mariner"],randi_range(1,999999)))
	menu_island=true

# Screens and dialogs report intent through signals. Handlers run deferred so
# they may replace the screen or dialog that emitted them.
func _route(source: Object,routes: Dictionary):
	for signal_name in routes: source.connect(signal_name,routes[signal_name],CONNECT_DEFERRED)

func _host():
	var pname=name_field.text.strip_edges()
	if pname.is_empty(): pname="Voyager"
	preferences.set_value("player_name",pname)
	var err=net.host(pname,host_password_field.text)
	if err!=OK: _rejected(tr("Could not host on UDP 24567. Another server may be running."))

func _join():
	var pname=name_field.text.strip_edges()
	if pname.is_empty(): pname="Voyager"
	preferences.set_value("player_name",pname)
	join_draft={"address":address_field.text.strip_edges(),"password":password_field.text}
	joining=true
	var err=net.join_room(join_draft.address,pname,join_draft.password)
	if err!=OK and joining:_join_failed("Paste a valid invite code from the host.")

func _reconnect():
	if net.reconnect_address.is_empty():return
	join_draft={"address":net.reconnect_address,"password":net.reconnect_password}
	joining=true
	net.reconnect()

func _cancel_join():
	joining=false
	net.leave()
	_show_join_form(false)

func _join_failed(message: String):
	joining=false
	_show_join_form(false)
	screen.show_join_error(message)

func _show_join_form(connecting: bool):
	if not (is_instance_valid(screen) and screen.scene_file_path=="res://scenes/ui/home.tscn"):_home()
	screen.open_join(join_draft.address,join_draft.password)
	screen.show_connecting(connecting)

func _on_board_picked(kind: String,id: int):
	# Moving a ship takes two picks: the ship, then its new edge.
	if kind=="move_ship":
		board.move_from=id
		mode="move_to"
		board.set_mode(mode,net.seat)
		_hud()
		return
	if kind=="move_to":
		net.act({"type":"move_ship","id":board.move_from,"to":id})
		return
	net.act({"type":kind,"id":id})

func _network_changed():
	if server_only or not is_node_ready(): return
	if joining and not net.roster.is_empty():joining=false
	if joining:
		# Failures arrive as a notice right after the connection closes.
		_show_join_form(net.online)
	elif not net.online:
		_home()
	elif not net.started:
		_lobby()
	elif not state.is_empty():
		_hud()

func _lobby():
	_clear("res://scenes/ui/lobby.tscn")
	board.camera.h_offset=0
	screen.show_room(net,invite_address,connection_status)
	_route(screen,{
		"add_bot_requested":net.configure_bot.bind("add"),
		"ready_requested":net.ready_up,
		"start_requested":net.start_game,
		"leave_requested":net.leave,
		"settings_requested":_open_settings,
		"cosmetics_requested":_open_cosmetics,
		"music_requested":_open_music,
		"map_router_requested":net.map_router,
		"invite_requested":_copy_invite,
		"bot_difficulty_changed":func(seat,level):net.configure_bot("difficulty",seat,level),
		"bot_remove_requested":_remove_seat,
		"setting_changed":net.choose_setting,
		"resume_requested":net.resume_saved,
		"new_game_requested":net.cancel_resume,
	})
	screen.invite_address_edited.connect(func(text):invite_address=text)
	_apply_text(screen)

func _remove_seat(seat: int):
	if seat<0 or seat>=net.roster.size():return
	if net.roster[seat].get("bot",false):net.configure_bot("remove",seat)
	else:net.remove_player(seat)

func _copy_invite(address: String):
	if address.is_empty(): _rejected(tr("Enter your public address first, or use Map router."))
	else:
		var code=net.invite(address)
		if code.is_empty():_rejected(tr("Enter a valid public address and optional UDP port."))
		else:DisplayServer.clipboard_set(code);_notice(tr("Invite copied. Share it with your guests."))

func _received(data: Dictionary):
	CatanDiagnostics.event("state.received","turn=%s phase=%s"%[data.get("turn",-1),data.get("phase","")])
	if server_only or not is_node_ready(): return
	var previous=state
	var previous_trade=state.get("trade_event",{})
	var previous_offer=state.get("offer",{})
	var trading=is_instance_valid(modal) and modal.name=="TradeDialog"
	# A rematch sends a new board to a client that still holds the old one.
	var fresh=state.is_empty() or state.get("game_id",0)!=data.get("game_id",0)
	var new_turn=fresh or state.get("turn",-1)!=data.turn or state.get("setup",-1)!=data.get("setup",-1) or state.get("paired",false)!=data.get("paired",false)
	var produced=not fresh and data.rolled and (not state.rolled or state.dice!=data.dice)
	audio.transition({} if fresh else state,data,net.seat)
	state=data
	_merge_log(data)
	board.camera.h_offset=0
	board.camera.v_offset=1.8 if guide!=null else 0.0
	if guide!=null: board.camera.fov=42
	board.show_labels=not inspection_mode
	if fresh:
		board.build(state)
		menu_island=false
	else: board.refresh(state)
	turn_clock_limit=float(state.get("turn_limit",0.0))
	turn_clock_left=float(state.get("turn_seconds",0.0))
	board.day_seconds=state.get("world_seconds",board.day_seconds)
	board.day_count=int(state.get("world_days",board.day_count))
	board.advance_day(0)
	if produced: board.throw_dice(state.dice)
	mode=_kept_mode(previous,fresh)
	if state.turn==net.seat:
		if state.phase=="setup_settlement": mode="settlement"
		if state.phase=="setup_road": mode="road"
		if state.phase=="free_roads": mode="route" if state.get("island","")=="archipelago" else "road"
		if state.phase=="robber": mode="robber"
	if guide!=null and guide.completed: mode=""
	board.set_mode("" if inspection_mode else mode,-1 if inspection_mode else net.seat)
	_hud()
	_trade_notifications(previous_trade,previous_offer,fresh)
	_theft_notification(previous,fresh)
	_follow_card_dialogs(previous,fresh)
	if new_turn and state.turn==net.seat and state.winner==-1:_show_turn_banner()
	elif state.turn!=net.seat or state.winner!=-1:
		turn_banner.hide()
	if trading and state.phase=="play" and state.turn==net.seat and state.winner==-1:
		if not state.offer.is_empty() and state.offer.from==net.seat:_view_offer()
		else:_trade(false)
	elif is_instance_valid(modal) and modal.name=="TradeOffer":
		if state.offer.is_empty() or state.winner!=-1:_close_modal()
		else:modal.show_offer(state,net.seat,net)

## A build or ship move the player has picked stays picked through snapshots
## about something else, such as an answer to their trade offer. It ends when
## the player acts: a build pays resources and a move changes the board.
func _kept_mode(previous: Dictionary,fresh: bool) -> String:
	if fresh or mode.is_empty() or state.turn!=net.seat or state.phase!="play" or not state.rolled or state.winner!=-1:return ""
	if previous.get("turn",-1)!=state.turn or previous.get("paired",false)!=state.get("paired",false):return ""
	if previous.players[net.seat].hand!=state.players[net.seat].hand or previous.edges!=state.edges or previous.vertices!=state.vertices:return ""
	var rules=CatanRules.new();rules.s=state
	match mode:
		"move_ship":return mode if not rules.movable_ships(net.seat).is_empty() else ""
		"move_to":return mode if board.move_from in rules.movable_ships(net.seat) else ""
		"road","ship","settlement","city":return mode if rules.can_pay(net.seat,CatanRules.COST[mode]) and not rules.build_sites(net.seat,mode).is_empty() else ""
	return ""

## The discard dialog opens when a seven asks this player to discard, stays
## open while others discard, and closes once it's done. The Year of plenty and
## Monopoly picker closes when the card can no longer be played.
func _follow_card_dialogs(previous: Dictionary,fresh: bool):
	var must_discard=state.phase=="discard" and state.discards.has(str(net.seat)) and state.winner==-1
	var had_to=not fresh and previous.get("phase","")=="discard" and previous.get("discards",{}).has(str(net.seat))
	var open=modal.name if is_instance_valid(modal) else ""
	if open=="Discard" and not must_discard:_close_modal()
	elif must_discard and not had_to and open in ["","TradeOffer"]:_discard()
	if open=="ResourceCard" and (state.turn!=net.seat or state.phase!="play" or state.card_played or state.winner!=-1):_close_modal()

## Only the thief and the victim learn what was taken.
func _theft_notification(previous: Dictionary,fresh: bool):
	var theft: Dictionary=state.get("theft",{})
	if fresh or theft.is_empty() or not theft.has("resource") or int(theft.id)==int(previous.get("theft",{}).get("id",0)):return
	var taken=tr(CatanRules.RES[int(theft.resource)])
	if int(theft.victim)==net.seat:
		notifications.show_notice("theft",tr("%s stole 1 %s from you.") % [state.players[int(theft.thief)].name,taken],"",Callable())
	elif int(theft.thief)==net.seat:
		notifications.show_notice("theft",tr("You stole 1 %s from %s.") % [taken,state.players[int(theft.victim)].name],"",Callable())

func _merge_log(data: Dictionary):
	var start=int(data.get("log_start",0))
	var tail: Array=data.get("log",[])
	if start<=game_log.size():
		game_log=game_log.slice(0,start)+tail
	else:
		# Joined or reconnected mid-game: keep the tail until the full log arrives.
		game_log=tail.duplicate()
		if not log_pending:
			log_pending=true
			net.request_log()

func _log_received(entries: Array):
	log_pending=false
	game_log=entries.duplicate()
	if is_instance_valid(modal) and modal.name=="GameLog":modal.show_log(game_log,net.seat,state)

func _process(delta):
	# Menus and dialogs keep the scroll wheel and drags to themselves.
	board.accepts_input=not state.is_empty() and not is_instance_valid(modal)
	var soundtrack=net.music_state()
	audio.follow_soundtrack(soundtrack,delta)
	if is_instance_valid(board.weather):audio.follow_weather(board.weather.current,delta)
	music_ui_clock-=delta
	if music_ui_clock<=0:
		music_ui_clock=.15
		_refresh_music_library(soundtrack)
	var live=net.started and not net.paused and not net.waiting_for_player()
	if live:board.advance_day(delta)
	ui_day_night.advance(board.daylight,delta)
	if live and turn_clock_limit>0.0:
		turn_clock_left=maxf(0.0,turn_clock_left-delta)
		_refresh_turn_clock()

func _hud():
	_clear("res://scenes/ui/hud.tscn")
	screen.visible=not inspection_mode
	screen.show_game(net,state,mode)
	_route(screen,{
		"action_requested":net.act,
		"build_requested":_choose,
		"trade_requested":_trade,
		"discard_requested":_discard,
		"offer_requested":_view_offer,
		"resource_card_requested":_resource_card,
		"inspect_requested":_toggle_inspection,
		"log_requested":_journal,
		"guide_requested":_help,
		"music_requested":_open_music,
		"settings_requested":_open_settings,
		"leave_requested":_confirm_leave,
	})
	_refresh_turn_clock()
	_apply_text(screen)
	if is_instance_valid(modal) and modal.name=="GameLog":modal.show_log(game_log,net.seat,state)
	if is_instance_valid(modal) and modal.name=="Victory" and state.winner==-1:_close_modal()
	if state.winner!=-1 and not (is_instance_valid(modal) and modal.name in ["Victory","GameLog"]):
		_show_victory()
	if guide!=null:_tutorial_ui()
	_show_away()
	_queue_layout()

## One toast when someone leaves, and one when a bot takes their seat.
func _show_away():
	var away=[]
	var covered=[]
	for row_player in net.roster:
		if row_player.connected:continue
		if row_player.get("stand_in",false):covered.append(row_player.name)
		else:away.append(row_player.name)
	var shown=",".join(away)+"|"+",".join(covered)
	if shown==away_shown:return
	away_shown=shown
	for player_name in away:_notice(tr("%s disconnected. Waiting to reconnect.") % player_name)
	if not covered.is_empty():_notice(tr("A bot plays for %s until they return.") % ", ".join(covered))

func _set_music_volume(value: float):
	preferences.set_value("music",value)
	audio.apply(preferences.values)

func _toggle_music_mute():
	if preferences.values.music>0:
		music_volume_before_mute=preferences.values.music;_set_music_volume(0)
	else:_set_music_volume(maxf(.1,music_volume_before_mute))

func _open_music():
	var dialog=_present("res://scenes/ui/music_dialog.tscn")
	_route(dialog,{"control_requested":net.music_control,"volume_changed":_set_music_volume,"mute_toggled":_toggle_music_mute})
	_refresh_music_library(net.music_state())

func _refresh_music_library(sample: Dictionary):
	if is_instance_valid(modal) and modal.name=="MusicLibrary":
		modal.refresh(sample,net.can_control_music(),net.online and not net.solo,preferences.values.music)

func _journal():
	var dialog=_present("res://scenes/ui/game_log_dialog.tscn")
	dialog.show_log(game_log,net.seat,state)
	if state.get("winner",-1)!=-1:dialog.close_requested.connect(_show_victory,CONNECT_DEFERRED)

func _show_victory():
	if state.get("winner",-1)==-1:return
	var victory=_present("res://scenes/ui/victory_dialog.tscn")
	victory.show_results(state,net)
	_route(victory,{"leave_requested":net.leave,"rematch_requested":net.rematch,"log_requested":_journal})

func _choose(kind: String):
	var rules=CatanRules.new();rules.s=state
	if kind=="move_ship":
		mode="" if mode in ["move_ship","move_to"] else kind
		board.set_mode(mode,net.seat)
		_hud()
		return
	if state.phase=="play" and rules.build_sites(net.seat,kind).is_empty():
		_rejected(tr(CatanRules.NO_SPACE[kind]))
		return
	mode=kind
	board.set_mode(mode,net.seat)
	_hud()

func _notice(message: String):
	print(message)
	if server_only or not is_node_ready(): return
	if joining and not net.online:
		audio.play("error")
		_join_failed(message)
		return
	if message.begins_with("Router") or message.begins_with("Automatic mapping"):
		if "Invite address: " in message: invite_address=message.get_slice("Invite address: ",1)
		connection_status=message
		if net.online and not net.started: _lobby()
	toast.text=CatanI18n.render(message)
	toast.show()
	toast_generation+=1
	var generation=toast_generation
	get_tree().create_timer(5).timeout.connect(func():
		if is_instance_valid(toast) and toast_generation==generation: toast.hide())

## A refused action or a failed connection: the notice plus the error sound.
func _rejected(message: String):
	if not server_only and is_node_ready() and not (joining and not net.online):audio.play("error")
	_notice(message)

# Modals are scenes with a close_requested signal; one is shown at a time.
func _present(scene_path: String) -> Control:
	if is_instance_valid(modal): modal.free()
	modal=load(scene_path).instantiate()
	modals.add_child(modal)
	modal.close_requested.connect(_close_modal,CONNECT_DEFERRED)
	_apply_text(modal)
	return modal

func _close_modal():
	net.paused=net.solo and inspection_mode
	if is_instance_valid(modal): modal.free()

func _trade(reset: bool=true):
	if reset:trade_draft={}
	var dialog=_present("res://scenes/ui/trade_dialog.tscn")
	dialog.draft_changed.connect(func(draft):trade_draft=draft)
	dialog.show_trade(state,net.seat,trade_draft)
	_route(dialog,{"trade_requested":net.act})

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
	if not offer.is_empty() and (fresh or offer.get("id",0)!=previous_offer.get("id",0)):
		var sender=int(offer.from)
		var offer_message=tr("%s offers %s for %s.") % [state.players[sender].name,_resource_text(offer.give),_resource_text(offer.receive)]
		if sender==net.seat:offer_message=tr("Your trade offer: %s for %s.") % [_resource_text(offer.give),_resource_text(offer.receive)]
		else:
			var rules=CatanRules.new();rules.s=state
			if not rules.can_pay(net.seat,offer.receive):offer_message+=tr(" You don't have the requested resources.")
		notifications.show_notice("trade",offer_message,tr("View offer"),_view_offer)
	if fresh or not changed:return
	var actor=int(event.actor)
	var message=""
	match event.kind:
		"accepted":
			if actor==net.seat:message=tr("%s accepted your trade.") % state.players[event.other].name
			elif event.other==net.seat:message=tr("Trade completed with %s.") % state.players[actor].name
			else:message=tr("%s traded with %s.") % [state.players[actor].name,state.players[event.other].name]
		"withdrawn":message=tr("Trade offer withdrawn.") if actor==net.seat else tr("%s withdrew their trade offer.") % state.players[actor].name
		"responded":
			# Tell the offering player who answered, unless the offer is already open in front of them.
			var answer=str(offer.get("responses",{}).get(str(actor),{}).get("answer",""))
			if event.other==net.seat and not (is_instance_valid(modal) and modal.name=="TradeOffer"):
				var responded={"accept":tr("%s accepted your offer."),"counter":tr("%s made a counter-offer."),"decline":tr("%s declined your offer.")}.get(answer,"")
				if not responded.is_empty():notifications.show_notice("trade",responded % state.players[actor].name,tr("View offer"),_view_offer)
		"bank":
			if actor==net.seat:message=tr("Bank trade completed.")
	if not message.is_empty():notifications.show_notice("trade_result",message,"",Callable())

func _view_offer():
	if state.get("offer",{}).is_empty():return
	# The offer is in front of the player now, so its notification goes.
	notifications.dismiss("trade")
	var dialog=_present("res://scenes/ui/offer_dialog.tscn")
	dialog.show_offer(state,net.seat,net)
	_route(dialog,{"response_requested":net.act,"withdraw_requested":func():net.act({"type":"cancel_trade"})})

func _discard():
	var dialog=_present("res://scenes/ui/discard_dialog.tscn")
	dialog.show_discard(state.discards[str(net.seat)],state.players[net.seat].hand)
	_route(dialog,{"discard_requested":func(cards):net.act({"type":"discard","cards":cards})})

func _resource_card(id: int):
	var dialog=_present("res://scenes/ui/resource_card_dialog.tscn")
	dialog.show_card(id,state.bank)
	_route(dialog,{"play_requested":net.act})

func _confirm_leave():
	var dialog=_present("res://scenes/ui/leave_dialog.tscn")
	dialog.show_leave(net,state.get("winner",-1)!=-1)
	_route(dialog,{"leave_requested":net.leave})

func _help():
	_present("res://scenes/ui/guide_dialog.tscn")

func _node(node_name: String) -> Node:
	return screen.find_child(node_name,true,false)

func _solo():
	var pname=preferences.values.player_name
	if is_instance_valid(name_field): pname=name_field.text.strip_edges()
	if pname.is_empty(): pname="Voyager"
	preferences.set_value("player_name",pname)
	net.host_solo(pname)
	net.configure_bot("add",-1,1)
	net.configure_bot("add",-1,1)

func _apply_preferences():
	CatanDiagnostics.event("settings.apply","quality=%s day_night=%s"%[preferences.values.quality,preferences.values.day_night_cycle])
	var language_changed=active_language!=preferences.values.language
	active_language=preferences.values.language
	CatanI18n.apply(active_language)
	if language_changed:call_deferred("_refresh_language")
	preferences.apply_display(get_viewport())
	board.apply_preferences(preferences.values)
	audio.apply(preferences.values)
	net.bot_delay=[1.25,0.7,0.2][preferences.values.bot_speed]
	net.my_look=preferences.look()
	net.my_color=preferences.values.player_color
	if net.online and net.seat>=0 and net.seat<net.roster.size() and net.roster[net.seat].get("look",PackedByteArray())!=net.my_look:
		net.choose_look(net.my_look)
	if net.online and net.seat>=0 and net.seat<net.roster.size() and str(net.roster[net.seat].get("color",""))!=net.my_color:
		net.choose_color(net.my_color)
	_apply_text(ui)

func _open_settings():
	var settings=_present("res://scenes/ui/settings.tscn")
	net.paused=net.solo
	settings.setup(preferences)
	settings.preferences_changed.connect(_apply_preferences)
	_route(settings,{})

func _open_cosmetics():
	_present("res://scenes/ui/cosmetics.tscn").setup(preferences,net)
	net.paused=net.solo

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
	tutorial_layer.add_child(tutorial_panel)
	tutorial_panel.show_lesson(guide)
	# The lesson rewraps when its width changes; the island is framed below it.
	tutorial_panel.find_child("LessonPanel",true,false).minimum_size_changed.connect(_queue_layout)
	_route(tutorial_panel,{"step_requested":_tutorial_step,"restart_requested":func():guide.load_lesson(net,preferences.values.player_name)})

func _tutorial_step(direction: int):
	if guide.step+direction>=CatanTutorial.LESSONS.size():
		_solo()
		return
	guide.step=clampi(guide.step+direction,0,CatanTutorial.LESSONS.size()-1)
	guide.load_lesson(net,preferences.values.player_name)

# Larger small text: labels keep their authored size but never render below 16 px (14 px by default).
# A label that sizes its own text to fit, like a card title, is left alone.
func _apply_text(root: Node):
	for label in root.find_children("*","Label",true,false):
		if label.has_meta("fits_text"):continue
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
	if not is_instance_valid(screen):return
	var width=ui.size.x
	var height=ui.size.y
	toast.offset_left=-minf(470,width*.5-20)
	toast.offset_right=minf(470,width*.5-20)
	var overlay_bottom=0.0
	if guide!=null and is_instance_valid(tutorial_panel):
		var lesson: Control=tutorial_panel.find_child("LessonPanel",true,false)
		var area=screen.overlay_area(ui.size)
		lesson.offset_left=area.position.x
		lesson.offset_right=area.end.x-width
		# No height of its own: the lesson grows down to fit its text at this width.
		lesson.offset_top=area.position.y
		lesson.offset_bottom=area.position.y
		overlay_bottom=lesson.get_global_rect().end.y
	board.view_region=screen.arrange(ui.size,overlay_bottom)
	notifications.offset_left=-minf(420,width-32)
	notifications.offset_right=-16
	notifications.offset_top=screen.notifications_top
	toast.offset_bottom=-screen.toast_bottom
	toast.offset_top=-screen.toast_bottom-42
	if inspection_mode:board.view_region=Rect2(16,16,width-32,height-64)
	board._update_camera()

func _exit_tree():
	CatanIcons.textures.clear()

func _notification(what: int):
	if what==NOTIFICATION_WM_CLOSE_REQUEST:_exit_desktop()

func _exit_desktop():
	CatanDiagnostics.event("shutdown.requested")
	if quitting:return
	quitting=true
	set_process(false)
	net.leave()
	# Let play commands from this input frame reach the mixer before stopping them.
	await get_tree().create_timer(.06).timeout
	audio.shutdown()
	# Let the audio mixer release queued playback references before engine teardown.
	await get_tree().create_timer(.15).timeout
	get_tree().quit()

func _open_updates():
	var dialog=_present("res://scenes/ui/updates_dialog.tscn")
	net.paused=net.solo
	_route(dialog,{"check_requested":updater.check_updates,"download_requested":updater.download_update,"install_requested":_install_update})
	_updates_changed()

func _updates_changed():
	if not is_node_ready():return
	var data=updater.status
	var stage=data.get("state","idle")
	var release_version=str(data.get("version",""))
	if stage in ["available","ready"] and not release_version.is_empty():
		var notification_key=stage+":"+release_version
		if not notified_updates.has(notification_key):
			notified_updates[notification_key]=true
			var message=tr("Update %s is available.") % release_version if stage=="available" else tr("Update %s is ready to install.") % release_version
			notifications.show_notice("update",message,tr("View update"),_open_updates)

	if is_instance_valid(screen) and screen.has_method("show_update_stage"):screen.show_update_stage(stage)
	if is_instance_valid(modal) and modal.name=="Updates":modal.show_status(data,updater.supported,updater.busy(),net.online)

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

func _refresh_turn_clock():
	if is_instance_valid(screen) and screen.has_method("show_turn_clock"):
		screen.show_turn_clock(turn_clock_left,turn_clock_limit,state.get("winner",-1)!=-1)

func _show_turn_banner():
	turn_banner.text=tr("Your turn")
	turn_banner.add_theme_color_override("font_color",board.player_color(net.seat))
	turn_banner.show()
	turn_banner_timer.start()

func _refresh_language():
	if server_only:return
	if net.started and not state.is_empty():_hud()
	elif joining:_show_join_form(net.online)
	elif net.online:_lobby()
	else:_home()
	if is_instance_valid(modal) and modal.name=="Settings":
		modal.refresh()
	turn_banner.text=tr("Your turn")
	if guide!=null:_tutorial_ui()
