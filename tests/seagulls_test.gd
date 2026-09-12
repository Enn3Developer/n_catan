extends SceneTree
var checks=0
var failures=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func shot(path: String):
	await create_timer(.2).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run():
	var game=load("res://scenes/main.tscn").instantiate()
	game.preferences=CatanSettings.new("user://gulls-test.cfg");game.preferences.values=CatanSettings.DEFAULTS.duplicate()
	game.preferences.values.day_night_cycle=false;game.preferences.values.weather=1
	root.add_child(game);await create_timer(.4).timeout;game.set_process(false)
	var board=game.board;board.set_process(false)
	var gulls=board.seagulls
	check(gulls.flock.size()==6 and board.birds.size()==6,"bounded pool replaces the three fixed birds")
	check(gulls.flock.all(func(bird):return is_instance_valid(bird.WingLeft) and is_instance_valid(bird.WristRight) and is_instance_valid(bird.Head) and is_instance_valid(bird.Feet)),"Blender wing, neck and foot pivots survive glTF import")
	check(gulls.flock.all(func(bird):return bird.feathers.size()==4),"all four wing sections import their folded shape")
	check(gulls.flock[0].model.find_children("*","MeshInstance3D",true,false).size()==7,"static parts are batched into seven meshes")
	var seen={};var populations={};var steady=true;var reservations=true;var glide=false;var flap=false
	var time=0.0
	for tick in 2400:
		var previous=gulls.flock.map(func(bird):return [bird.state,bird.root.position])
		time+=.1;gulls.animate(.1,time,1.0,{"rain":0.0,"storm":0.0},false)
		var owners={}
		for perch in gulls.perches:
			if perch.owner<0:continue
			if owners.has(perch.owner):reservations=false
			owners[perch.owner]=true
		for bird in gulls.flock:
			seen[bird.state]=true
			if previous[bird.id][0]!="away" and bird.state!="away":
				steady=steady and bird.root.position.distance_to(previous[bird.id][1])<.45 and bird.root.position.is_finite()
			if bird.state=="flying":glide=glide or bird.flap<.1;flap=flap or bird.flap>.8
		populations[gulls.flock.filter(func(bird):return bird.root.visible).size()]=true
	check(seen.has_all(["arriving","flying","approaching","landing","perched","takeoff","leaving","away","skimming"]),"visitors naturally arrive, fly, skim, perch and leave")
	check(populations.size()>1 and not populations.has(6),"visible population varies and stays below its cap")
	check(steady,"flight and landing paths have no position jumps")
	check(reservations,"each visitor reserves at most one harbour perch")
	check(glide and flap,"cruise alternates gliding with powered wingbeats")
	for tick in 900:time+=.1;gulls.animate(.1,time,1.0,{"storm":1.0},false)
	check(gulls.flock.all(func(bird):return bird.state=="away" and not bird.root.visible),"storm drives the flock offshore")
	check(gulls.perches.all(func(perch):return perch.owner<0),"departures release every perch")
	for tick in 300:time+=.1;gulls.animate(.1,time,0.0,{},false)
	check(gulls.flock.all(func(bird):return not bird.root.visible),"night prevents new arrivals")
	for tick in 800:time+=.1;gulls.animate(.1,time,1.0,{},false)
	check(gulls.flock.any(func(bird):return bird.root.visible),"gulls return in daylight after the storm")
	gulls.animate(0,time,1.0,{},true)
	check(gulls.flock.filter(func(bird):return bird.state=="perched").all(func(bird):return bird.feathers.all(func(part):return is_equal_approx(part.get_blend_shape_value(0),1.0))),"resting gulls fold their feathers against their bodies")
	var poses=gulls.flock.map(func(bird):return [bird.root.transform,bird.WingLeft.transform,bird.Head.transform])
	gulls.animate(1,time+1,1.0,{},true)
	check(gulls.flock.all(func(bird):return bird.state in ["perched","away"]),"reduced motion keeps gulls on harbour posts")
	for bird in gulls.flock:
		check([bird.root.transform,bird.WingLeft.transform,bird.Head.transform]==poses[bird.id],"reduced motion freezes the complete pose")
	gulls.animate(0,time,0.0,{},true)
	check(gulls.flock.all(func(bird):return not bird.root.visible),"night also hides resting gulls with reduced motion")
	# Rebuilding at six-player scale must refresh perches, not retain harbour nodes.
	var data=board.state.duplicate(true);data.extension=true;board.build(data)
	check(gulls.perches.size()==board.harbors.size(),"board rebuild refreshes the perch inventory")
	check(board.scenery.to_global(gulls.perches[0].position).distance_to(board.harbors[0].to_global(Vector3(-.135,.140,.72)))<.001,"perch coordinates follow the expanded scenery scale")
	check(gulls.flock.size()==6,"rebuild reuses the same model instances")
	if DisplayServer.get_name()!="headless":
		game.ui.hide();board.view_region=Rect2();board.show_labels=false
		for entry in board.board_labels:entry.label.hide()
		data.extension=false;board.build(data)
		gulls.animate(0,0,1.0,{},true)
		var resting=gulls.flock[0]
		board.camera.h_offset=0;board.camera.v_offset=0
		var focus=resting.root.global_position+Vector3.UP*1.4
		board.camera.position=focus+Vector3(10,7,12);board.camera.look_at(focus)
		await shot("/tmp/catan-seagull-perched.png")
		var flying=gulls.flock[1]
		flying.root.show();flying.state="flying";flying.root.position=Vector3(0,4,0);flying.root.rotation=Vector3.ZERO
		flying.fold=0;flying.flap=0;gulls._pose(flying,0,5)
		focus=flying.root.global_position+Vector3.UP*1.0
		board.camera.position=focus+Vector3(9,9,-14);board.camera.look_at(focus)
		await shot("/tmp/catan-seagull-flight.png")
	game.queue_free();await create_timer(.2).timeout
	print("SEAGULLS_TEST: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
