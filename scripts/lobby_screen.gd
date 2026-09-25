extends CatanScreen
## Room lobby: seats and bots, readiness, the room rules and the invite tools
## for online hosts. Only the room controller can change the rules.

signal add_bot_requested
signal ready_requested
signal start_requested
signal leave_requested
signal settings_requested
signal cosmetics_requested
signal music_requested
signal map_router_requested
signal invite_requested(address: String)
signal invite_address_edited(address: String)
signal bot_difficulty_changed(seat: int,level: int)
signal bot_remove_requested(seat: int)
signal setting_changed(key: String,value: Variant)
signal resume_requested
signal new_game_requested

const PLAYER_SLOT=preload("res://scenes/ui/player_slot.tscn")
var shown_seed=0

func show_room(net: CatanNetwork,invite_address: String,connection_status: String):
	%LobbyTitle.text=tr("Solo game") if net.solo else tr("Online room")
	%PlayerCount.text="%d / 6" % net.roster.size()
	var controller=net.is_controller()
	var extended=net.roster.size()>4
	var hexes=(30 if extended else 19)+((5 if extended else 4) if net.room_settings.island=="archipelago" else 0)+(1 if net.room_settings.get("treasure",false) else 0)
	%RoomSummary.text=(tr("%d hexes · Paired turns") if extended else tr("%d hexes · Classic")) % hexes
	%RoomAccess.visible=not net.solo
	%RoomAccess.text=tr("Password required to join") if not net.room_password.is_empty() else tr("Open room · no password")
	for i in CatanNetwork.MAX_PLAYERS:
		var slot=PLAYER_SLOT.instantiate()
		%PlayerSlots.add_child(slot)
		slot.show_seat(net,i,controller)
		slot.difficulty_selected.connect(bot_difficulty_changed.emit)
		slot.remove_requested.connect(bot_remove_requested.emit)
	%AddBot.disabled=not controller or net.roster.size()>=CatanNetwork.MAX_PLAYERS
	%ReadyButton.text=tr("Not ready") if net.seat>=0 and net.roster[net.seat].ready else tr("I'm ready")
	%ReadyButton.disabled=net.seat<0
	# Solo players are always ready; the only choice left is to start.
	%ReadyButton.visible=not net.solo
	var all_ready=net.roster.size()>=CatanNetwork.MIN_PLAYERS and net.roster.size()<=CatanNetwork.MAX_PLAYERS
	# Saved seats nobody has come back for start with a bot in them.
	for row in net.roster:
		if not row.ready and not CatanNetwork._waiting_seat(row): all_ready=false
	%StartGame.disabled=not controller or not all_ready
	%LobbyStatus.text="" if all_ready else tr("Add %d more player(s)") % (CatanNetwork.MIN_PLAYERS-net.roster.size()) if net.roster.size()<CatanNetwork.MIN_PLAYERS else tr("Waiting for players")
	var hosting=net.multiplayer.is_server()
	%InviteAddress.text=invite_address if hosting else net.reconnect_address
	%InviteAddress.editable=hosting
	for node: Control in [%InviteGap,%InviteHeading,%InviteAddress,%InviteActions]:node.visible=not net.solo
	%MapRouter.disabled=not hosting
	%ConnectionHelp.visible=not net.solo
	%ConnectionHelp.text=tr("Share the invite code. Host: open UDP 24567.")
	if not connection_status.is_empty() and not net.solo:%ConnectionHelp.text=CatanI18n.render(connection_status)
	_show_rules(net.room_settings,controller,net.solo)
	_show_saved(net,controller)

func _show_rules(settings: Dictionary,controller: bool,solo: bool):
	shown_seed=int(settings.seed)
	%SeedField.text=str(shown_seed)
	%SeedField.editable=controller
	%NewSeed.disabled=not controller
	%IslandPicker.clear()
	%IslandPicker.add_item(tr("Random coastline"))
	%IslandPicker.add_item(tr("Classic hexagon"))
	%IslandPicker.add_item(tr("Archipelago"))
	%IslandPicker.set_item_tooltip(2,tr("A main island and smaller ones across the sea. Build ships to reach them; the first settlement on each new island is worth 2 extra points."))
	%IslandPicker.select(CatanRules.ISLANDS.find(settings.island))
	%TimerPicker.clear()
	for seconds in CatanRules.TURN_TIMERS:%TimerPicker.add_item(tr("Off") if seconds==0 else tr("%d s") % seconds if seconds<60 else tr("%d min") % (seconds/60) if seconds%60==0 else tr("%d:%02d min") % [seconds/60,seconds%60])
	%TimerPicker.select(maxi(0,CatanRules.TURN_TIMERS.find(int(settings.turn_seconds))))
	# Solo games and lessons have no turn clock.
	%TimerLabel.visible=not solo
	%TimerPicker.visible=not solo
	%PointsPicker.clear()
	for points in range(CatanRules.POINT_TARGETS[0],CatanRules.POINT_TARGETS[1]+1):%PointsPicker.add_item(str(points))
	%PointsPicker.select(int(settings.points)-CatanRules.POINT_TARGETS[0])
	%FriendlyRobber.set_pressed_no_signal(bool(settings.friendly_robber))
	var switches: Array[Control]=[%FriendlyRobber]
	for rule in CatanRules.HOUSE_RULES:
		if rule=="friendly_robber":continue
		var toggle: CheckButton=_house_rule(rule)
		toggle.set_pressed_no_signal(bool(settings.get(rule,false)))
		# Sea rules only show for the archipelago, where there are ships to move and islands to hide.
		var shown=rule not in CatanRules.SEA_RULES or settings.island=="archipelago"
		toggle.visible=shown
		%RulesGrid.get_node(toggle.name+"Label").visible=shown
		switches.append(toggle)
	# A resumed game plays by the rules it was saved with.
	var locked=not controller or bool(settings.get("resuming",false))
	for control: Control in [%IslandPicker,%TimerPicker,%PointsPicker]+switches:control.set("disabled",locked)
	%SeedField.editable=not locked
	%NewSeed.disabled=locked

