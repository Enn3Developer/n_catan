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
		root.get_texture().get_image().save_png("/tmp/catan-ui-"+title+".png")
func run():
	game=load("res://scenes/main.tscn").instantiate()
	game.preferences=CatanSettings.new("user://appearance-roads-test.cfg")
	game.preferences.values=CatanSettings.DEFAULTS.duplicate()
	game.preferences.values.day_night_cycle=false
	root.add_child(game);await create_timer(.4).timeout
	game._open_settings()
	check(not game.modal.get_node("%Navigation").get_children().any(func(n):return n is Button and n.text=="Appearance"),"settings has no duplicate appearance navigation")
	game._open_cosmetics()
	check(game.modal.color_buttons.size()==20,"twenty color choices")
	for i in 20:
		game.modal.color_buttons[i].pressed.emit()
		check(game.modal.preview_color==Color(game.modal.COLOR_SWATCHES[i][1]),"swatch selects exact player color")
		check(game.modal.color_buttons.filter(func(b):return b.button_pressed).size()==1,"one selected swatch")
	game.modal.preview_color=Color("5de623");game.modal.select_style(2)
	check(game.modal.color_name.text=="Player color: Custom","legacy custom color remains supported")
	game.modal._equip()
	check(game.preferences.values.player_color=="5de623","custom color survives applying appearance")
	root.size=Vector2i(800,600)
	await shot("appearance-custom-800")
	game.modal.color_buttons[6].pressed.emit()
	await shot("appearance-swatches-800")
	game.set_process(false)
	game.ui_day_night.advance(0,5)
	await shot("appearance-night-800")
	game.ui_day_night.advance(1,5)
	game.set_process(true)
	game._close_modal();CatanI18n.apply(1);game._open_cosmetics()
	game.modal.color_buttons[8].pressed.emit()
	check(game.modal.color_name.text=="Colore giocatore: Verde petrolio","color names and selection label translate into Italian")
	await shot("appearance-it-800")
	CatanI18n.apply(0)
	game._close_modal();game._solo();game.net.start_game();game.net.paused=true
	game.board.set_process(false)
	game.turn_banner.hide()
	game.screen.hide()
	var state=game.net.rules.s
	var center=-1
	var distance=INF
	for i in state.vertices.size():
		var vertex=state.vertices[i]
		var degree=state.edges.filter(func(e):return e.a==i or e.b==i).size()
		var d=Vector2(vertex.x,vertex.z).length()
		if degree==3 and d<distance:center=i;distance=d
	var incident=state.edges.filter(func(e):return e.a==center or e.b==center)
	for e in state.edges:e.owner=-1
	for v in state.vertices:v.owner=-1;v.level=0
	incident[0].owner=0;incident[1].owner=0
	for style in 4:
		game.net.roster[0].piece_style=style;game.net._sync()
		var joints=game.board.pieces_root.find_children("RoadJoint*","Node3D",false,false)
		check(joints.size()==1,"same-owner bend joins for each style")
		var vertex=Vector3(state.vertices[center].x,0,state.vertices[center].z)
		for road in game.board.pieces_root.find_children("Road_*","Node3D",false,false):
			var a=road.position+road.basis.z*.385;var b=road.position-road.basis.z*.385
			a.y=0;b.y=0
			check(minf(a.distance_to(vertex),b.distance_to(vertex))<.001,"road mesh reaches the shared vertex")
		for i in 8:await process_frame
		game.board.markers.hide()
		game.screen.hide()
		game.turn_banner.hide()
		vertex=game.board.pieces_root.to_global(vertex+Vector3.UP*.25)
		game.board.camera.h_offset=0;game.board.camera.v_offset=0
		game.board.camera.position=vertex+Vector3(.7,1.8,1.6)*CatanBoard.TILE_SIZE
		game.board.camera.look_at(vertex)
		await shot("road-bend-"+str(style))
	incident[2].owner=0;game.net._sync()
	check(game.board.pieces_root.find_children("RoadJoint*","Node3D",false,false).size()==1,"three-way branch shares one join")
	for i in 8:await process_frame
	game.screen.hide()
	var focus=game.board.pieces_root.to_global(Vector3(state.vertices[center].x,.25,state.vertices[center].z))
	game.board.camera.h_offset=0;game.board.camera.v_offset=0
	game.board.camera.position=focus+Vector3(.7,1.8,1.6)*CatanBoard.TILE_SIZE;game.board.camera.look_at(focus)
	await shot("road-branch")
	incident[1].owner=1;incident[2].owner=-1;game.net._sync()
	check(game.board.pieces_root.find_children("RoadJoint*","Node3D",false,false).is_empty(),"opponent roads remain separate")
	incident[1].owner=0;state.vertices[center].owner=1;state.vertices[center].level=1;game.net._sync()
	check(game.board.pieces_root.find_children("RoadJoint*","Node3D",false,false).is_empty(),"occupied vertex keeps building clearance")
	game.net.leave();game.queue_free();await create_timer(.2).timeout;await process_frame
	print("APPEARANCE_ROADS_TEST: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
