extends SceneTree
var failures=0
var checks=0
func check(value: bool,message: String):
	checks+=1
	if not value: failures+=1; printerr("FAIL: ",message)
func pause(): await create_timer(0.12).timeout
func press(button: Button):
	check(button!=null and not button.disabled,"button available: "+str(button.name))
	button.pressed.emit()
	await pause()
func _initialize(): call_deferred("run")
func run():
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.4).timeout
	check(game.board.scene_file_path.ends_with("board.tscn"),"board instanced scene")
	check(game.audio.scene_file_path.ends_with("audio.tscn"),"audio instanced scene")
	check(game.ui.theme.default_font.multichannel_signed_distance_field,"UI uses scalable crisp font")
	check(game.board.board_labels.size()>19,"board labels rendered in UI layer")
	await press(game._node("Singleplayer"))
	check(game.net.solo and game.net.multiplayer.multiplayer_peer is OfflineMultiplayerPeer,"solo does not open a network socket")
	check(game.net.roster.size()==3,"solo has two default bots")
	await press(game._node("AddBot"))
	check(game.net.roster.size()==4 and not game._node("AddBot").disabled,"four seats allow extension")
	game.net.configure_bot("add")
	game.net.configure_bot("add")
	await pause()
	check(game.net.roster.size()==6 and game._node("AddBot").disabled,"six seats enforced")
	game.net.configure_bot("add")
	check(game.net.roster.size()==6,"server rejects seventh participant")
	game.net.configure_bot("remove",5)
	game.net.configure_bot("remove",4)
	await pause()
	var first_slot=game._node("PlayerSlots").get_child(1)
	var difficulty=first_slot.get_node("Row/Controls/Difficulty")
	difficulty.select(2)
	difficulty.item_selected.emit(2)
	await pause()
	check(game.net.roster[1].difficulty==2,"difficulty selector updates host")
	await press(game._node("PlayerSlots").get_child(3).get_node("Row/Controls/Remove"))
	check(game.net.roster.size()==3,"remove bot UI")
	game.net.configure_bot("remove",2)
	await pause()
	check(game._node("StartGame").disabled,"solo needs at least two bots")
	game.net.start_game()
	check(not game.net.started,"solo server rejects two participants")
	game.net.configure_bot("add")
	await pause()
	check(not game._node("StartGame").disabled,"three participants can start")
	game.net.configure_bot("difficulty",1,0)
	game.net.configure_bot("difficulty",2,1)
	game.net.configure_bot("add",-1,2)
	await press(game._node("StartGame"))
	check(game.state.phase=="setup_settlement","solo starts")
	game.net.bot_delay=0.10
	var helper=CatanBot.new(119)
	for i in 150:
		if game.state.phase=="play": break
		if game.state.turn==0:
			var action=helper.choose(game.state,0,1)
			game.net.act(action)
		await pause()
	check(game.state.phase=="play","all bot difficulties complete live setup")
	for p in 4: check(game.state.players[p].points==2,"two opening settlements")
	game._open_settings()
	check(game.net.paused,"solo paused in settings")
	game.modal.find_child("Master",true,false).value=35
	game.modal.find_child("Music",true,false).value=0
	game.modal.find_child("Quality",true,false).item_selected.emit(0)
	game.modal.find_child("ReducedMotion",true,false).button_pressed=true
	await pause()
	check(absf(game.preferences.values.master-0.35)<0.01,"master slider updates preference")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")),"music slider mutes bus")
	check(absf(AudioServer.get_bus_volume_db(0)-linear_to_db(0.35))<0.01,"master gain applied")
	check(game.get_viewport().msaa_3d==Viewport.MSAA_DISABLED,"low quality applied")
	check(game.board.reduce_motion,"reduced motion applied")
	var saved=CatanSettings.new()
	check(saved.values.master==0.35 and saved.values.music==0.0 and saved.values.reduce_motion,"preferences survive reload")
	game.modal.find_child("LargeText",true,false).button_pressed=true
	game.modal.find_child("BotSpeed",true,false).item_selected.emit(2)
	game.modal.find_child("Sensitivity",true,false).value=1.7
	game.modal.find_child("Effects",true,false).value=23
	game.modal.find_child("Ambience",true,false).value=15
	await pause()
	check(game.preferences.values.large_text,"larger text preference")
	check(game.modal.find_child("AudioHeading",true,false).get_theme_font_size("font_size")>=16,"larger text applied to native scene labels")
	check(absf(game.net.bot_delay-0.2)<0.01,"bot speed applied")
	check(absf(game.board.camera_speed-1.7)<0.01,"camera sensitivity applied")
	check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Effects"))-linear_to_db(0.23))<0.01,"effect gain applied")
	check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambience"))-linear_to_db(0.15))<0.01,"ambience gain applied")
	if DisplayServer.get_name()!="headless":
		game.modal.find_child("Fullscreen",true,false).button_pressed=true
		await pause()
		check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN,"fullscreen applied")
		game.modal.find_child("Fullscreen",true,false).button_pressed=false
		game.modal.find_child("VSync",true,false).button_pressed=false
		await pause()
		check(DisplayServer.window_get_vsync_mode()==DisplayServer.VSYNC_DISABLED,"VSync applied")
	await press(game.modal.find_child("ResetSettings",true,false))
	check(game.preferences.values==CatanSettings.DEFAULTS,"reset defaults")
	await press(game.modal.find_child("CloseSettings",true,false))
	check(not game.net.paused,"solo resumes after settings")
	check(game.audio.music.playing and game.audio.music.get_playback_position()>0,"music playback advancing")
	for effect in ["click","dice","build","trade","card","turn","win","error"]:
		game.audio.play(effect)
		check(game.audio.voices[(game.audio.voice_index-1)%8].playing,"effect plays: "+effect)
	game._tutorial_start()
	await pause()
	check(game.net.tutorial and game.guide.step==0,"tutorial starts independently")
	for step in CatanTutorial.LESSONS.size():
		game.guide.step=step
		game.guide.load_lesson(game.net,"Voyager")
		await pause()
		var expected=game.guide.current().action
		var action={"type":expected}
		match expected:
			"settlement","road": action=helper.choose(game.state,0,1)
			"roll": pass
			"city":
				for v in game.state.vertices.size():
					if game.state.vertices[v].owner==0: action.id=v; break
			"bank_trade": action.give=0; action.receive=1
			"robber": action.id=(game.state.robber+1)%19
			"play_card": action.id=0
		if not expected.is_empty():
			game.net.act(action)
			await pause()
		check(game.guide.completed,"tutorial lesson completed: "+str(step))
		check(not game.tutorial_panel.find_child("NextLesson",true,false).disabled,"tutorial allows next: "+str(step))
	game._tutorial_step(1)
	check(game.guide==null and game.net.solo and not game.net.tutorial,"tutorial graduation opens solo lobby")
	game.net.leave()
	print("FEATURE_TEST: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
