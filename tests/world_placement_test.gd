extends SceneTree
var failures=0
var checks=0
var art=CatanTileArt.new()
var world=preload("res://scripts/living_world.gd").new()
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func hits(stage: Node3D,shape: Shape3D,at: Vector3) -> Array:
	var query=PhysicsShapeQueryParameters3D.new()
	query.shape=shape;query.transform=Transform3D(Basis.IDENTITY,stage.global_transform*at)
	return stage.get_world_3d().direct_space_state.intersect_shape(query,16)
func names(collisions: Array) -> String:
	return str(collisions.map(func(hit):return hit.collider.name if hit.collider.name=="NumberToken" else hit.collider.get_parent().name))
func run():
	var prefs=CatanSettings.DEFAULTS.duplicate(true)
	for kind in 6:
		for variant in 2:
			var stage=Node3D.new();root.add_child(stage)
			var scene=art.instantiate(kind,variant,prefs);stage.add_child(scene)
			for mesh in scene.find_children("*","MeshInstance3D",true,false):
				if str(mesh.name).begins_with("GroundCover") or str(mesh.name).begins_with("Micro"):continue
				mesh.create_trimesh_collision()
			var actors=world.populate(stage,kind,variant,art)
			for prop in stage.get_children():
				if not (str(prop.name).begins_with("TimberHouse") or str(prop.name).begins_with("Worksite")):continue
				for mesh in prop.find_children("*","MeshInstance3D",true,false):mesh.create_trimesh_collision()
			await physics_frame;await physics_frame
			var token=CylinderShape3D.new();token.radius=.19;token.height=.09
			var marker=CatanWorldLayout.point(CatanWorldLayout.data.token)
			var token_position=Vector3(marker.x,.25,marker.y)
			var overlap=hits(stage,token,token_position)
			check(overlap.is_empty(),"token clear %d/%d: %s"%[kind,variant,names(overlap)])
			var token_body=StaticBody3D.new();token_body.name="NumberToken";stage.add_child(token_body)
			token_body.position=token_position
			var token_shape=CollisionShape3D.new();token_shape.shape=token;token_body.add_child(token_shape)
			await physics_frame;await physics_frame
			var town=CylinderShape3D.new();town.radius=.40;town.height=.65
			for corner in 6:
				var a=PI/6+corner*PI/3
				overlap=hits(stage,town,Vector3(cos(a),.43,sin(a)))
				check(overlap.is_empty(),"city clearance %d/%d corner %d: %s"%[kind,variant,corner,names(overlap)])
			var body=CapsuleShape3D.new();body.radius=.035;body.height=.16
			if kind!=2:
				for light in [1.0,.75,.5,.25,.1]:
					world.animate(actors,5,art,light)
					for actor in actors:
						overlap=hits(stage,body,actor.root.position+Vector3.UP*.11)
						check(overlap.is_empty(),"worker route clear %d/%d light %.2f: %s"%[kind,variant,light,names(overlap)])
			else:
				check(scene.find_children("*Wool*","MeshInstance3D",true,false).is_empty(),"no duplicate baked sheep")
				var grass_points=[]
				for mesh in scene.find_children("GroundCover*Grass*","MeshInstance3D",true,false):
					for surface in mesh.mesh.get_surface_count():
						for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
							var p=mesh.global_transform*vertex;grass_points.append(Vector2(p.x,p.z))
				for origin in CatanWorldLayout.biome(kind).workers:
					var nearest=INF;var p=CatanWorldLayout.point(origin)
					for grass in grass_points:nearest=minf(nearest,p.distance_to(grass))
					check(nearest<.075,"grass grows in sheep grazing area %d %s" % [variant,p])
				var sheep_body=CapsuleShape3D.new();sheep_body.radius=.023;sheep_body.height=.062
				for time in [0,9,18,27]:
					for light in [1.0,.5,0.0]:
						world.animate(actors,time,art,light)
						for actor in actors:
							var contacts=hits(stage,sheep_body,actor.root.position+Vector3.UP*.045)
							check(contacts.is_empty(),"sheep route avoids solid scenery %d: %s"%[variant,names(contacts)])
				for light in [1.0,.75,.5,.25,0.0]:
					world.animate(actors,9,art,light)
					for i in actors.size():
						for j in range(i+1,actors.size()):
							check(actors[i].root.position.distance_to(actors[j].root.position)>.14,"sheep remain apart going to their sleeping places")
			var huts=stage.find_children("TimberHouse*","Node3D",true,false)
			check(huts.size()==(0 if kind in [2,4,5] else 1),"one planned cottage per work tile")
			stage.free();await physics_frame
	var dock=world.harbor(-1);root.add_child(dock)
	for mesh in dock.find_children("*","MeshInstance3D",true,false):mesh.create_trimesh_collision()
	await physics_frame;await physics_frame
	var footprint=CylinderShape3D.new();footprint.radius=.40;footprint.height=.65
	for side in [-1,1]:
		var collisions=hits(dock,footprint,Vector3(side*.5,.43,0))
		check(collisions.is_empty(),"harbor leaves room for coastal cities: "+names(collisions))
	dock.free()
	print("WORLD_PLACEMENT_TEST: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