## The saved game: an offer to resume it, or while resuming, which seats are
## still waiting for their players.
func _show_saved(net: CatanNetwork,controller: bool):
	var resumed=bool(net.room_settings.get("resuming",false))
	var summary=net.saved_summary() if controller else {}
	%SavedGame.visible=resumed or not summary.is_empty()
	%ResumeGame.visible=not resumed and not summary.get("outdated",false)
	%NewGameInstead.visible=resumed and controller
	if resumed:
		var waiting=[]
		for row in net.roster:
			if row.get("saved_seat",false) and not row.connected:waiting.append(row.name)
		%SavedInfo.text=tr("Resuming a saved game. Friends rejoin with the invite and take their seats back.") if waiting.is_empty() else tr("Resuming a saved game. Waiting for %s to rejoin with the invite. If you start now, a bot plays for them until they join.") % ", ".join(waiting)
		for control: Control in [%AddBot]:control.set("disabled",true)
		return
	if summary.is_empty():return
	if summary.get("outdated",false):
		%SavedInfo.text=tr("The saved game is from version %s, which plays by different rules. It can't be resumed here, and starting a new game replaces it.") % summary.version
		return
	var when=Time.get_datetime_dict_from_unix_time(int(summary.saved)+int(Time.get_time_zone_from_system().bias)*60)
	%SavedInfo.text=tr("%s · turn %d · saved %04d-%02d-%02d %02d:%02d. Starting a new game replaces it.") % [", ".join(summary.names),summary.turn,when.year,when.month,when.day,when.hour,when.minute]

## A labelled switch for one house rule, made once and kept in the rules grid.
func _house_rule(rule: String) -> CheckButton:
	var node_name=rule.to_pascal_case()
	var existing=%RulesGrid.get_node_or_null(node_name)
	if existing:return existing
	var text: Array=CatanRules.HOUSE_RULE_TEXT[rule]
	var label=Label.new()
	label.name=node_name+"Label"
	label.text=text[0]
	label.tooltip_text=text[1]
	label.mouse_filter=Control.MOUSE_FILTER_PASS
	label.add_theme_font_size_override("font_size",15)
	%RulesGrid.add_child(label)
	var toggle=CheckButton.new()
	toggle.name=node_name
	toggle.custom_minimum_size=Vector2(0,40)
	toggle.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	toggle.tooltip_text=text[1]
	toggle.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	toggle.add_to_group("ui_click")
	toggle.toggled.connect(func(enabled):setting_changed.emit(rule,enabled))
	%RulesGrid.add_child(toggle)
	return toggle

func arrange(viewport: Vector2,_overlay_bottom: float) -> Rect2:
	%Voyage.custom_minimum_size.x=320 if viewport.x<1100 else 380
	# The room is a centred block no wider than it needs, and each list is as
	# tall as its content until the window runs out of room; then it scrolls.
	var side=maxf(24,(viewport.x-1080)/2)
	%Frame.offset_left=side
	%Frame.offset_right=-side
	var room=viewport.y-48-%Header.get_combined_minimum_size().y-16
	var crew_chrome=%Crew.get_combined_minimum_size().y-%CrewScroll.get_combined_minimum_size().y
	%CrewScroll.custom_minimum_size.y=minf(%PlayerSlots.get_combined_minimum_size().y,room-crew_chrome)
	var voyage_chrome=%Voyage.get_combined_minimum_size().y-%VoyageScroll.get_combined_minimum_size().y
	%VoyageScroll.custom_minimum_size.y=minf(%VoyageContent.get_combined_minimum_size().y,room-voyage_chrome)
	# The panels cover the board, so frame the island off screen; otherwise a
	# sliver of it shows through the gap between the columns.
	return Rect2(Vector2(-2*viewport.x,0),viewport)

func _on_invite_address_text_changed(address: String):
	invite_address_edited.emit(address)

func _on_copy_invite_pressed():
	invite_requested.emit(%InviteAddress.text.strip_edges())

func _submit_seed():
	var text: String=%SeedField.text.strip_edges()
	if text.is_valid_int() and int(text)>=1 and int(text)<=999999999:
		if int(text)!=shown_seed:setting_changed.emit("seed",int(text))
	else:%SeedField.text=str(shown_seed)

func _on_seed_submitted(_text: String):
	_submit_seed()

func _on_seed_focus_exited():
	_submit_seed()

func _on_new_seed_pressed():
	setting_changed.emit("seed",CatanNetwork._random_seed())

func _on_island_selected(index: int):
	setting_changed.emit("island",CatanRules.ISLANDS[index])

func _on_timer_selected(index: int):
	setting_changed.emit("turn_seconds",CatanRules.TURN_TIMERS[index])

func _on_points_selected(index: int):
	setting_changed.emit("points",CatanRules.POINT_TARGETS[0]+index)

func _on_friendly_robber_toggled(enabled: bool):
	setting_changed.emit("friendly_robber",enabled)
