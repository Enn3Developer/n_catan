class_name CatanBoard
extends Node3D
signal picked(kind: String,id: int)
const TILE_SIZE=25.0 # Regular hexes: 50 m tip to tip, 43.3 m across flats.
const PLAYERS=[Color("ed815d"),Color("65bfcb"),Color("d9b76c"),Color("b697d7"),Color("7dcc83"),Color("d1aa87")]
const LABEL_FONT=preload("res://assets/fonts/FiraSans-Medium.ttf")
@onready var camera: Camera3D=$CameraRig/Camera
@onready var sun: DirectionalLight3D=$Sun
@onready var environment: Environment=$WorldEnvironment.environment
@onready var terrain: Node3D=$Terrain
@onready var pieces_root: Node3D=$Buildings
@onready var markers: Node3D=$PlacementMarkers
@onready var scenery: Node3D=$Scenery
@onready var background_landscape: CatanBackgroundLandscape=$Scenery/BackgroundLandscape
@onready var ocean: MeshInstance3D=$Ocean
@onready var sea_material: ShaderMaterial=$Ocean.material_override
@onready var pollen: CPUParticles3D=$SunlitPollen
@onready var label_layer: CanvasLayer=$Labels
@onready var fps_label: Label=%FPS
var state={}
var mode=""
var seat=-1
var board_scale=1.0
var yaw=0.0
var pitch=0.745
var hover=-1
var targets=[]
var marker_nodes=[]
var boats=[]
var sea_traffic=preload("res://scripts/sea_traffic.gd").new()
var beacon: Node3D
var beacon_lamp: MeshInstance3D
var beacon_beam: MeshInstance3D
var beacon_spot: SpotLight3D
var elapsed=0.0
var birds=[]
var seagulls=preload("res://scripts/seagulls.gd").new()
var reduce_motion=false
var camera_speed=1.0
var board_labels=[]
var quality=2
var art=CatanTileArt.new()
var cosmetics=CatanCosmetics.new()
var render_values=CatanSettings.DEFAULTS.duplicate()
var tile_nodes=[]
var water_centers=PackedVector2Array()
var camera_focus=Vector3(0,0,1.0)
var camera_zoom=1.0
var last_water_quality=-1
var last_shadow_quality=-1
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
var weather

func _ready():
	if "--server" in OS.get_cmdline_user_args():
		set_process(false)
		return
	# The wave table is shared with boat bobbing on the CPU.
	sea_material.set_shader_parameter("waves",preload("res://scripts/ocean_waves.gd").WAVES)
	_update_camera()
	_world_props()
	weather=preload("res://scripts/weather.gd").new();add_child(weather);weather.setup()

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

func label3(text: String,pos: Vector3,size: int,color: Color=Color("fff1ce"),resource_id: int=-1) -> Node3D:
	var anchor=Node3D.new()
	anchor.position=pos
	var label=Label.new()
	label.text=text
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font",LABEL_FONT)
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
	sun.shadow_enabled=values.shadow_quality>0
	if last_shadow_quality!=values.shadow_quality:
		RenderingServer.directional_shadow_atlas_set_size([1024,1024,2048,4096,8192][values.shadow_quality],true)
		RenderingServer.directional_soft_shadow_filter_set_quality([0,0,1,3,4][values.shadow_quality])
		last_shadow_quality=values.shadow_quality
	var forward=RenderingServer.get_current_rendering_method()=="forward_plus"
	environment.fog_enabled=values.atmosphere
	environment.tonemap_exposure=values.exposure
	environment.glow_enabled=values.bloom
	environment.ssao_enabled=forward and values.ambient_occlusion>0
	if forward:RenderingServer.environment_set_ssao_quality(1 if values.ambient_occlusion==1 else 3,values.ambient_occlusion==1,.5,2,70,100)
	environment.ssil_enabled=forward and values.global_illumination==1
	environment.sdfgi_enabled=forward and values.global_illumination>=2
	environment.sdfgi_min_cell_size=.4 if values.global_illumination==2 else .2
	environment.ssr_enabled=forward and values.reflections>0
	environment.ssr_max_steps=32 if values.reflections==1 else 96
	camera.attributes.dof_blur_far_enabled=values.depth_of_field and forward
	camera.attributes.dof_blur_near_enabled=values.depth_of_field and forward
	_update_camera_focus()
	sea_material.set_shader_parameter("motion_speed",0.0 if reduce_motion else values.wind)
	sea_material.set_shader_parameter("water_quality",values.water_quality)
	if last_water_quality!=values.water_quality:
		ocean.mesh.subdivide_width=[64,128,224,320][values.water_quality]
		ocean.mesh.subdivide_depth=ocean.mesh.subdivide_width
		last_water_quality=values.water_quality
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

	water_centers=centers.duplicate()
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
	seagulls.configure()
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
	sea_material.set_shader_parameter("animation_time",elapsed)
	environment.sky.sky_material.set_shader_parameter("animation_time",elapsed)
	living_world.animate(actors,elapsed,art,daylight)
	living_world.animate(band_actors,elapsed,art,daylight)
	living_world.animate_dwellers(dwellers,elapsed,daylight)
	for harbor in harbors:
		harbor.get_node("MooredBoat").position.y=-.025+sin(elapsed*.7+harbor.position.x)*.003
	seagulls.animate(delta,elapsed,daylight,weather.current if is_instance_valid(weather) else {},reduce_motion)
	sea_traffic.animate(delta,elapsed)
	if delta>0:
		for harbor in harbors:_float_boat(harbor.get_node("MooredBoat"))
		for ship in sea_traffic.fleet:_float_boat(ship.boat)
	_update_boat_wakes()
	_animate_beacon()
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
	_apply_surface(rock,"PBR_Wood" if parent in boats else "PBR_Rock")
	rock.position=pos
	rock.scale=size
	rock.rotation=Vector3(pos.x,0.3+pos.z,pos.x*0.5)
	parent.add_child(rock)

