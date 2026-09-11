extends SceneTree
var checks=0
var failures=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await create_timer(.5).timeout
	game.set_process(false);var board=game.board;board.set_process(false)
	var traffic=board.sea_traffic
	check(traffic.fleet.size()==3 and not traffic.ports.is_empty(),"boats have routes and port destinations")
	var starts=board.boats.map(func(boat):return boat.position)
	var destinations={};var max_step=0.0;var grounded=false
	var forward_samples=0;var reverse_samples=0
	for frame in 4500:
		var previous=board.boats.map(func(boat):return boat.position)
		traffic.animate(.2,frame*.2)
		for i in traffic.fleet.size():
			var ship=traffic.fleet[i];var p=Vector2(ship.boat.position.x,ship.boat.position.z)
			max_step=maxf(max_step,p.distance_to(Vector2(previous[i].x,previous[i].z)))
			var movement=ship.boat.position-previous[i];movement.y=0
			if movement.length()>.001:
				if ship.boat.basis.z.dot(movement.normalized())>.8:forward_samples+=1
				else:reverse_samples+=1
			if traffic.grid.is_point_solid(traffic.cell_for(p)):grounded=true
			if ship.port>=0 and ship.wait>0 and ship.visits>0:destinations[ship.port]=true
	check(forward_samples>reverse_samples*4,"boats travel bow-first for most sailing samples")
	check(not grounded,"all sampled routes avoid land, rocks and piers")
	check(max_step<=.031,"movement remains smooth without teleporting")
	check(destinations.size()>=3,"boats visit different randomly selected ports")
	for i in traffic.fleet.size():
		check(traffic.fleet[i].visits>0,"each boat approaches a port")
		check(board.boats[i].position.distance_to(starts[i])>1,"boats sail away from their initial positions")
	board.elapsed=900;board._update_boat_wakes()
	var wakes=board.sea_material.get_shader_parameter("boat_sources")
	check(absf(wakes[0].x-board.boats[0].global_position.x)<.001,"water wake follows moving boat")
	board.day_seconds=150;board.advance_day(0)
	check(not board.beacon.visible and board.beacon_spot.light_energy==0,"lighthouse beam off in daylight")
	board.day_seconds=450;board.advance_day(0)
	check(board.beacon.visible and board.beacon_spot.light_energy>0,"night illuminates lighthouse")
	var settings=CatanSettings.new("user://day-night-test.cfg")
	settings.set_value("day_night_cycle",false)
	check(not CatanSettings.new(settings.path).values.day_night_cycle,"cycle preference persists")
	board.apply_preferences(settings.values)
	check(board.daylight==1 and not board.beacon.visible,"cycle off immediately restores daylight")
	var fixed_sun=board.get_node("Sun").rotation
	board.advance_day(30)
	check(board.day_seconds==480 and board.get_node("Sun").rotation.is_equal_approx(fixed_sun),"clock advances while sun stays fixed")
	settings.set_value("day_night_cycle",true);board.apply_preferences(settings.values)
	check(board.daylight==0 and board.beacon.visible,"cycle on restores current night")
	var band=board.living_world.robber_band(0,board.art)
	var average=Vector2.ZERO
	for actor in band.actors:average+=actor.origin/4.0
	check(average.length()<.001,"robber group centered on tile")
	check(Vector2(band.root.get_node("Campfire").position.x,band.root.get_node("Campfire").position.z).length()<.001,"robber campfire at tile center")
	band.root.free()
	var angle=board.beacon.rotation.y;board.elapsed+=2;board._animate_beacon()
	check(absf(angle-board.beacon.rotation.y)>.1,"night beam rotates")
	board.reduce_motion=true;var position=board.boats[0].position;angle=board.beacon.rotation.y
	board._process(1)
	check(board.boats[0].position.is_equal_approx(position) and is_equal_approx(board.beacon.rotation.y,angle),"reduce motion freezes boats and beacon")
	var rules=CatanRules.new();rules.create(["A","B","C","D","E","F"],903)
	board.build(rules.snapshot(0));grounded=false
	for frame in 4500:
		traffic.animate(.2,frame*.2)
		for ship in traffic.fleet:
			var p=Vector2(ship.boat.position.x,ship.boat.position.z)
			if traffic.grid.is_point_solid(traffic.cell_for(p)):grounded=true
	check(not grounded,"extended island routes avoid obstacles")
	check(traffic.fleet.all(func(ship):return ship.visits>0),"all boats visit ports on six-player island")
	game.queue_free();await create_timer(.2).timeout;await process_frame;await process_frame
	print("SEA_TRAFFIC_TEST: ",checks," checks, ",failures," failures, visited ",destinations.size()," ports")
	quit(1 if failures else 0)
