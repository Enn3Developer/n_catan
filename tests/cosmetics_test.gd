extends SceneTree
var game
var checks=0
var failures=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func shot(label: String):
	await create_timer(.35).timeout
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png("/tmp/catan-cosmetics-"+label+".png")
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await create_timer(1).timeout
	check(game._node("OpenCosmetics").visible,"visible main menu entry")
	await shot("home")
	game._node("OpenCosmetics").pressed.emit()
	await process_frame
	await process_frame
	check(game.modal.target==-1,"home selection has no seat")
	game.modal.select_style(2);game.modal._equip()
	check(game.preferences.values.piece_style==2 and game.net.my_style==2,"home style saved")
	check(CatanSettings.new().values.piece_style==2,"style persists on disk")
	game._close_modal();game._solo()
	for i in 3:game.net.configure_bot("add")
	check(game.net.roster[0].piece_style==2,"solo inherits saved style")
	check(game._node("LobbyCosmetics")!=null,"lobby entry")
	game._open_cosmetics()
	check(game.modal.choices.item_count==6,"six-player cosmetics selector")
	for style in 4:
		game.modal.select_style(style)
		check(not game.modal.equip.disabled or game.net.roster[0].piece_style==style,"equip button reflects actual state")
		await shot(CatanCosmetics.SETS[style].to_lower())
		game.modal._equip()
		check(game.net.roster[0].piece_style==style,"own lobby style applies")
		check(is_instance_valid(game.modal) and game.modal.name=="Cosmetics","lobby sync preserves wardrobe")
		check(game.modal.equip.disabled,"equipped status updates")
	var motion=InputEventMouseMotion.new();motion.button_mask=MOUSE_BUTTON_MASK_LEFT;motion.relative=Vector2(40,0)
	game.modal._preview_input(motion)
	check(game.modal.display_root.get_child(0).rotation.y>0,"interactive preview rotation")
	game.modal.choices.select(1);game.modal._target_changed(1)
	game.modal.select_style(1);game.modal._equip()
	check(game.net.roster[1].piece_style==1,"host can style bot")
	check(game.preferences.values.piece_style==3,"bot style does not change own saved choice")
	game._close_modal()
	await shot("lobby")
	game.net.start_game();game.net.paused=true
	check(game.state.piece_styles==[3,1,2,3,0,1],"snapshot carries all cosmetics")
	var rules=game.net.rules
	# Fixed populated sample to verify actual scene instances, keeping ownership distinct.
	for i in 3:
		rules.s.vertices[i*5].owner=i;rules.s.vertices[i*5].level=1
		rules.s.vertices[i*5+2].owner=i;rules.s.vertices[i*5+2].level=2
		rules.s.edges[i*5].owner=i
	game.net._sync()
	check(game.board.pieces_root.find_children("Road_*","Node3D",true,false).size()==3,"roads rendered")
	check(game.board.pieces_root.find_children("MedievalVillage*","Node3D",true,false).size()==3,"settlements rendered")
	check(game.board.pieces_root.find_children("MedievalCity*","Node3D",true,false).size()==3,"cities rendered")
	game._open_cosmetics();game.modal.select_style(0);game.modal._equip()
	check(game.net.paused,"solo remains paused while choosing")
	check(game.state.piece_styles[0]==0,"in-match cosmetic sync")
	check(game.board.pieces_root.find_children("MedievalCity*","Node3D",true,false).filter(func(city):return city.get_meta("cosmetic")==0).size()==1,"equipped city rebuilt in game")
	var before=var_to_str(rules.s)
	game.net.choose_piece_style(99)
	check(game.state.piece_styles[0]==0,"invalid cosmetic rejected")
	check(var_to_str(rules.s)==before,"cosmetics do not change rules")
	game._close_modal();game.net.paused=true
	await shot("board")
	game.preferences.set_value("piece_style",0)
	game.net.leave();game.queue_free();await process_frame
	print("COSMETICS_TEST: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
