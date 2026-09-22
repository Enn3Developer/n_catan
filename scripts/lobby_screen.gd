extends CatanScreen
## Room lobby: seats and bots, readiness, and the invite tools for online hosts.

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

const PLAYER_SLOT=preload("res://scenes/ui/player_slot.tscn")

func show_room(net: CatanNetwork,invite_address: String,connection_status: String):
	%LobbyTitle.text=tr("Solo game") if net.solo else tr("Online room")
	%PlayerCount.text="%d / 6" % net.roster.size()
	%RoomType.text="SOLO" if net.solo else "ONLINE"
	var controller=net.is_controller()
	%RoomSummary.text=tr("30 hexes · Paired turns") if net.roster.size()>4 else tr("19 hexes · Classic")
	if not net.solo:%RoomSummary.text+="\n"+(tr("Password required to join") if not net.room_password.is_empty() else tr("Open room · no password"))
	for i in CatanNetwork.MAX_PLAYERS:
		var slot=PLAYER_SLOT.instantiate()
		%PlayerSlots.add_child(slot)
		slot.show_seat(net,i,controller)
		slot.difficulty_selected.connect(bot_difficulty_changed.emit)
		slot.remove_requested.connect(bot_remove_requested.emit)
	%AddBot.disabled=not controller or net.roster.size()>=CatanNetwork.MAX_PLAYERS
	%ReadyButton.text=tr("Not ready") if net.seat>=0 and net.roster[net.seat].ready else tr("I'm ready")
	%ReadyButton.disabled=net.seat<0
	var all_ready=net.roster.size()>=CatanNetwork.MIN_PLAYERS and net.roster.size()<=CatanNetwork.MAX_PLAYERS
	for row in net.roster:
		if not row.ready: all_ready=false
	%StartGame.disabled=not controller or not all_ready
	%LobbyStatus.text=tr("Ready to play") if all_ready else tr("Add %d more player(s)") % (CatanNetwork.MIN_PLAYERS-net.roster.size()) if net.roster.size()<CatanNetwork.MIN_PLAYERS else tr("Waiting for players")
	var hosting=net.multiplayer.is_server()
	%InviteAddress.text=invite_address if hosting else net.reconnect_address
	%InviteAddress.editable=hosting
	for node: Control in [%InviteHeading,%InviteAddress,%InviteActions]:node.visible=not net.solo
	%MapRouter.disabled=not hosting
	%ConnectionHelp.text=tr("Choose each bot’s difficulty.") if net.solo else tr("Share the invite code. Host: open UDP 24567.")
	if not connection_status.is_empty() and not net.solo:%ConnectionHelp.text=CatanI18n.render(connection_status)

func arrange(viewport: Vector2,_overlay_bottom: float) -> Rect2:
	%Voyage.custom_minimum_size.x=280 if viewport.x<1100 else 340
	return Rect2(Vector2.ZERO,viewport)

func _on_invite_address_text_changed(address: String):
	invite_address_edited.emit(address)

func _on_copy_invite_pressed():
	invite_requested.emit(%InviteAddress.text.strip_edges())
