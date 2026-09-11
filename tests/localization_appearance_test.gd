extends SceneTree
var game
var checks=0
var failures=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func shot(label: String):
	await create_timer(.2).timeout
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png("/tmp/catan-localization-"+label+".png")
func run():
	var config=CatanSettings.new("user://localization-test.cfg")
	config.set_value("language",1);config.set_value("player_color","12abcd")
	check(CatanSettings.new(config.path).values.language==1,"language persists")
	check(CatanSettings.new(config.path).values.player_color=="12abcd","color persists")
	config.set_value("player_color","transparent");check(config.values.player_color=="","invalid color rejected")
	CatanI18n.apply(1)
	check(CatanI18n.render("Your turn")=="È il tuo turno","Italian catalog loaded")
	var message=CatanI18n.message("%s stole a resource from %s.",["City","Knight"])
	check(CatanI18n.render(message)=="City ha rubato una risorsa a Knight.","player names remain untranslated")
	var r=CatanRules.new();r.create(["City","Knight","Wool"],123)
	r.s.phase="play";r.s.rolled=true;r.s.turn=0;r.s.players[0].hand=[0,0,0,0,0]
	var error=r.apply(0,{"type":"bank_trade","give":0,"receive":1})
	check("4 Legno" in CatanI18n.render(error),"bank shortage includes count and translated resource")
	CatanI18n.apply(0)
	check("4 more Timber" in CatanI18n.render(error),"same wire error renders in English")
	r.s.players[0].hand[0]=4;r.s.bank[1]=0
	check("no Brick left" in CatanI18n.render(r.apply(0,{"type":"bank_trade","give":0,"receive":1})),"bank stock distinguished from player shortage")
	r.s.players[0].hand[0]=0
	check("make this offer" in CatanI18n.render(r.apply(0,{"type":"offer_trade","give":[1,0,0,0,0],"receive":[0,1,0,0,0]})),"offer shortage explained")
	r.s.offer={"from":1,"give":[1,0,0,0,0],"receive":[0,2,0,0,0]};r.s.turn=1
	check("2 Brick" in CatanI18n.render(r.apply(0,{"type":"accept_trade"})),"accept shortage names missing resources")
	r.s.offer={};check("no longer available" in r.apply(0,{"type":"accept_trade"}),"stale offer explained")
	r.s.turn=0;r.s.players[0].new_cards[0]=1
	check("next turn" in r.apply(0,{"type":"play_card","id":0}),"new card wait explained")
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await create_timer(.3).timeout
	game.preferences.set_value("language",1);game._apply_preferences();await process_frame;await process_frame
	check(TranslationServer.get_locale().begins_with("it"),"language applies live")
	await shot("home")
	game._open_settings();await process_frame
	check(game.modal.controls.has("language"),"language selector in settings")
	game.modal.select_tab("World");await shot("settings")
	game._close_modal();game._open_cosmetics()
	game.modal.preview_color=Color("22aadd");game.modal.select_style(2);game.modal._equip()
	check(game.preferences.values.player_color=="22aadd" and game.net.my_color=="22aadd","home color equips and saves")
	await shot("appearance")
	game._close_modal();game._solo();game.net.start_game();game.net.paused=true
	await process_frame
	check(game.state.player_colors[0]=="22aadd","snapshot includes color")
	check(game.board.player_color(0).is_equal_approx(Color("22aadd")),"board uses custom color")
	check(game.turn_banner.visible and game.turn_banner.text=="È il tuo turno","own turn has Italian banner")
	check(game.turn_banner.get_theme_color("font_color").is_equal_approx(Color("22aadd")),"banner matches player")
	check(game.turn_banner.mouse_filter==Control.MOUSE_FILTER_IGNORE,"banner does not block clicks")
	await shot("turn")
	game.turn_banner_timer.stop();game.turn_banner.hide();game.net._sync()
	check(not game.turn_banner.visible,"repeated snapshot does not repeat banner")
	game.net.rules.s.turn=1;game.net._sync()
	check(not game.turn_banner.visible,"other player never gets local banner")
	game.net.rules.s.turn=0;game.net._sync()
	check(game.turn_banner.visible,"next own turn shows banner")
	await create_timer(3.1).timeout
	check(not game.turn_banner.visible,"banner expires after three seconds")
	game._trade();await shot("trade")
	game._close_modal();game._help();await shot("guide")
	game._close_modal();game.preferences.set_value("language",0);game._apply_preferences();await process_frame;await process_frame
	check(TranslationServer.get_locale().begins_with("en"),"can switch back to English during match")
	game.net.leave();game.queue_free();await create_timer(.2).timeout;await process_frame;await process_frame
	print("LOCALIZATION_APPEARANCE_TEST: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
