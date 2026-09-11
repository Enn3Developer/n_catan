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
	for island in landscape.sectors:
		check(island.mesh.get_surface_count()==1,"terrain and forest batched into one surface")
		var arrays=island.mesh.surface_get_arrays(0)
		vertices+=arrays[Mesh.ARRAY_VERTEX].size()
		for vertex in arrays[Mesh.ARRAY_VERTEX]:
			var p=island.transform*vertex
			nearest=minf(nearest,Vector2(p.x,p.z).length());tallest=maxf(tallest,p.y)
	var shore_min=INF;var shore_max=0.0
	for step in 360:
		var angle=TAU*step/360.0
		shore_min=minf(shore_min,landscape.shore_radius(angle));shore_max=maxf(shore_max,landscape.shore_radius(angle))
		check(landscape.terrain_point(angle,.35).y>.2,"continuous low mainland at every bearing")
	check(shore_max-shore_min>25.0,"bays and headlands break up the shoreline")
	check(landscape.terrain_point(0,.5).is_equal_approx(landscape.terrain_point(TAU,.5)),"terrain closes without a seam")
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
