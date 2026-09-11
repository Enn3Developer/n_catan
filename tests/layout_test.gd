extends SceneTree
var game
var surface: SubViewport
var checks=0
var failures=0
const SIZES=[Vector2i(800,600),Vector2i(1024,768),Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080),Vector2i(2560,1080),Vector2i(900,1100)]
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func settle():
	for i in 8:await process_frame
func shot(label: String):
	await settle()
	if DisplayServer.get_name()!="headless":surface.get_texture().get_image().save_png("/tmp/catan-rework-"+label+".png")
func inspect_layout(scope: Node,label: String):
	var bounds=Rect2(Vector2.ZERO,Vector2(surface.size)).grow(2)
	for node in scope.find_children("*","Control",true,false):
		if not node.is_visible_in_tree():continue
		if node is PanelContainer or node is ScrollContainer:
			var scroll_parent=false
			var parent=node.get_parent()
			while parent!=scope and parent!=null:
				if parent is ScrollContainer:scroll_parent=true;break
				parent=parent.get_parent()
			if not scroll_parent:check(bounds.encloses(node.get_global_rect()),"%s %s inside window %s" % [label,node.name,node.get_global_rect()])
		if node is Container and not node is ScrollContainer and not node is FlowContainer:
			for child in node.get_children():
				if child is Control and child.visible:
					check(node.get_global_rect().grow(2).encloses(child.get_global_rect()),"%s %s fits %s (%s / %s)" % [label,child.name,node.name,child.get_global_rect(),node.get_global_rect()])
func run():
	surface=SubViewport.new();surface.own_world_3d=true;surface.size=Vector2i(1440,900);surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(surface)
	game=load("res://scenes/main.tscn").instantiate();surface.add_child(game)
	await create_timer(2).timeout
	if "--italian" in OS.get_cmdline_user_args():game.preferences.set_value("language",1)
	game.preferences.set_value("frame_limit",2);game._apply_preferences()
	for dimensions in SIZES:
		surface.size=dimensions;await create_timer(.3).timeout;await settle()
		check(surface.get_visible_rect().size==Vector2(dimensions),"viewport responds to window: requested %s actual %s visible %s" % [dimensions,surface.size,surface.get_visible_rect()])
		inspect_layout(game.screen,"home "+str(dimensions))
		game._node("ShowOnline").button_pressed=true;await settle()
		inspect_layout(game.screen,"host form "+str(dimensions))
		game._online_mode(false);await settle();inspect_layout(game.screen,"join form "+str(dimensions))
		game._online_mode(true);await settle()
		if dimensions.x in [800,1440]:await shot("home-%d" % dimensions.x)
		game._node("ShowOnline").button_pressed=false
	game._solo()
	for i in 3:game.net.configure_bot("add")
	for i in game.net.roster.size():game.net.roster[i].name="Long Player Name %02d" % i
	game._lobby()
	for dimensions in SIZES:
		surface.size=dimensions;await create_timer(.3).timeout;await settle();inspect_layout(game.screen,"lobby "+str(dimensions))
		if dimensions.x in [800,1440]:await shot("lobby-%d" % dimensions.x)
	game.net.start_game();game.net.paused=true
	for dimensions in SIZES:
		surface.size=dimensions;await create_timer(.3).timeout;await settle();inspect_layout(game.screen,"hud "+str(dimensions))
		check(game._node("HandBody").find_children("*Badge","HBoxContainer",true,false).size()==5,"five resource badges")
		var available=game.board.view_region.grow(25)
		for target in game.board.targets:
			check(available.has_point(game.board.camera.unproject_position(target.pos)),"placement visible "+str(dimensions))
		if dimensions.x in [800,1440,2560]:await shot("hud-%d" % dimensions.x)
	game._open_settings()
	for dimensions in SIZES:
		surface.size=dimensions;await create_timer(.3).timeout;await settle()
		for tab in ["Graphics","World","Audio"]:
			game.modal.select_tab(tab);await settle();inspect_layout(game.modal,"settings "+tab+str(dimensions))
		game.modal.select_tab("Graphics")
		if dimensions.x in [800,1440]:await shot("settings-%d" % dimensions.x)
	game._close_modal();game._open_cosmetics()
	for dimensions in SIZES:
		surface.size=dimensions;await create_timer(.3).timeout;await settle();inspect_layout(game.modal,"cosmetics "+str(dimensions))
		if dimensions.x in [800,1440]:await shot("cosmetics-%d" % dimensions.x)
	game._close_modal()
	surface.size=Vector2i(800,600)
	for fn in [game._trade,game._open_music,game._help,game._confirm_leave,game._journal]:
		fn.call();await settle();inspect_layout(game.modal,"dialog")
	await shot("dialog-800")
	game._close_modal()
	game.preferences.set_value("large_text",true);game._apply_preferences();await settle()
	inspect_layout(game.screen,"large text hud")
	game._open_settings();await settle();inspect_layout(game.modal,"large text settings");game._close_modal()
	game.net.leave();game._tutorial_start()
	for dimensions in [Vector2i(800,600),Vector2i(1440,900)]:
		surface.size=dimensions;await create_timer(.3).timeout;await settle();inspect_layout(game.tutorial_panel,"tutorial "+str(dimensions));await shot("tutorial-%d" % dimensions.x)
	game.net.leave();game.queue_free();await process_frame
	surface.queue_free();await process_frame
	print("LAYOUT_TEST: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
