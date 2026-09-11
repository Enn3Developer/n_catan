extends SceneTree
var failures=0
var checks=0
func check(ok,message):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await create_timer(.5).timeout
	var board=game.board
	var data=board.state.duplicate(true)
	data.vertices[5].owner=0;data.vertices[5].level=2
	data.vertices[0].owner=1;data.vertices[0].level=1
	board.refresh(data)
	check(board.band_actors.size()==4,"robber is four people")
	var city=board.pieces_root.find_child("MedievalCity",true,false)
	var village=board.pieces_root.find_child("MedievalVillage",true,false)
	check(city.find_children("NightLight*","OmniLight3D",true,false).size()==3,"city has three local light sources")
	check(village.find_children("NightLight*","OmniLight3D",true,false).size()==1,"settlement has fewer local lights")
	board.day_seconds=150;board.advance_day(0)
	check(board.night_lights.all(func(light):return not light.visible and light.light_energy==0),"lights off at noon")
	var farmer=board.actors.filter(func(actor):return actor.type=="worker")[0]
	var sheep=board.actors.filter(func(actor):return actor.type=="sheep")[0]
	check(farmer.root.visible,"workers active by day")
	var daytime=sheep.root.position
	board.day_seconds=450;board.advance_day(0)
	check(board.night_lights.all(func(light):return light.visible and light.light_energy>0),"lights on at midnight")
	check(not farmer.root.visible,"workers indoors at night")
	check(sheep.root.visible and sheep.body.position.y<.06 and sheep.root.scale==Vector3.ONE*board.living_world.TILE_ACTOR_SCALE and sheep.root.position.distance_to(daytime)>.1,"sheep gather and rest at night")
	var limb=sheep.limbs[0].rotation
	board.living_world.animate(board.actors,40,board.art,0)
	check(sheep.limbs[0].rotation==limb,"sleeping sheep do not walk")
	check(board.band_actors.all(func(actor):return actor.root.visible),"robber stays identifiable at night")
	board.day_seconds=150;board.advance_day(0)
	check(farmer.root.visible and is_equal_approx(sheep.root.scale.y,board.living_world.TILE_ACTOR_SCALE),"dawn restores work and grazing")
	board.day_seconds=450;board.advance_day(0);board.refresh(data)
	check(board.night_lights.all(func(light):return light.visible),"snapshot rebuild preserves night lights")
	data.robber=(data.robber+1)%data.tiles.size();board.refresh(data)
	var band=board.pieces_root.get_node("RobberBand")
	check(band.position==Vector3(data.tiles[data.robber].x,0,data.tiles[data.robber].z),"band follows authoritative robber tile")
	board.reduce_motion=true;var clock=board.elapsed;board._process(1)
	check(clock==board.elapsed,"reduced motion keeps lighting without animation")
	if DisplayServer.get_name()!="headless":
		game.ui.visible=false;board.show_labels=false
		var vertex=data.vertices[5]
		board.view_region=Rect2();board.camera_focus=Vector3(vertex.x*board.TILE_SIZE,.24*board.TILE_SIZE,vertex.z*board.TILE_SIZE);board.camera_zoom=.19;board._update_camera()
		for time in [150,450]:
			board.day_seconds=time;board.advance_day(0)
			await create_timer(.7).timeout;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/catan-city-%s.png" % ("day" if time==150 else "night"))
		var tile=data.tiles[data.robber]
		board.camera_focus=Vector3(tile.x*board.TILE_SIZE,.24*board.TILE_SIZE,(tile.z+.82)*board.TILE_SIZE);board.camera_zoom=.14;board._update_camera()
		await create_timer(.7).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/catan-band-night.png")
	game.queue_free();await create_timer(.2).timeout;await process_frame
	print("NIGHT_WORLD_TEST: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
