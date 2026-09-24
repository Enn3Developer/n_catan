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

const PLAYER_SLOT=preload("res://scenes/ui/player_slot.tscn")
var shown_seed=0

func show_room(net: CatanNetwork,invite_address: String,connection_status: String):
	%LobbyTitle.text=tr("Solo game") if net.solo else tr("Online room")
	%PlayerCount.text="%d / 6" % net.roster.size()
	var controller=net.is_controller()
	%RoomSummary.text=tr("30 hexes · Paired turns") if net.roster.size()>4 else tr("19 hexes · Classic")
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
	for row in net.roster:
		if not row.ready: all_ready=false
	%StartGame.disabled=not controller or not all_ready
	%LobbyStatus.text="" if all_ready else tr("Add %d more player(s)") % (CatanNetwork.MIN_PLAYERS-net.roster.size()) if net.roster.size()<CatanNetwork.MIN_PLAYERS else tr("Waiting for players")
	var hosting=net.multiplayer.is_server()
	%InviteAddress.text=invite_address if hosting else net.reconnect_address
	%InviteAddress.editable=hosting
	for node: Control in [%InviteHeading,%InviteAddress,%InviteActions]:node.visible=not net.solo
	%MapRouter.disabled=not hosting
	%ConnectionHelp.visible=not net.solo
	%ConnectionHelp.text=tr("Share the invite code. Host: open UDP 24567.")
	if not connection_status.is_empty() and not net.solo:%ConnectionHelp.text=CatanI18n.render(connection_status)
	_show_rules(net.room_settings,controller,net.solo)

func _show_rules(settings: Dictionary,controller: bool,solo: bool):
	shown_seed=int(settings.seed)
	%SeedField.text=str(shown_seed)
	%SeedField.editable=controller
	%NewSeed.disabled=not controller
	%IslandPicker.clear()
	%IslandPicker.add_item(tr("Random coastline"))
	%IslandPicker.add_item(tr("Classic hexagon"))
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
	for control: Control in [%IslandPicker,%TimerPicker,%PointsPicker,%FriendlyRobber]:control.set("disabled",not controller)

func arrange(viewport: Vector2,_overlay_bottom: float) -> Rect2:
	%Voyage.custom_minimum_size.x=320 if viewport.x<1100 else 380
	return Rect2(Vector2.ZERO,viewport)

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
