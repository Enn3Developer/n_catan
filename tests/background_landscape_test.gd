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
	check(landscape.islands.size()==12,"landscape surrounds every camera orbit")
	var vertices=0;var nearest=INF;var tallest=0.0
	for island in landscape.islands:
		check(island.mesh.get_surface_count()==1,"terrain and forest batched into one surface")
		var arrays=island.mesh.surface_get_arrays(0)
		vertices+=arrays[Mesh.ARRAY_VERTEX].size()
		for vertex in arrays[Mesh.ARRAY_VERTEX]:
			var p=island.transform*vertex
			nearest=minf(nearest,Vector2(p.x,p.z).length());tallest=maxf(tallest,p.y)
	check(nearest>9.5,"background stays outside boat navigation and play area")
	check(tallest>2.0,"mountains create a raised horizon")
	check(vertices<600000,"batched backdrop has a bounded geometry budget")
	board.day_seconds=150;board.advance_day(0);var day=landscape.material.get_shader_parameter("haze_color")
	board.day_seconds=450;board.advance_day(0);var night=landscape.material.get_shader_parameter("haze_color")
	check(night.get_luminance()<day.get_luminance(),"background haze darkens at night")
	game.queue_free();await process_frame;await process_frame
	print("BACKGROUND_TEST: ",checks," checks, ",failures," failures, ",vertices," vertices")
	quit(1 if failures else 0)
