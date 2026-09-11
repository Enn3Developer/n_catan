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
	for frame in 4500:
		var previous=board.boats.map(func(boat):return boat.position)
		traffic.animate(.2,frame*.2)
		for i in traffic.fleet.size():
			var ship=traffic.fleet[i];var p=Vector2(ship.boat.position.x,ship.boat.position.z)
			max_step=maxf(max_step,p.distance_to(Vector2(previous[i].x,previous[i].z)))
			if traffic.grid.is_point_solid(traffic.cell_for(p)):grounded=true
			if ship.port>=0 and ship.wait>0 and ship.visits>0:destinations[ship.port]=true
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
	game.queue_free();await process_frame;await process_frame
	print("SEA_TRAFFIC_TEST: ",checks," checks, ",failures," failures, visited ",destinations.size()," ports")
	quit(1 if failures else 0)
