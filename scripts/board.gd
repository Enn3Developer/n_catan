class_name CatanBoard
extends Node3D
signal picked(kind: String,id: int)
const TILE_SIZE=25.0 # Regular hexes: 50 m tip to tip, 43.3 m across flats.
const COLORS=[Color("488963"),Color("bd7250"),Color("8fab60"),Color("c7a456"),Color("7a8b99"),Color("d7bf87")]
const PLAYERS=[Color("ed815d"),Color("65bfcb"),Color("d9b76c"),Color("b697d7"),Color("7dcc83"),Color("d1aa87")]
var camera: Camera3D
var terrain: Node3D
var pieces_root: Node3D
var markers: Node3D
var state={}
var mode=""
var seat=-1
var board_scale=1.0
var yaw=0.0
var pitch=0.745
var hover=-1
var targets=[]
var marker_nodes=[]
var cache=[]
var scenery: Node3D
var background_landscape: Node3D
var clouds=[]
var boats=[]
var sea_traffic=preload("res://scripts/sea_traffic.gd").new()
var beacon: Node3D
var beacon_lamp: MeshInstance3D
var beacon_beam: MeshInstance3D
var beacon_spot: SpotLight3D
var terrain_noise: NoiseTexture2D
var elapsed=0.0
var windmills=[]
var birds=[]
var reduce_motion=false
var camera_speed=1.0
var board_labels=[]
var label_layer: CanvasLayer
var label_font: Font
var sea_material: ShaderMaterial
var vegetation=[]
var quality=2
var production_rings=[]
var art=CatanTileArt.new()
var cosmetics=CatanCosmetics.new()
var render_values=CatanSettings.DEFAULTS.duplicate()
var tile_nodes=[]
var ocean: MeshInstance3D
var camera_focus=Vector3(0,0,1.0)
var camera_zoom=1.0
var last_water_quality=-1
var last_shadow_quality=-1
var pollen: CPUParticles3D
var fps_label: Label
var show_labels=true
var view_region=Rect2()
var day_seconds=150.0
var active_dice: CatanDiceThrow
var living_world=preload("res://scripts/living_world.gd").new()
var actors=[]
var harbors=[]
var band_actors=[]
var dwellers=[]
var road_travel=preload("res://scripts/road_travel.gd").new()
var night_lights=[]
var daylight=1.0

func _ready():
	if "--server" in OS.get_cmdline_user_args():
		set_process(false)
		return
	camera=get_node_or_null("CameraRig/Camera")
	if camera==null:
		camera=Camera3D.new()
		add_child(camera)
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	camera.fov=35
	camera.size=12.2
	camera.far=9000
	camera.near=.08
	_update_camera()
	var world=get_node_or_null("WorldEnvironment")
	if world==null:
		world=WorldEnvironment.new()
		add_child(world)
	var env=Environment.new()
	env.background_mode=Environment.BG_SKY
	var sky=Sky.new()
	var atmosphere=ProceduralSkyMaterial.new()
	atmosphere.sky_top_color=Color("4d7389")
	atmosphere.sky_horizon_color=Color("ccd3c7")
	atmosphere.ground_bottom_color=Color("174352")
	atmosphere.ground_horizon_color=Color("bdd6d3")
	sky.sky_material=atmosphere
	env.sky=sky
	env.fog_enabled=true
	env.fog_light_color=Color("b2d0ce")
	env.fog_density=0.0015*2.2/TILE_SIZE
	env.background_color=Color("102b3c")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color=Color("b7d4e0")
	env.ambient_light_energy=0.55
	env.tonemap_mode=Environment.TONE_MAPPER_ACES
	env.tonemap_white=4.0
	env.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	world.environment=env
	var light=get_node_or_null("Sun")
	if light==null:
		light=DirectionalLight3D.new()
		add_child(light)
	light.rotation_degrees=Vector3(-38,-34,0)
	light.light_color=Color("ffe4b9")
	light.light_energy=1.65
	light.light_angular_distance=.6
	light.shadow_bias=.10
	light.shadow_normal_bias=1.5
	light.shadow_enabled=true
	light.directional_shadow_max_distance=85*TILE_SIZE/2.2
	light.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	terrain=_branch("Terrain")
	pieces_root=_branch("Buildings")
	markers=_branch("PlacementMarkers")
	scenery=_branch("Scenery")
	label_layer=CanvasLayer.new()
	label_layer.layer=0
	add_child(label_layer)
	label_font=load("res://assets/fonts/FiraSans-Medium.ttf")

	terrain_noise=NoiseTexture2D.new()
	var noise=FastNoiseLite.new()
	noise.seed=8531
	noise.frequency=0.045
	noise.fractal_octaves=4
	terrain_noise.noise=noise
	terrain_noise.width=256
	terrain_noise.height=256
	terrain_noise.seamless=true
	var water=PlaneMesh.new()
	water.size=Vector2(7000,7000)
	water.subdivide_width=150
	water.subdivide_depth=150
	ocean=MeshInstance3D.new()
	ocean.mesh=water
	ocean.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var water_material=ShaderMaterial.new()
	water_material.shader=load("res://shaders/water.gdshader")
	ocean.material_override=water_material
	sea_material=water_material
	ocean.position.y=-.027*TILE_SIZE
	add_child(ocean)
	for branch in [terrain,pieces_root,markers]:branch.scale=Vector3.ONE*TILE_SIZE
	var stats=CanvasLayer.new()
	stats.layer=5
	add_child(stats)
	fps_label=Label.new()
	fps_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	fps_label.offset_left=18
	fps_label.offset_top=-25
	fps_label.add_theme_font_size_override("font_size",13)
	fps_label.add_theme_color_override("font_outline_color",Color("10232b"))
	fps_label.add_theme_constant_override("outline_size",5)
	stats.add_child(fps_label)
	pollen=CPUParticles3D.new()
	pollen.name="SunlitPollen"
	pollen.amount=96
	pollen.lifetime=12
	pollen.preprocess=4
	pollen.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX
	pollen.emission_box_extents=Vector3(8,1.6,8)
	pollen.position.y=1.8
	pollen.direction=Vector3(.2,.1,.1)
	pollen.gravity=Vector3.ZERO
	pollen.initial_velocity_min=.03
	pollen.initial_velocity_max=.09
	var mote=SphereMesh.new()
	mote.radius=.007
	mote.height=.014
	mote.radial_segments=4
	mote.rings=2
	var dust=mat(Color("eadbb7"))
	dust.emission_enabled=true
	dust.emission=Color("423b29")
	mote.material=dust
	pollen.mesh=mote
	pollen.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pollen)
	_world_props()

