extends SceneTree
var failures=0
func check(ok,message):
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await create_timer(.5).timeout
	check(game._node("ExitDesktop") is Button,"desktop exit in home menu")
	game._open_settings()
	check(game.modal.tabs.keys()==["Graphics","World","Audio"],"one graphics tab")
	for key in ["fullscreen","shadow_quality","water_quality","wind","quality"]:
		check(game.modal.tabs.Graphics.is_ancestor_of(game.modal.controls[key]),"graphics group "+key)
	game._close_modal()
	var board=game.board
	check(is_equal_approx(board.TILE_SIZE*2,50),"50 metre hex diameter")
	check(board.actors.size()>40,"populated resource tiles")
	var actor=board.actors.filter(func(entry):return entry.type=="sheep")[0]
	actor.phase=0.0
	board.living_world.animate([actor],0,board.art)
	var start=actor.root.position
	board.living_world.animate(board.actors,5,board.art)
	check(actor.root.position.distance_to(start)>.001,"actors walk")
	board.reduce_motion=true
	var clock=board.elapsed;board._process(1)
	check(board.elapsed==clock,"reduced motion freezes world")
	check(board.harbors.size()>0,"coastal harbors exist")
	for harbor in board.harbors:check(harbor.has_node("MooredBoat"),"harbor has moored boat")
	var town=board.living_world.town(0,Color.CORAL,true)
	check(town.find_children("TimberHouse*","Node3D",true,false).size()==6,"city has six houses and keep")
	town.free()
	# A populated overview and close view are captured when run with graphics enabled.
	var data=board.state.duplicate(true)
	for i in [0,5,15]:data.vertices[i].owner=i%3;data.vertices[i].level=2 if i==5 else 1
	board.refresh(data)
	if DisplayServer.get_name()!="headless":
		game.ui.visible=false;board.show_labels=false
		board.camera_focus=Vector3.ZERO;board.camera_zoom=.8;board._update_camera()
		await create_timer(1).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/catan-living-overview.png")
		var vertex=data.vertices[5];board.camera_focus=Vector3(vertex.x*board.TILE_SIZE,.25*board.TILE_SIZE,vertex.z*board.TILE_SIZE);board.camera_zoom=.15;board._update_camera()
		await create_timer(.5).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/catan-living-city.png")
	game.queue_free();await create_timer(.2).timeout;await process_frame
	print("LIVING_WORLD_TEST: ",failures," failures");quit(1 if failures else 0)
