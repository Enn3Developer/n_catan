extends SceneTree
var checks=0
var failures=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await create_timer(.5).timeout
	var board=game.board;var landscape=board.background_landscape
	check(landscape.sectors.size()==12,"continuous mainland surrounds every camera orbit")
	var vertices=0;var nearest=INF;var tallest=0.0
	# Per bearing: the nearest point above water and the highest ground.
	var shore=[];var crest=[]
	shore.resize(360);shore.fill(INF);crest.resize(360);crest.fill(-INF)
	# Points on bearing 0, seen from its first and last sector.
	var seams=[[],[]]
	for index in landscape.sectors.size():
		var island=landscape.sectors[index]
		check(island.mesh.get_surface_count()==1,"terrain and forest batched into one surface")
		var arrays=island.mesh.surface_get_arrays(0)
		check(arrays[Mesh.ARRAY_COLOR]!=null and arrays[Mesh.ARRAY_COLOR].size()==arrays[Mesh.ARRAY_VERTEX].size(),"painted with vertex colors")
		vertices+=arrays[Mesh.ARRAY_VERTEX].size()
		for vertex in arrays[Mesh.ARRAY_VERTEX]:
			var p=island.transform*vertex
			var flat=Vector2(p.x,p.z)
			nearest=minf(nearest,flat.length());tallest=maxf(tallest,p.y)
			var bearing=posmod(int(fposmod(flat.angle(),TAU)/TAU*360),360)
			if p.y>0:shore[bearing]=minf(shore[bearing],flat.length())
			crest[bearing]=maxf(crest[bearing],p.y)
			if absf(p.z)<.004 and p.x>0 and index in [0,landscape.sectors.size()-1]:seams[0 if index==0 else 1].append(p)
	check(crest.all(func(height):return height>.2),"continuous low mainland at every bearing")
	check(shore.max()-shore.min()>25.0,"bays and headlands break up the shoreline")
	# Ground points appear in both sectors; any point on only one side must be a tree above that ground.
	var ground=seams[0].filter(func(p):return seams[1].any(func(q):return p.distance_to(q)<.02))
	ground.sort_custom(func(a,b):return a.x<b.x)
	var loose=(seams[0]+seams[1]).filter(func(p):return not ground.any(func(q):return p.distance_to(q)<.02))
	check(ground.size()>20 and loose.all(func(p):return p.y>_ground_along(ground,p.x)+.01),"terrain closes without a seam")
	var shader=landscape.material.shader.code
	check(not "ALPHA=" in shader and not "depth_prepass_alpha" in shader,"backdrop stays opaque")
	check(nearest>9.5,"background stays outside boat navigation and play area")
	check(tallest>3.0 and tallest<6.0,"varied peaks leave room for sky")
	check(vertices<600000,"batched backdrop has a bounded geometry budget")
	board.day_seconds=150;board.advance_day(0);var day=landscape.material.get_shader_parameter("haze_color")
	board.day_seconds=450;board.advance_day(0);var night=landscape.material.get_shader_parameter("haze_color")
	check(night.get_luminance()<day.get_luminance(),"background haze darkens at night")
	game.queue_free();await create_timer(.2).timeout;await process_frame;await process_frame
	print("BACKGROUND_TEST: ",checks," checks, ",failures," failures, ",vertices," vertices")
	quit(1 if failures else 0)

func _ground_along(profile: Array,x: float) -> float:
	for i in range(1,profile.size()):
		if profile[i].x>=x:return lerpf(profile[i-1].y,profile[i].y,inverse_lerp(profile[i-1].x,profile[i].x,x))
	return profile[-1].y
