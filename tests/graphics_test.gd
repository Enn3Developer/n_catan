extends SceneTree
var game
var checks=0
var failures=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func change(key: String,value: Variant):
	game.preferences.set_value(key,value)
	game._apply_preferences()
func run():
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(2).timeout
	game.preferences.reset()
	game._apply_preferences()
	game._solo()
	game.net.start_game()
	game.net.paused=true
	var board=game.board
	var env=board.get_node("WorldEnvironment").environment
	check(board.terrain.scale==Vector3.ONE*CatanBoard.TILE_SIZE,"enlarged board geometry")
	check(board.ocean.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"ocean cannot self-shadow")
	check(board.tile_nodes.size()==19,"nineteen detailed tiles")
	var vertices=[]
	var cover=[]
	for detail in 4:
		change("model_quality",detail)
		change("foliage_quality",detail)
		vertices.append(board.tile_nodes[0].ground.mesh.surface_get_array_len(0))
		var visible=0
		for tile in board.tile_nodes:
			for node in tile.diorama.find_children("GroundCover*","MeshInstance3D",true,false):
				if node.visible:visible+=1
		cover.append(visible)
	for i in 3:
		check(vertices[i+1]>vertices[i],"terrain detail increases at level "+str(i+1))
		check(cover[i+1]>cover[i],"vegetation density increases at level "+str(i+1))
	for tier in 3:
		change("texture_quality",tier)
		var texture=board.tile_nodes[0].ground.material_override.get_shader_parameter("albedo_map")
		check(texture.get_width()==[512,1024,2048][tier],"actual texture resolution tier "+str(tier))
		check(texture.get_image().has_mipmaps(),"texture mipmaps tier "+str(tier))
		for node in board.scenery.find_children("*","MeshInstance3D",true,false):
			if node.has_meta("pbr_surface"):
				check(node.material_override.get_shader_parameter("albedo_map").get_width()==texture.get_width(),"scenery texture tier updates")
	for aa in 6:
		change("anti_aliasing",aa)
		check(root.msaa_3d==[0,0,1,2,3,0][aa],"MSAA level "+str(aa))
		check(root.screen_space_aa==(1 if aa==1 else 0),"FXAA level "+str(aa))
		check(root.use_taa==(aa==5),"TAA level "+str(aa))
		await create_timer(.15).timeout
	for gi in 4:
		change("global_illumination",gi)
		check(env.ssil_enabled==(gi==1),"screen space bounce "+str(gi))
		check(env.sdfgi_enabled==(gi>=2),"SDFGI enabled "+str(gi))
		if gi>=2:check(is_equal_approx(env.sdfgi_min_cell_size,.4 if gi==2 else .2),"SDFGI resolution")
		await create_timer(1).timeout
	for level in 3:
		change("ambient_occlusion",level)
		change("reflections",level)
		check(env.ssao_enabled==(level>0),"AO toggles")
		check(env.ssr_enabled==(level>0),"SSR toggles")
		check(env.ssr_max_steps==(32 if level==1 else 96),"SSR ray steps")
	for level in 5:
		change("shadow_quality",level)
		check(board.get_node("Sun").shadow_enabled==(level>0),"shadow toggles")
	for level in 4:
		change("water_quality",level)
		check(board.ocean.mesh.subdivide_width==[64,128,224,320][level],"water tessellation")
		check(board.sea_material.get_shader_parameter("water_quality")==level,"water shader quality")
	for enabled in [false,true]:
		for key in ["bloom","atmosphere","depth_of_field","show_fps"]:change(key,enabled)
		check(env.glow_enabled==enabled and env.fog_enabled==enabled,"bloom and atmosphere")
		check(board.camera.attributes.dof_blur_far_enabled==enabled,"depth of field")
		check(board.fps_label.visible==enabled,"FPS overlay")
	change("particles",0)
	check(not board.pollen.visible and not board.pollen.emitting,"particles off immediately")
	change("particles",2)
	check(board.pollen.visible and board.pollen.emitting,"particles enabled")
	change("wind",.3)
	check(is_equal_approx(board.sea_material.get_shader_parameter("motion_speed"),.3),"water wind speed")
	change("reduce_motion",true)
	check(board.sea_material.get_shader_parameter("motion_speed")==0 and not board.pollen.visible,"reduced motion overrides effects")
	for material in board.art.materials.values():
		if material is ShaderMaterial and material.shader.resource_path.ends_with("premium_foliage.gdshader"):
			check(material.get_shader_parameter("motion_speed")==0,"foliage motion disabled")
	change("exposure",.8)
	check(is_equal_approx(env.tonemap_exposure,.8),"exposure applies")
	change("render_scale",.75)
	change("upscaling",1)
	check(is_equal_approx(root.scaling_3d_scale,.75) and root.scaling_3d_mode==Viewport.SCALING_3D_MODE_FSR,"render scale and FSR")
	change("frame_limit",2)
	check(Engine.max_fps==60,"frame limiter")
	change("frame_limit",0)
	change("anisotropy",2)
	check(game.preferences.applied_anisotropy==2,"native anisotropy applied")
	game._open_settings()
	for spec in game.modal.OPTIONS:
		check(game.modal.controls.has(spec[2]),"native setting control "+spec[2])
	change("quality",1)
	game.modal.refresh()
	check(game.modal.controls.quality.selected==1 and game.preferences.values.model_quality==1,"preset applies coordinated values")
	change("texture_quality",2)
	game.modal.refresh()
	check(game.modal.controls.quality.selected==4,"individual settings mark Custom")
	var saved=CatanSettings.new()
	check(saved.values==game.preferences.values,"all preferences survive disk reload")
	game.modal.get_node("%ResetSettings").pressed.emit()
	check(game.preferences.values==CatanSettings.DEFAULTS,"reset restores all controls")
	game._close_modal()
	var start=board.camera.position
	var zoom=InputEventMouseButton.new()
	zoom.button_index=MOUSE_BUTTON_WHEEL_UP
	zoom.pressed=true
	board._unhandled_input(zoom)
	check(board.camera_zoom<1 and board.camera.position!=start,"wheel zoom")
	# Pan from the center; a headless cursor can put zoom anchoring at the clamp.
	board.reset_camera()
	var pan=InputEventMouseMotion.new()
	pan.button_mask=MOUSE_BUTTON_MASK_MIDDLE
	pan.relative=Vector2(25,10)
	var focus=board.camera_focus
	board._unhandled_input(pan)
	check(board.camera_focus!=focus,"middle drag pan")
	board.reset_camera()
	check(board.camera_zoom==1 and board.camera_focus==Vector3(0,0,1),"Home framing")
	game._toggle_inspection()
	check(game.inspection_mode and not game.screen.visible and game.net.paused,"inspection hides HUD and pauses solo")
	game._toggle_inspection()
	check(not game.inspection_mode and game.screen.visible and not game.net.paused,"inspection resumes solo")
	var bad=ConfigFile.new()
	bad.set_value("preferences","texture_quality",99)
	bad.set_value("preferences","wind",-100)
	bad.set_value("preferences","render_scale",NAN)
	bad.save("user://invalid.cfg")
	var sanitized=CatanSettings.new("user://invalid.cfg")
	check(sanitized.values.texture_quality==2 and sanitized.values.wind==0 and sanitized.values.render_scale==1,"invalid saved values sanitized")
	var old=ConfigFile.new()
	old.set_value("preferences","quality",0)
	old.save("user://legacy.cfg")
	var migrated=CatanSettings.new("user://legacy.cfg")
	check(migrated.values.model_quality==0 and migrated.values.global_illumination==0,"legacy preset migration")
	game.net.leave()
	game.queue_free()
	await process_frame
	print("GRAPHICS_TEST: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
