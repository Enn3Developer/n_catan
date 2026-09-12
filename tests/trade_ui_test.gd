extends SceneTree
var game
var checks=0
var failures=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func shot(title: String):
	for i in 8:await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/catan-trade-"+title+".png")
func button(text: String) -> Button:
	for b in game.modal.find_children("*","Button",true,false):
		if b.text==text or b.text.begins_with(text+" ·"):return b
	return null
func run():
	game=load("res://scenes/main.tscn").instantiate()
	game.preferences=CatanSettings.new("user://trade-ui-test.cfg")
	game.preferences.values=CatanSettings.DEFAULTS.duplicate()
	root.add_child(game);await create_timer(.5).timeout
	game._solo();game.net.start_game();game.net.paused=true
	var r=game.net.rules
	r.s.phase="play";r.s.rolled=true;r.s.turn=0
	r.s.players[0].hand=[4,0,0,0,0];game.net._sync();game._trade()
	check(game.selected_give.get_item_icon(0)!=null,"trade selectors show resource icons")
	check(button("Players").button_pressed and button("Offer to all players").visible,"player trading opens by default")
	check(game.amount_give.value==1 and game.amount_get.value==1,"player offer defaults to 1:1")
	await shot("players-day")
	game.set_process(false);game.ui_day_night.advance(0,5);await shot("players-night")
	game.ui_day_night.advance(1,5);game.set_process(true)
	for control in game.modal.find_children("*","Button",true,false):
		if control.icon==null or control is OptionButton:continue
		for state in ["normal","hover","pressed","hover_pressed"]:
			check(control.get_theme_color("icon_"+state+"_color")==Color.WHITE,"resource icons retain original colors in "+state)
	button("Bank").button_pressed=true;button("Bank").pressed.emit()
	check(game.amount_give.value==4 and game.amount_get.value==1,"bank shows 4:1 quantities")
	check(not game.amount_give.editable and not button("Bank trade").disabled,"bank amount fixed and affordable")
	game.selected_get.select(0);game.selected_get.item_selected.emit(0)
	check(button("Bank trade").disabled,"same-resource trade unavailable")
	game.selected_get.select(1);game.selected_get.item_selected.emit(1)
	button("Players").button_pressed=true;button("Players").pressed.emit()
	check(game.amount_give.editable and button("Offer to all players").visible,"player offer allows custom amount")
	check(game.amount_give.value==1 and game.amount_get.value==1,"switching from bank returns to 1:1 player offer")
	game.amount_give.value=5
	check(button("Offer to all players").disabled,"unaffordable offer unavailable")
	game._close_modal();r.s.vertices[0].owner=0;r.s.vertices[0].port=0;game.net._sync();game._trade()
	check(button("Players").button_pressed and game.amount_give.value==1,"reopening starts a new player offer")
	button("Bank").button_pressed=true;button("Bank").pressed.emit()
	check(game.amount_give.value==2 and game.amount_get.value==1,"owned resource port changes exchange quantity")
	var before=r.s.players[0].hand.duplicate();button("Bank trade").pressed.emit();await process_frame;await process_frame
	check(r.s.players[0].hand[0]==before[0]-2 and r.s.players[0].hand[1]==1,"bank click exchanges displayed quantities")
	game._close_modal();r.s.paired=true;game.net._sync();game._trade()
	check(button("Bank").button_pressed and not game.amount_give.editable,"paired turns default to bank instead")
	check(button("Players").disabled,"paired turn prevents player offers")
	game._close_modal();game.net.leave();game.queue_free();await create_timer(.2).timeout;await process_frame
	print("TRADE_UI_TEST: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