func mat(color: Color) -> StandardMaterial3D:
	var m=StandardMaterial3D.new()
	m.albedo_color=color
	m.roughness=0.85
	return m

func mesh(shape: Mesh,color: Color) -> MeshInstance3D:
	var node=MeshInstance3D.new()
	node.mesh=shape
	node.material_override=mat(color)
	return node

func cylinder(radius: float,height: float,color: Color,sides: int=6) -> MeshInstance3D:
	var shape=CylinderMesh.new()
	shape.top_radius=radius
	shape.bottom_radius=radius
	shape.height=height
	shape.radial_segments=sides
	return mesh(shape,color)

func box(size: Vector3,color: Color) -> MeshInstance3D:
	var shape=CatanMiniature.bevel_box(size)
	return mesh(shape,color)

func _branch(branch_name: String) -> Node3D:
	var branch=get_node_or_null(branch_name)
	if branch==null:
		branch=Node3D.new()
		branch.name=branch_name
		add_child(branch)
	return branch

func label3(text: String,pos: Vector3,size: int,color: Color=Color("fff1ce"),resource_id: int=-1) -> Node3D:
	var anchor=Node3D.new()
	anchor.position=pos
	var label=Label.new()
	label.text=text
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font",label_font)
	label.add_theme_font_size_override("font_size",20 if size>30 else 13)
	label.add_theme_color_override("font_color",color)
	if text.contains(":"):
		label.add_theme_color_override("font_outline_color",Color("133a41"))
		label.add_theme_constant_override("outline_size",4)
	var display: Control=label
	if resource_id>=0:
		var row=HBoxContainer.new();row.add_theme_constant_override("separation",3)
		row.mouse_filter=Control.MOUSE_FILTER_IGNORE
		CatanIcons.icon(row,CatanIcons.RESOURCES[resource_id],22)
		row.add_child(label);display=row
	label_layer.add_child(display)
	board_labels.append({"anchor":anchor,"label":display,"port":text.contains(":")})
	return anchor

func apply_preferences(values: Dictionary):
	var old=render_values.duplicate()
	render_values=values.duplicate()
	reduce_motion=values.reduce_motion
	quality=values.quality
	camera_speed=values.camera_speed
	art.configure(values)
	var geometry_changed=tile_nodes.size()>0 and (old.model_quality!=values.model_quality or old.texture_quality!=values.texture_quality or old.foliage_quality!=values.foliage_quality)
	if geometry_changed:
		for tile in tile_nodes:
			tile.ground.mesh=art.terrain(tile.kind,values.model_quality)
			tile.ground.material_override=art.ground(tile.kind,tile.index)
			tile.cliff.material_override=art.cliff()
			art.apply_instance(tile.diorama,values)
	if old.texture_quality!=values.texture_quality:
		for node in find_children("*","MeshInstance3D",true,false):
			if node.has_meta("pbr_surface"):
				node.material_override=art.surface(node.get_meta("pbr_surface"),null,values)
	art.animate(values)
	var light=get_node_or_null("Sun")
	if light:
		light.shadow_enabled=values.shadow_quality>0
		if last_shadow_quality!=values.shadow_quality:
			RenderingServer.directional_shadow_atlas_set_size([1024,1024,2048,4096,8192][values.shadow_quality],true)
			RenderingServer.directional_soft_shadow_filter_set_quality([0,0,1,3,4][values.shadow_quality])
			last_shadow_quality=values.shadow_quality
	var forward=RenderingServer.get_current_rendering_method()=="forward_plus"
	var world=get_node_or_null("WorldEnvironment")
	if world:
		var env=world.environment
		env.fog_enabled=values.atmosphere
		env.fog_density=.0018*2.2/TILE_SIZE
		env.fog_sun_scatter=.25
		env.tonemap_exposure=values.exposure
		env.glow_enabled=values.bloom
		env.glow_intensity=.18
		env.glow_bloom=.025
		env.glow_hdr_threshold=1.8
		env.ssao_enabled=forward and values.ambient_occlusion>0
		env.ssao_radius=.42
		env.ssao_intensity=1.05
		env.ssao_light_affect=.22
		env.ssao_detail=.8
		if forward:RenderingServer.environment_set_ssao_quality(1 if values.ambient_occlusion==1 else 3,values.ambient_occlusion==1,.5,2,70,100)
		env.ssil_enabled=forward and values.global_illumination==1
		env.ssil_radius=2.2
		env.ssil_intensity=.45
		env.sdfgi_enabled=forward and values.global_illumination>=2
		env.sdfgi_min_cell_size=.4 if values.global_illumination==2 else .2
		env.sdfgi_use_occlusion=true
		env.sdfgi_energy=.85
		env.ssr_enabled=forward and values.reflections>0
		env.ssr_max_steps=32 if values.reflections==1 else 96
		env.ssr_depth_tolerance=.25
		if camera.attributes==null:camera.attributes=CameraAttributesPractical.new()
		camera.attributes.dof_blur_far_enabled=values.depth_of_field and forward
		camera.attributes.dof_blur_near_enabled=values.depth_of_field and forward
		camera.attributes.dof_blur_amount=.065
		_update_camera_focus()
	sea_material.set_shader_parameter("motion_speed",0.0 if reduce_motion else values.wind)
	sea_material.set_shader_parameter("water_quality",values.water_quality)
	if last_water_quality!=values.water_quality:
		var plane=PlaneMesh.new()
		plane.size=Vector2(7000,7000)
		plane.subdivide_width=[64,128,224,320][values.water_quality]
		plane.subdivide_depth=plane.subdivide_width
		ocean.mesh=plane
		last_water_quality=values.water_quality
	for cloud in clouds:cloud.visible=false
	for material in vegetation:material.set_shader_parameter("motion_speed",0.0 if reduce_motion else values.wind)
	for smoke in find_children("Smoke","CPUParticles3D",true,false):
		smoke.emitting=values.particles>0 and not reduce_motion
		smoke.visible=smoke.emitting
		var amount=4 if values.particles==1 else 12
		if smoke.amount!=amount:smoke.amount=amount
	pollen.emitting=values.particles>0 and not reduce_motion
	pollen.visible=pollen.emitting
	var pollen_amount=32 if values.particles<2 else 112
	if pollen.amount!=pollen_amount:pollen.amount=pollen_amount
	fps_label.visible=values.show_fps
	advance_day(0)
	CatanDiagnostics.event("board.settings.complete")