func _world_props():
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
	seagulls.setup(self)

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

func _float_boat(boat: Node3D):
	var p=Vector2(boat.global_position.x,boat.global_position.z)
	var storm=float(weather.current.storm) if is_instance_valid(weather) else 0.0
	var height=preload("res://scripts/ocean_waves.gd").height(p,elapsed*render_values.wind,storm,render_values.water_quality,water_centers,TILE_SIZE*.993)
	boat.position.y+=height/boat.get_parent().global_basis.get_scale().y

# A complete day lasts ten minutes of active play. Solo pause freezes the clock.
func advance_day(delta: float):
	day_seconds=fposmod(day_seconds+delta,600.0)
	var lighting_seconds=day_seconds if render_values.get("day_night_cycle",true) else 150.0
	daylight=smoothstep(-.15,.35,sin(lighting_seconds/600.0*TAU))
	sun.rotation_degrees=Vector3(-15-60*absf(sin(lighting_seconds/600.0*TAU)),-34+lighting_seconds*.06,0)
	sun.light_energy=lerpf(.52,1.65,daylight)
	var dusk=Color("efa46f").lerp(Color("ffe4b9"),daylight)
	sun.light_color=Color("92b6ed").lerp(dusk,daylight)
	var env=environment
	env.ambient_light_energy=lerpf(.65,.55,daylight)
	env.ambient_light_sky_contribution=lerpf(.35,1.0,daylight)
	env.ambient_light_color=Color("7893bf").lerp(Color("b7d4e0"),daylight)
	env.fog_light_color=Color("233750").lerp(Color("b2d0ce"),daylight)
	var sky=env.sky.sky_material
	var sky_top=Color("091329").lerp(Color("2780cf"),daylight)
	var sky_horizon=Color("33445d").lerp(Color("a4d5f4"),daylight)
	if is_instance_valid(weather):
		weather.update_weather(day_seconds,daylight,render_values,board_scale)
		var conditions=weather.current
		var overcast=float(conditions.clouds)
		var storm=float(conditions.storm)
		var direct_sun=float(conditions.sun_visibility)
		var sky_overcast=smoothstep(.28,.72,overcast)
		# Cloudy, rainy and stormy skies light the board diffusely, without sun shadows.
		sun.light_energy*=direct_sun
		sun.shadow_enabled=render_values.get("shadow_quality",3)>0 and direct_sun>.01
		env.ambient_light_energy=lerpf(.65,.50,storm)
		env.ambient_light_sky_contribution=lerpf(1.0,.35,overcast)
		env.ambient_light_color=Color("7893bf").lerp(Color("c4d1db"),daylight)
		env.fog_density=lerpf(.0018*2.2/TILE_SIZE,.0007,float(conditions.rain))
		env.fog_light_color=env.fog_light_color.lerp(Color("687c8e"),overcast*.55)
		sky_top=sky_top.lerp(Color("647586").darkened((1.0-daylight)*.68),sky_overcast*.85)
		sky_horizon=sky_horizon.lerp(Color("85939c").darkened((1.0-daylight)*.64),sky_overcast*.8)
		sky.set_shader_parameter("cloud_cover",overcast)
		sky.set_shader_parameter("sun_visibility",direct_sun)
		sky.set_shader_parameter("storm_strength",storm)
		sky.set_shader_parameter("flash",0.0 if reduce_motion else conditions.flash)
		sea_material.set_shader_parameter("sun_strength",daylight*direct_sun)
		sea_material.set_shader_parameter("storm_strength",storm)
		sea_material.set_shader_parameter("rain_strength",0.0 if reduce_motion or render_values.particles==0 else conditions.rain)
	sky.set_shader_parameter("sky_top_color",sky_top)
	sky.set_shader_parameter("sky_horizon_color",sky_horizon)
	sky.set_shader_parameter("daylight",daylight)
	sky.set_shader_parameter("sun_direction",sun.global_basis.z.normalized())
	sea_material.set_shader_parameter("sun_direction",sun.global_basis.z.normalized())
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
