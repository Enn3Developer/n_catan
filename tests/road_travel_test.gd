extends SceneTree
var checks=0
var failures=0
var travel=preload("res://scripts/road_travel.gd").new()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func shot(title: String):
	for i in 6:await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/catan-road-travel-"+title+".png")
func graph_checks():
	var state={"vertices":[],"edges":[]}
	for i in 6:state.vertices.append({"owner":-1})
	state.vertices[0].owner=0;state.vertices[3].owner=0
	for pair in [[0,1],[1,2],[2,3],[2,4],[4,1]]:state.edges.append({"a":pair[0],"b":pair[1],"owner":0})
	check(travel.routes(state).size()==1,"connected towns have one route despite a loop and branch")
	check(travel.routes(state)[0].vertices==[0,1,2,3],"shortest road path chosen")
	state.vertices[3].owner=1
	check(travel.routes(state).is_empty(),"does not visit opponent town")
	state.vertices[3].owner=0;state.vertices[2].owner=1
	check(travel.routes(state).is_empty(),"opponent town blocks travel")
	state.vertices[2].owner=-1;state.edges[0].owner=1
	check(travel.routes(state).is_empty(),"opponent road blocks travel")
	state.edges[0].owner=-1
	check(travel.routes(state).is_empty(),"disconnected town has no walker")
	state.vertices[0].owner=-1
	check(travel.routes(state).is_empty(),"dead end without a town is not a destination")
func run():
	graph_checks()
	root.size=Vector2i(1280,800)
	var board=load("res://scenes/board.tscn").instantiate();root.add_child(board);await process_frame
	var rules=CatanRules.new();rules.create(["A","B","C"],9047)
	var data=rules.snapshot(0)
	var center=-1;var closest=INF
	for i in data.vertices.size():
		var v=data.vertices[i]
		if data.edges.filter(func(e):return e.a==i or e.b==i).size()!=3:continue
		if Vector2(v.x,v.z).length()<closest:center=i;closest=Vector2(v.x,v.z).length()
	var edges=data.edges.filter(func(e):return e.a==center or e.b==center)
	var first=edges[0].a if edges[0].a!=center else edges[0].b
	var last=edges[1].a if edges[1].a!=center else edges[1].b
	data.vertices[first].owner=0;data.vertices[first].level=1
	data.vertices[last].owner=0;data.vertices[last].level=2
	edges[0].owner=0;edges[1].owner=0
	board.build(data);board.set_process(false);board.render_values["day_night_cycle"]=false
	var initial_population=board.dwellers.size()
	check(initial_population==22,"travel reuses town population")
	for style in 4:
		data=data.duplicate(true);data.piece_styles=[style,0,0];board.refresh(data)
		var walkers=board.dwellers.filter(func(actor):return actor.has("route"))
		check(walkers.size()==1,"one road walker for connected settlement and city")
		var actor=walkers[0]
		var duration=actor.route.length/.045
		var time=duration*.35-actor.index*7.73
		board.living_world.animate_dwellers(board.dwellers,time,1)
		check(actor.root.visible and actor.moving,"walker travels during daylight")
		check(is_equal_approx(actor.root.position.y,CatanCosmetics.road_deck_height(style)),"feet follow lowered road deck")
		var before=actor.root.position
		board.living_world.animate_dwellers(board.dwellers,time+.1,1)
		var direction=actor.root.position-before
		check(direction.length()>.004 and direction.length()<.005,"walking speed is steady")
		check((-actor.root.basis.z.normalized()).dot(direction.normalized())>.95,"walker faces travel")
		board.living_world.animate_dwellers(board.dwellers,duration+1-actor.index*7.73,1)
		check(not actor.root.visible and not actor.moving,"walker rests at destination")
		board.living_world.animate_dwellers(board.dwellers,time,0)
		check(not actor.root.visible,"road walkers stay home at night")
		var rest=12.0+float(actor.index%4)*3.0
		var return_time=duration+rest+duration*.4-actor.index*7.73
		board.living_world.animate_dwellers(board.dwellers,return_time,1);before=actor.root.position
		board.living_world.animate_dwellers(board.dwellers,return_time+.1,1)
		check(actor.root.visible and (-actor.root.basis.z.normalized()).dot((actor.root.position-before).normalized())>.95,"return journey faces back toward home")
		board.elapsed=time;board.reduce_motion=true;board.daylight=1
		board.living_world.animate_dwellers(board.dwellers,time,1);before=actor.root.position
		board._process(1)
		check(actor.root.position.is_equal_approx(before),"reduced motion freezes road travel")
		var old=actor.root;board.refresh(data)
		actor=board.dwellers.filter(func(a):return a.has("route"))[0]
		check(not is_instance_valid(old) and actor.root.position.is_equal_approx(before),"snapshot rebuild preserves journey progress without stale actors")
		check(board.dwellers.size()==initial_population,"refresh does not duplicate population")
		var focus=board.pieces_root.to_global(Vector3(data.vertices[center].x,.24,data.vertices[center].z))
		board.markers.hide();board.camera.h_offset=0;board.camera.v_offset=0
		board.camera.position=focus+Vector3(.7,1.9,2.3)*CatanBoard.TILE_SIZE;board.camera.look_at(focus)
		for road in board.pieces_root.find_children("Road_*","Node3D",false,false):
			check(road.position.y<.22 and is_equal_approx(road.scale.y,.3),"roads have a low profile")
		for entry in board.board_labels:entry.label.hide()
		board.fps_label.hide()
		await shot("style-"+str(style))
	data=data.duplicate(true)
	for edge in data.edges:edge.owner=-1
	board.refresh(data)
	check(board.dwellers.all(func(actor):return not actor.has("route")),"removing road restores local town errands")
	check(board.dwellers.size()==initial_population,"removing road preserves town population")
	board.queue_free();await process_frame
	print("ROAD_TRAVEL_TEST: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