func build(data: Dictionary):
	CatanDiagnostics.event("board.build.begin","tiles=%d"%data.get("tiles",[]).size())
	if is_instance_valid(active_dice):active_dice.queue_free()
	day_seconds=data.get("world_seconds",150.0)
	state=data
	board_scale=1.32 if data.get("extension",false) else 1.0
	scenery.scale=Vector3.ONE*board_scale*TILE_SIZE
	_update_camera()
	for entry in board_labels: entry.label.free()
	board_labels=[]
	windmills=[]
	vegetation=[]
	for n in terrain.get_children(): n.free()
	tile_nodes=[]
	actors=[]
	harbors=[]
	art.configure(render_values)
	var centers=PackedVector2Array()
	for i in state.tiles.size():
		var t=state.tiles[i]
		centers.append(Vector2(t.x,t.z)*TILE_SIZE)
		var root=Node3D.new()
		root.name="Tile_%02d_%s" % [i,CatanTileArt.BIOMES[t.kind]]
		root.position=Vector3(t.x,0,t.z)
		terrain.add_child(root)
		var side=MeshInstance3D.new()
		side.name="StratifiedCliff"
		side.mesh=art.cliff_mesh(i)
		side.material_override=art.cliff()
		root.add_child(side)
		var top=MeshInstance3D.new()
		top.name="SculptedGround"
		top.mesh=art.terrain(t.kind,render_values.model_quality)
		top.material_override=art.ground(t.kind,i)
		root.add_child(top)
		var diorama=art.instantiate(t.kind,i,render_values)
		root.add_child(diorama)
		actors.append_array(living_world.populate(root,t.kind,i,art))
		tile_nodes.append({"root":root,"ground":top,"cliff":side,"diorama":diorama,"kind":t.kind,"index":i})
		if t.number>0:
			var marker=CatanWorldLayout.point(CatanWorldLayout.data.token)
			var rim=cylinder(.19,.038,Color("897444"),64)
			rim.position=Vector3(marker.x,.224,marker.y)
			root.add_child(rim)
			var token=cylinder(.173,.023,Color("e5d8b9"),64)
			token.position=Vector3(marker.x,.251,marker.y)
			root.add_child(token)
			root.add_child(label3(str(t.number),Vector3(marker.x,.275,marker.y-.05),43,Color("913f2d") if t.number in [6,8] else Color("302d21")))
			var dot_count=6-absi(7-t.number)
			for dot in dot_count:
				var pip=cylinder(.012,.003,Color("913f2d") if t.number in [6,8] else Color("634e35"),12)
				pip.position=Vector3(marker.x+(dot-(dot_count-1)*.5)*.033,.265,marker.y+.08)
				root.add_child(pip)

	while centers.size()<30:centers.append(Vector2(10000,10000))
	sea_material.set_shader_parameter("tile_centers",centers)
	sea_material.set_shader_parameter("tile_count",state.tiles.size())
	sea_material.set_shader_parameter("tile_radius",TILE_SIZE*.993)
	# Use the owning tile's edge normal, not the board's radial direction.
	for e in state.edges:
		var a=state.vertices[e.a]
		var b=state.vertices[e.b]
		if e.tiles!=1 or a.port==-2 or a.port!=b.port:continue
		var pos=Vector3((a.x+b.x)*.5,0,(a.z+b.z)*.5)
		var tangent=Vector3(b.x-a.x,0,b.z-a.z).normalized()
		var outward=Vector3(-tangent.z,0,tangent.x)
		if outward.dot(pos)<0:outward=-outward
		var harbor=living_world.harbor(a.port)
		harbor.position=pos
		harbor.rotation.y=atan2(outward.x,outward.z)
		terrain.add_child(harbor)
		harbors.append(harbor)
		terrain.add_child(label3("3:1" if a.port==-1 else "2:1",pos+outward*.82+Vector3.UP*.28,27,Color("fff1ce"),a.port))
	refresh(data)
	sea_traffic.configure(self)
	_update_boat_wakes()

