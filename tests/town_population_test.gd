extends SceneTree
var checks=0
var failures=0
var world=preload("res://scripts/living_world.gd").new()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
	for city in [false,true]:
		var town=world.town(0,Color.CORAL,city);root.add_child(town)
		var residents=town.get_meta("dwellers")
		check(residents.size()==(16 if city else 6),"population matches building level")
		check(town.scale.y>1,"town buildings are taller")
		var homes=town.get_children().filter(func(node):return str(node.name).begins_with("TimberHouse"))
		for i in homes.size():
			for j in range(i+1,homes.size()):
				check(homes[i].position.distance_to(homes[j].position)>.1*sqrt(2)*(homes[i].scale.x+homes[j].scale.x),"neighboring cottage roofs stay separate")
		for mesh in town.find_children("*","MeshInstance3D",true,false):
			if residents.any(func(actor):return actor.root.is_ancestor_of(mesh)):continue
			mesh.create_trimesh_collision()
		await physics_frame;await physics_frame
		var first=residents[0].root.position
		var walked=false;var mixed_activity=false
		for time in range(0,120,2):
			world.animate_dwellers(residents,time,1)
			walked=walked or first.distance_to(residents[0].root.position)>.01
			var walking=residents.filter(func(actor):return actor.moving).size()
			mixed_activity=mixed_activity or (walking>0 and walking<residents.size())
			for i in residents.size():
				var actor=residents[i]
				var shape=CapsuleShape3D.new();shape.radius=.012;shape.height=.066
				var query=PhysicsShapeQueryParameters3D.new();query.shape=shape
				query.transform=Transform3D(Basis.IDENTITY,town.global_transform*(actor.root.position+Vector3.UP*.047))
				var hits=town.get_world_3d().direct_space_state.intersect_shape(query)
				check(hits.is_empty(),"resident street avoids buildings: %s / %d at %s"%[city,i,time])
				for j in range(i+1,residents.size()):
					check(actor.root.position.distance_to(residents[j].root.position)>.025,"residents remain separated")
		for time in range(0,30):
			world.animate_dwellers(residents,time,1)
			var positions=residents.map(func(actor):return actor.root.position)
			world.animate_dwellers(residents,time+.01,1)
			for i in residents.size():
				var delta=residents[i].root.position-positions[i]
				if delta.length()>.00005:
					check((-residents[i].root.basis.z.normalized()).dot(delta.normalized())>.98,"walking faces the direction of travel")
		check(walked,"residents walk through town")
		check(mixed_activity,"residents have independent walking and resting schedules")
		world.animate_dwellers(residents,40,0)
		check(residents.all(func(actor):return not actor.root.visible),"residents rest at night")
		town.free();await physics_frame
	var board=load("res://scenes/board.tscn").instantiate();root.add_child(board)
	await process_frame
	var rules=CatanRules.new();rules.create(["A","B","C"],9047)
	var data=rules.snapshot(0);data.vertices[0].owner=0;data.vertices[0].level=1
	board.build(data)
	check(is_equal_approx(board.TILE_SIZE*2,50),"50 metre hex diameter")
	check(board.dwellers.size()==6,"board registers settlement residents")
	var old=board.dwellers[0].root
	data=data.duplicate(true);data.vertices[0].level=2;board.refresh(data)
	check(not is_instance_valid(old) and board.dwellers.size()==16,"city upgrade replaces residents without stale actors")
	board.reduce_motion=true;var before=board.dwellers[0].root.position;board._process(1)
	check(board.dwellers[0].root.position.is_equal_approx(before),"reduced motion freezes residents")
	data=data.duplicate(true);data.vertices[0].owner=-1;board.refresh(data)
	check(board.dwellers.is_empty(),"removing town clears population")
	board.queue_free();await process_frame
	print("TOWN_POPULATION_TEST: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
