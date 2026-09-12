extends SceneTree
var game
var checks=0
var failures=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func settle():
	for i in 6:await process_frame
func shot(label: String):
	await settle()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/catan-022-"+label+".png")
func run():
	game=load("res://scenes/main.tscn").instantiate()
	game.preferences=CatanSettings.new("user://ui-localization-test.cfg")
	game.preferences.values=CatanSettings.DEFAULTS.duplicate()
	root.add_child(game)
	await create_timer(.4).timeout
	game.preferences.set_value("language",1);game.preferences.set_value("day_night_cycle",false)
	game._apply_preferences();await settle()
	game._open_settings();await settle()
	var toggle=game.modal.controls.day_night_cycle
	for type in ["Button","OptionButton","CheckButton","CheckBox"]:
		check(game.ui.theme.has_stylebox("hover_pressed",type),type+" has explicit checked hover surface")
		check(game.ui.theme.get_stylebox("hover_pressed",type) is StyleBoxTexture,type+" checked hover is textured")
	toggle.set_pressed_no_signal(true)
	Input.warp_mouse(Vector2(10,10));await shot("switch-checked")
	Input.warp_mouse(toggle.get_global_rect().get_center());await shot("switch-hover")
	if DisplayServer.get_name()!="headless":check(toggle.get_draw_mode()==BaseButton.DRAW_HOVER_PRESSED,"pointer reaches checked hover state")
	game.ui_day_night.advance(0,5);await shot("switch-hover-night")
	game.ui_day_night.advance(1,5)
	game.modal._change(game.modal.OPTIONS[1],0);await settle()
	check(TranslationServer.translate("Move the robber")=="Move the robber","switch back to English")
	game.modal._change(game.modal.OPTIONS[1],1);await settle()
	check(TranslationServer.translate("Move the robber")=="Sposta il brigante","switch to Italian live")
	game._close_modal();game._open_cosmetics();await settle()
	check(game.modal.color_buttons.size()==20,"twenty simple color swatches");await shot("color-swatches-it")
	game._close_modal();game._solo();game.net.roster[0].name="City";game.net.start_game();game.net.paused=true
	game.net.rules.s.players[0].name="City"
	game.net.rules.s.players[0].cards=[1,1,1,1,1]
	game.net.rules.s.players[0].new_cards=[1,1,1,1,1]
	game.net._sync();await settle()
	check(game._phase_text()=="Preparazione","setup phase translated before composition")
	check(game._node("TimberBadge").tooltip_text=="Legno: 0","resource badge translates before formatting")
	var card=game._node("Card0")
	check("card_ready" not in card.tooltip_text and "disponibili" in card.tooltip_text,"card availability tooltip uses translated copy")
	check(card.find_child("CardEffect",true,false).text=="Sposta il brigante","card effect translated")
	check("City (tu)" in game._node("PlayerChip0").tooltip_text,"player name remains literal")
	await shot("cards-it")
	game._open_music();game.net.music_control("toggle");game._refresh_music_widgets(game.music_dialog_widgets,game.net.music_state())
	check("Il porto all’alba" in game.music_dialog_widgets.title.text,"formatted music title translated")
	check("Harbor at Dawn" not in game.music_dialog_widgets.title.tooltip_text,"music tooltip title translated")
	await shot("music-it")
	game._close_modal();game.queue_free();await create_timer(.3).timeout
	print("UI_LOCALIZATION_TEST: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