func _update_boat_wakes():
	var sources=PackedVector4Array()
	var vessels=boats.duplicate()
	for harbor in harbors:vessels.append(harbor.get_node("MooredBoat"))
	for boat in vessels:
		var boat_position=boat.global_position
		var axis=boat.global_basis.z.normalized()
		sources.append(Vector4(boat_position.x,boat_position.z,axis.x,axis.z))
	sea_material.set_shader_parameter("boat_count",mini(sources.size(),16))
	while sources.size()<16:sources.append(Vector4.ZERO)
	sea_material.set_shader_parameter("boat_sources",sources)

func refresh(data: Dictionary):
	var old=state
	state=data
	dwellers=[]
	for n in pieces_root.get_children(): n.free()
	var joins={}
	for e in state.edges:
		if e.owner<0:continue
		for vid in [e.a,e.b]:
			if state.vertices[vid].owner>=0:continue
			var key=Vector2i(vid,e.owner)
			joins[key]=joins.get(key,0)+1
	for e in state.edges:
		if e.owner<0: continue
		var a=state.vertices[e.a]
		var b=state.vertices[e.b]
		var road=cosmetics.road(_piece_style(e.owner),player_color(e.owner))
		var start=Vector3(a.x,0,a.z)
		var end=Vector3(b.x,0,b.z)
		var direction=(end-start).normalized()
		var gap=maxf(0,(start.distance_to(end)-.77)*.5)
		if joins.get(Vector2i(e.a,e.owner),0)<2:start+=direction*gap
		if joins.get(Vector2i(e.b,e.owner),0)<2:end-=direction*gap
		road.scale.z=start.distance_to(end)/.77
		road.scale.y=CatanCosmetics.ROAD_HEIGHT_SCALE
		road.position=(start+end)*.5+Vector3.UP*CatanCosmetics.road_base_height(_piece_style(e.owner))
		road.rotation.y=atan2(b.x-a.x,b.z-a.z)
		pieces_root.add_child(road)
	for key in joins:
		if joins[key]<2:continue
		var v=state.vertices[key.x]
		var join=cosmetics.road_joint(_piece_style(key.y),player_color(key.y))
		join.position=Vector3(v.x,CatanCosmetics.road_base_height(_piece_style(key.y)),v.z)
		join.scale.y=CatanCosmetics.ROAD_HEIGHT_SCALE
		pieces_root.add_child(join)
	var town_residents={}
	for vid in state.vertices.size():
		var v=state.vertices[vid]
		if v.owner<0: continue
		var village=Node3D.new()
		village.position=Vector3(v.x,0.22,v.z)
		pieces_root.add_child(village)
		var first_resident=dwellers.size()
		_house(village,Vector3.ZERO,player_color(v.owner),v.level==2,_piece_style(v.owner))
		town_residents[vid]=dwellers[first_resident]
		if not reduce_motion and not old.is_empty() and (old.vertices[vid].owner!=v.owner or old.vertices[vid].level!=v.level):
			village.scale=Vector3.ONE*0.1
			create_tween().tween_property(village,"scale",Vector3.ONE,0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	road_travel.assign(state,town_residents,pieces_root)
	var t=state.tiles[state.robber]
	var band=living_world.robber_band(t.kind,art)
	band.root.position=Vector3(t.x,0,t.z)
	pieces_root.add_child(band.root)
	band_actors=band.actors
	night_lights=find_children("NightLight*","OmniLight3D",true,false)
	advance_day(0)
	set_mode(mode,seat)
	CatanDiagnostics.event("board.refresh.complete")

func set_mode(value: String,player: int):
	mode=value
	seat=player
	hover=-1
	targets=[]
	marker_nodes=[]
	for n in markers.get_children(): n.free()
	if state.is_empty() or seat<0 or seat!=state.turn or state.winner!=-1: return
	var rules=CatanRules.new()
	rules.s=state
	var source=state.edges if mode=="road" else state.tiles if mode=="robber" else state.vertices
	for i in source.size():
		var good=false
		var pos=Vector3.ZERO
		if mode=="road":
			good=rules.valid_edge(seat,i,state.phase=="setup_road")
			var a=state.vertices[source[i].a]
			var b=state.vertices[source[i].b]
			pos=Vector3((a.x+b.x)/2,0.33,(a.z+b.z)/2)
		elif mode=="settlement":
			good=rules.valid_vertex(seat,i,state.phase=="setup_settlement")
			pos=Vector3(source[i].x,0.33,source[i].z)
		elif mode=="city":
			good=source[i].owner==seat and source[i].level==1
			pos=Vector3(source[i].x,0.8,source[i].z)
		elif mode=="robber":
			good=i!=state.robber
			pos=Vector3(source[i].x,0.7,source[i].z)
		if good:
			var ring=TorusMesh.new()
			ring.inner_radius=.065 if mode!="robber" else .14
			ring.outer_radius=.093 if mode!="robber" else .19
			ring.rings=24;ring.ring_segments=8
			var marker=mesh(ring,Color("f9df9c"))
			marker.position=pos
			markers.add_child(marker)
			targets.append({"id":i,"pos":markers.to_global(pos)})
			marker_nodes.append(marker)

func _process(delta):
	for entry in board_labels:
		if not is_instance_valid(entry.anchor): continue
		entry.label.visible=show_labels and not camera.is_position_behind(entry.anchor.global_position)
		var anchor_pos=entry.anchor.global_position
		var projected=camera.unproject_position(anchor_pos+camera.global_basis.x*.38*TILE_SIZE).distance_to(camera.unproject_position(anchor_pos))
		var label_scale=clampf(projected/30.0,.48,3.3)
		if entry.port:label_scale=clampf(label_scale,.8,1.5)
		entry.label.scale=Vector2.ONE*label_scale
		entry.label.position=(camera.unproject_position(entry.anchor.global_position)-entry.label.size*entry.label.scale*0.5).round()
	if fps_label.visible:fps_label.text=tr("%d FPS · %.1f ms · %.0f MB VRAM") % [Engine.get_frames_per_second(),1000.0/maxf(1,Engine.get_frames_per_second()),Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0]
	if reduce_motion: delta=0.0
	elapsed+=delta
	living_world.animate(actors,elapsed,art,daylight)
	living_world.animate(band_actors,elapsed,art,daylight)
	living_world.animate_dwellers(dwellers,elapsed,daylight)
	for harbor in harbors:
		harbor.get_node("MooredBoat").position.y=-.025+sin(elapsed*.7+harbor.position.x)*.003
	for mill in windmills: mill.rotation.z+=delta*0.4
	for i in birds.size():
		birds[i].visible=daylight>.15
		var angle=elapsed*0.12+i*2.1
		birds[i].position=Vector3(cos(angle)*6.5,2.2+sin(angle*2)*0.15,sin(angle)*5)
		var tangent=Vector3(-6.5*sin(angle),0,5*cos(angle)).normalized()
		birds[i].rotation.y=atan2(-tangent.x,-tangent.z)
		birds[i].rotation.z=sin(elapsed*2+i)*0.10
	sea_traffic.animate(delta,elapsed)
	_update_boat_wakes()
	_animate_beacon()
	for i in clouds.size():
		clouds[i].position.x+=delta*0.025
		if clouds[i].position.x>16: clouds[i].position.x=-16
	if targets.is_empty(): return
	var mouse=get_viewport().get_mouse_position()
	var nearest=-1
	var distance_px=25.0
	for i in targets.size():
		var d=camera.unproject_position(targets[i].pos).distance_to(mouse)
		if d<distance_px:
			nearest=i
			distance_px=d
	if nearest!=hover:
		hover=nearest
		for i in marker_nodes.size(): marker_nodes[i].scale=Vector3.ONE*(1.65 if i==hover else 1.0)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_LEFT and hover>=0:picked.emit(mode,targets[hover].id)
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var before=_mouse_ground()
			camera_zoom=clampf(camera_zoom*(.86 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.16),.16,1.6)
			_update_camera()
			camera_focus+=before-_mouse_ground()
			_clamp_focus()
			_update_camera()
	if event is InputEventMouseMotion:
		if event.button_mask&MOUSE_BUTTON_MASK_MIDDLE:
			var right=camera.global_basis.x
			var forward=Vector3(right.z,0,-right.x)
			var speed=camera.position.distance_to(camera_focus)*.0007*camera_speed
			camera_focus+=(-right*event.relative.x+forward*event.relative.y)*speed
			_clamp_focus()
			_update_camera()
		elif event.button_mask&MOUSE_BUTTON_MASK_RIGHT:
			yaw-=event.relative.x*.006*camera_speed
			pitch=clampf(pitch+event.relative.y*.004*camera_speed,.27,1.28)
			_update_camera()
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_HOME:reset_camera()
		if event.keycode==KEY_F:focus_tile_at_cursor()

func _mouse_ground() -> Vector3:
	var mouse=get_viewport().get_mouse_position()
	var origin=camera.project_ray_origin(mouse)
	var direction=camera.project_ray_normal(mouse)
	if absf(direction.y)<.01:return camera_focus
	return origin+direction*((.20*TILE_SIZE-origin.y)/direction.y)

func _clamp_focus():
	var limit=6*TILE_SIZE*board_scale
	camera_focus.x=clampf(camera_focus.x,-limit,limit)
	camera_focus.z=clampf(camera_focus.z,-limit,limit)
	camera_focus.y=.20*TILE_SIZE

func focus_tile_at_cursor():
	if state.is_empty():return
	var point=_mouse_ground()/TILE_SIZE
	var nearest=-1
	var distance=1.15
	for i in state.tiles.size():
		var tile=state.tiles[i]
		var d=Vector2(tile.x-point.x,tile.z-point.z).length()
		if d<distance:distance=d;nearest=i
	if nearest>=0:
		var tile=state.tiles[nearest]
		camera_focus=Vector3(tile.x*TILE_SIZE,.25*TILE_SIZE,tile.z*TILE_SIZE)
		camera_zoom=.24
		_update_camera()

func reset_camera():
	yaw=0
	pitch=.745
	camera.fov=35
	camera_focus=Vector3(0,0,1.0)
	camera_zoom=1.0
	_update_camera()

func _update_camera():
	var viewport_size=get_viewport().get_visible_rect().size
	var region=view_region if view_region.has_area() else Rect2(Vector2.ZERO,viewport_size)
	var frame_scale=maxf(.88/(region.size.x/viewport_size.x*(viewport_size.x/viewport_size.y)/(1440.0/900)),.69/(region.size.y/viewport_size.y))
	var distance=18.82*board_scale*TILE_SIZE*.88*camera_zoom*frame_scale
	camera.position=camera_focus+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
	var tan_v=tan(deg_to_rad(camera.fov*.5))
	camera.h_offset=-(region.get_center().x/viewport_size.x-.5)*2*distance*tan_v*viewport_size.x/viewport_size.y
	camera.v_offset=(region.get_center().y/viewport_size.y-.5)*2*distance*tan_v
	camera.look_at(camera_focus)
	_update_camera_focus()

func _update_camera_focus():
	if camera.attributes is CameraAttributesPractical:
		var distance=camera.position.distance_to(camera_focus)
		camera.attributes.dof_blur_far_distance=distance+.25*TILE_SIZE
		camera.attributes.dof_blur_far_transition=.6*TILE_SIZE
		camera.attributes.dof_blur_near_distance=maxf(.1,distance-.3*TILE_SIZE)
		camera.attributes.dof_blur_near_transition=.3*TILE_SIZE

func _apply_surface(node: MeshInstance3D,surface_name: String):
	node.set_meta("pbr_surface",surface_name)
	node.material_override=art.surface(surface_name,null,render_values)

func _rock(parent: Node3D,pos: Vector3,size: Vector3,color: Color):
	var sphere=SphereMesh.new()
	sphere.radius=0.5
	sphere.height=1.0
	sphere.radial_segments=20
	sphere.rings=10
	var rock=mesh(sphere,color)
	if parent not in clouds:_apply_surface(rock,"PBR_Wood" if parent in boats else "PBR_Rock")
	rock.position=pos
	rock.scale=size
	rock.rotation=Vector3(pos.x,0.3+pos.z,pos.x*0.5)
	parent.add_child(rock)

func _tile_props(parent: Node3D,kind: int,index: int):
	var random=RandomNumberGenerator.new()
	random.seed=index*421+33
	# Low groundcover gives every terrain its own grain and silhouette.
	for i in 28:
		var x=random.randf_range(-0.72,0.72)
		var z=random.randf_range(-0.72,0.72)
		if Vector2(x,z).length()>0.76 or (absf(x)<0.3 and z>0.24): continue
		if kind in [0,2]:
			var grass=CylinderMesh.new()
			grass.bottom_radius=0.025
			grass.top_radius=0.0
			grass.height=random.randf_range(0.045,0.11)
			grass.radial_segments=3
			var tuft=mesh(grass,Color("68854a") if i%2==0 else Color("b1bc65"))
			tuft.position=Vector3(x,0.24,z)
			tuft.material_override=_foliage(Color("68854a") if i%2==0 else Color("b1bc65"))
			parent.add_child(tuft)
		elif kind in [1,4,5]:
			var size=random.randf_range(0.035,0.10)
			_rock(parent,Vector3(x,0.22,z),Vector3(size,size*0.6,size),COLORS[kind].darkened(0.15))
	if kind==0:
		for i in 3:
			var x=[-0.57,0.03,0.54][i]
			var z=[-0.15,-0.5,0.1][i]
			var trunk=cylinder(0.027,0.26,Color("5e4230"),6)
			trunk.position=Vector3(x,0.33,z)
			parent.add_child(trunk)
			_rock(parent,Vector3(x,0.59,z),Vector3(0.32,0.4,0.3),Color("537647"))
	if kind==2:
		for i in 5:
			var post=box(Vector3(0.032,0.17,0.032),Color("d3bb80"))
			post.position=Vector3(-0.55+i*0.21,0.29,-0.57)
			parent.add_child(post)
		var fence=box(Vector3(0.9,0.027,0.028),Color("cbb176"))
		fence.position=Vector3(-0.13,0.34,-0.57)
		parent.add_child(fence)
	if kind==3:
		if index%2==0: _windmill(parent,Vector3(0.5,0.22,-0.42))
		for i in 3:
			var hay=cylinder(0.072,0.11,Color("d4aa48"),10)
			hay.rotation.z=PI/2
			hay.position=Vector3(-0.55+i*0.18,0.29,0.37)
			parent.add_child(hay)
	if kind==5:
		for i in 3:
			_rock(parent,Vector3(-0.32+i*0.22,0.24,-0.1),Vector3(0.45,0.16,0.35),Color("cdb17a"))
		var cactus=cylinder(0.044,0.32,Color("728557"),7)
		cactus.position=Vector3(-0.4,0.38,0.35)
		parent.add_child(cactus)

func _world_props():
	background_landscape=preload("res://scripts/background_landscape.gd").new()
	scenery.add_child(background_landscape)
	var random=RandomNumberGenerator.new()
	random.seed=822
	# Offshore rocks and tiny islands extend the scene beyond the board.
	for i in 22:
		var angle=i*TAU/22.0
		var radius=random.randf_range(5.4,7.6)
		var pos=Vector3(cos(angle)*radius,-0.27,sin(angle)*radius)
		if absf(pos.x)<4.4 and pos.z>0: continue
		var size=random.randf_range(0.18,0.55)
		_rock(scenery,pos,Vector3(size*1.4,size,size),Color("637b7a"))
	# A lighthouse on a small outcrop, with warm bands and a lantern.
	var island=Node3D.new()
	island.position=Vector3(-5.0,-0.2,-2.4)
	scenery.add_child(island)
	_rock(island,Vector3.ZERO,Vector3(1.25,0.5,0.85),Color("7a8878"))
	for i in 5:
		var band=cylinder(0.16-i*0.012,0.16,Color("e9dcc0") if i%2==0 else Color("ae6650"),32)
		band.mesh.top_radius=.16-(i+1)*.012
		band.position.y=0.2+i*0.16
		island.add_child(band)
	beacon_lamp=cylinder(0.12,0.16,Color("e9b85e"),32)
	beacon_lamp.position.y=1.0
	beacon_lamp.material_override.emission_enabled=true
	beacon_lamp.material_override.emission=Color("ffc86b")
	island.add_child(beacon_lamp)
	beacon_lamp.set_meta("night_light",living_world.add_night_light(island,Vector3(0,1.0,0),1.3,2.0))
	beacon=Node3D.new();beacon.name="LighthouseBeacon";beacon.position.y=1.0;island.add_child(beacon)
	beacon_spot=SpotLight3D.new();beacon.add_child(beacon_spot)
	beacon_spot.light_color=Color("ffdc95");beacon_spot.spot_range=7.0;beacon_spot.spot_angle=12
	beacon_spot.rotation.x=deg_to_rad(-8);beacon_spot.shadow_enabled=true
	var cone=CylinderMesh.new();cone.top_radius=.025;cone.bottom_radius=.60;cone.height=5.5;cone.radial_segments=48;cone.cap_top=false;cone.cap_bottom=false
	beacon_beam=MeshInstance3D.new();beacon_beam.mesh=cone
	beacon_beam.rotation.x=PI/2-deg_to_rad(8);beacon_beam.position=Vector3(0,-sin(deg_to_rad(8))*2.75,-cos(deg_to_rad(8))*2.75)
	beacon_beam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var beam_material=ShaderMaterial.new();beam_material.shader=load("res://shaders/lighthouse_beam.gdshader")
	beacon_beam.material_override=beam_material;beacon.add_child(beacon_beam)
	var cap=CylinderMesh.new()
	cap.top_radius=0
	cap.bottom_radius=0.2
	cap.height=0.17
	var roof=mesh(cap,Color("354854"))
	roof.position.y=1.16
	island.add_child(roof)
	for i in 3:
		var boat=Node3D.new()
		boat.position=Vector3([4.8,-4.8,2.8][i],-0.18,[2.6,1.9,-5.2][i])
		boat.rotation.y=[-0.4,0.8,1.3][i]
		scenery.add_child(boat)
		boats.append(boat)
		var hull=mesh(CatanMiniature.hull(),Color("946d4f"))
		boat.add_child(hull)
		var deck=box(Vector3(0.21,0.025,0.57),Color("bd9762"))
		deck.position.y=0.108
		_apply_surface(deck,"PBR_Wood")
		boat.add_child(deck)
		var mast=cylinder(0.016,0.8,Color("6c4e35"),6)
		mast.position.y=0.44
		_apply_surface(mast,"PBR_Wood")
		boat.add_child(mast)
		var sail=mesh(CatanMiniature.sail(),Color("ebdbad"))
		sail.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED
		boat.add_child(sail)
	for i in 3:
		var bird=Node3D.new()
		scenery.add_child(bird)
		birds.append(bird)
		for direction in [-1,1]:
			var shape=SphereMesh.new();shape.radius=.5;shape.height=1;shape.radial_segments=24;shape.rings=12
			var wing=mesh(shape,Color("e8e1c9"));wing.scale=Vector3(.26,.022,.083)
			wing.position.x=direction*0.075
			wing.rotation.z=direction*0.22
			bird.add_child(wing)
		cosmetics.orb(bird,Vector3.ZERO,Vector3(.065,.065,.17),Color("e8e1c9"))
		cosmetics.orb(bird,Vector3(0,.015,-.09),Vector3(.030,.022,.057),Color("d6a45c"))
	# Distant soft, low-poly clouds, away from the interactive board.
	for i in 7:
		var cloud=Node3D.new()
		cloud.position=Vector3(-13+i*4.1,3.5+random.randf()*1.5,-9-random.randf()*4)
		scenery.add_child(cloud)
		clouds.append(cloud)
		for j in 4:
			_rock(cloud,Vector3(j*0.5,random.randf()*0.12,0),Vector3(1.2,0.42+random.randf()*0.3,0.6),Color("dae4df"))

func _terrain_mesh(kind: int) -> ArrayMesh:
	var surface=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps=10
	for sector in 6:
		var a=Vector2(cos(deg_to_rad(30+60*sector)),sin(deg_to_rad(30+60*sector)))*0.975
		var b=Vector2(cos(deg_to_rad(30+60*(sector+1))),sin(deg_to_rad(30+60*(sector+1))))*0.975
		for i in steps:
			for j in range(steps-i):
				var p=a*float(i)/steps+b*float(j)/steps
				var q=a*float(i+1)/steps+b*float(j)/steps
				var r=a*float(i)/steps+b*float(j+1)/steps
				for point in [p,q,r]: surface.add_vertex(_ground_vertex(point,kind))
				if i+j<steps-1:
					var t=a*float(i+1)/steps+b*float(j+1)/steps
					for point in [q,t,r]: surface.add_vertex(_ground_vertex(point,kind))
	surface.generate_normals()
	return surface.commit()

func _ground_vertex(p: Vector2,kind: int) -> Vector3:
	var edge=maxf(absf(p.x)/0.866,maxf(absf(p.x*0.5+p.y*0.866)/0.866,absf(-p.x*0.5+p.y*0.866)/0.866))
	var height=[0.05,0.14,0.025,0.016,0.15,0.035][kind]
	var wave=0.5+sin(p.x*6.0+kind)*cos(p.y*5.0)*0.5
	return Vector3(p.x,0.2+pow(maxf(0,1-edge),1.3)*height*wave,p.y)

func _piece_style(player: int) -> int:
	var styles=state.get("piece_styles",[])
	return clampi(int(styles[player]),0,CatanCosmetics.SETS.size()-1) if player>=0 and player<styles.size() else 0

func _house(parent: Node3D,pos: Vector3,color: Color,city: bool=false,style: int=0):
	var root=living_world.town(style,color,city)
	root.position=pos
	parent.add_child(root)
	dwellers.append_array(root.get_meta("dwellers",[]))
	if style!=0:return
	var smoke=CPUParticles3D.new()
	smoke.name="Smoke"
	smoke.amount=8
	smoke.lifetime=2.6
	smoke.preprocess=0.7
	smoke.position=Vector3(.045,.336,-.08)
	smoke.direction=Vector3.UP
	smoke.spread=15
	smoke.gravity=Vector3(0.025,0.04,0)
	smoke.initial_velocity_min=0.07
	smoke.initial_velocity_max=0.12
	smoke.scale_amount_min=0.6
	smoke.scale_amount_max=1.3
	var puff=SphereMesh.new()
	puff.radius=0.025
	puff.height=0.05
	puff.radial_segments=8
	puff.rings=4
	var puff_material=mat(Color(0.7,0.75,0.72,0.2))
	puff_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_material.vertex_color_use_as_albedo=true
	puff.material=puff_material
	smoke.mesh=puff
	var fade=Gradient.new()
	fade.set_color(0,Color(1,1,1,0.4))
	fade.set_color(1,Color(1,1,1,0))
	smoke.color_ramp=fade
	smoke.emitting=render_values.particles>0 and not reduce_motion
	root.add_child(smoke)

func _windmill(parent: Node3D,pos: Vector3):
	var root=Node3D.new()
	root.position=pos
	parent.add_child(root)
	var shape=CylinderMesh.new()
	shape.bottom_radius=0.11
	shape.top_radius=0.075
	shape.height=0.38
	shape.radial_segments=8
	var tower=mesh(shape,Color("e8d4a7"))
	tower.position.y=0.19
	root.add_child(tower)
	var cap=CylinderMesh.new()
	cap.bottom_radius=0.13
	cap.top_radius=0
	cap.height=0.16
	cap.radial_segments=8
	var roof=mesh(cap,Color("796249"))
	roof.position.y=0.46
	root.add_child(roof)
	var rotor=Node3D.new()
	rotor.position=Vector3(0,0.34,0.095)
	root.add_child(rotor)
	windmills.append(rotor)
	for i in 4:
		var arm=Node3D.new()
		arm.rotation.z=i*PI/2
		rotor.add_child(arm)
		var blade=box(Vector3(0.055,0.21,0.022),Color("f1dfac"))
		blade.position.y=0.12
		arm.add_child(blade)

func _foliage(color: Color) -> ShaderMaterial:
	var material=ShaderMaterial.new()
	material.shader=load("res://shaders/foliage.gdshader")
	material.set_shader_parameter("leaf_color",color)
	material.set_shader_parameter("motion_speed",0.0 if reduce_motion else 1.0)
	vegetation.append(material)
	return material

func show_production(roll: int):
	if reduce_motion: return
	for tid in state.tiles.size():
		var tile=state.tiles[tid]
		if tile.number!=roll or tid==state.robber: continue
		var ring_mesh=TorusMesh.new()
		ring_mesh.inner_radius=0.74
		ring_mesh.outer_radius=0.77
		var ring=mesh(ring_mesh,Color("e9c77c"))
		ring.position=Vector3(tile.x,0.27,tile.z)
		terrain.add_child(ring)
		var animation=create_tween()
		animation.tween_property(ring,"position:y",0.48,0.5)
		animation.parallel().tween_property(ring,"scale",Vector3.ONE*1.15,0.5)
		animation.tween_callback(ring.queue_free)

func _animate_beacon():
	if not is_instance_valid(beacon):return
	var night=1.0-daylight
	beacon.rotation.y=fposmod(elapsed*.38,TAU)
	beacon.visible=night>.01
	beacon_spot.light_energy=night*5.0
	beacon_spot.spot_range=7.0*scenery.scale.y
	beacon_lamp.material_override.emission_energy_multiplier=night*1.4
	beacon_beam.material_override.set_shader_parameter("strength",night)

# A complete day lasts ten minutes of active play. Solo pause freezes the clock.
func advance_day(delta: float):
	day_seconds=fposmod(day_seconds+delta,600.0)
	var lighting_seconds=day_seconds if render_values.get("day_night_cycle",true) else 150.0
	daylight=smoothstep(-.15,.35,sin(lighting_seconds/600.0*TAU))
	var sun=get_node("Sun")
	sun.rotation_degrees=Vector3(-15-60*absf(sin(lighting_seconds/600.0*TAU)),-34+lighting_seconds*.06,0)
	sun.light_energy=lerpf(.52,1.65,daylight)
	var dusk=Color("efa46f").lerp(Color("ffe4b9"),daylight)
	sun.light_color=Color("92b6ed").lerp(dusk,daylight)
	var env=get_node("WorldEnvironment").environment
	env.ambient_light_energy=lerpf(.65,.55,daylight)
	env.ambient_light_sky_contribution=lerpf(.35,1.0,daylight)
	env.ambient_light_color=Color("7893bf").lerp(Color("b7d4e0"),daylight)
	env.fog_light_color=Color("233750").lerp(Color("b2d0ce"),daylight)
	var sky=env.sky.sky_material
	sky.sky_top_color=Color("091329").lerp(Color("4d7389"),daylight)
	sky.sky_horizon_color=Color("33445d").lerp(Color("ccd3c7"),daylight)
	sky.ground_horizon_color=Color("243952").lerp(Color("bdd6d3"),daylight)
	background_landscape.set_daylight(daylight)
	living_world.night_lighting(night_lights,1.0-daylight)
	_animate_beacon()
	living_world.animate(actors,elapsed,art,daylight)
	living_world.animate(band_actors,elapsed,art,daylight)
	living_world.animate_dwellers(dwellers,elapsed,daylight)

func throw_dice(values: Array):
	if values.size()!=2 or values.any(func(value):return value<1 or value>6):return
	if is_instance_valid(active_dice):active_dice.queue_free()
	# Land near the clear outer edge of the desert miniature, away from its token.
	var tile=state.tiles[0]
	for candidate in state.tiles:
		if candidate.kind==5:tile=candidate;break
	active_dice=CatanDiceThrow.new();active_dice.name="ThrownDice";add_child(active_dice)
	active_dice.scale=Vector3.ONE*(TILE_SIZE/2.2)
	active_dice.setup(values,Vector3(tile.x*2.2,.9,(tile.z+.64)*2.2),reduce_motion)
	active_dice.settled.connect(show_production)

func player_color(player: int) -> Color:
	var colors=state.get("player_colors",[])
	var value=str(colors[player]) if player>=0 and player<colors.size() else ""
	return Color(value) if not value.is_empty() and CatanNetwork.valid_color(value) else PLAYERS[clampi(player,0,5)]
