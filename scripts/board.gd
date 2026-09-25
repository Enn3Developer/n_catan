class_name CatanBoard
extends Node3D
signal picked(kind: String,id: int)
const TILE_SIZE=25.0 # Regular hexes: 50 m tip to tip, 43.3 m across flats.
const PLAYERS=[Color("ed815d"),Color("65bfcb"),Color("d9b76c"),Color("b697d7"),Color("7dcc83"),Color("d1aa87")]
const NUMBER_TOKEN=preload("res://scenes/world/number_token.tscn")
const PLACEMENT_MARKER=preload("res://scenes/world/placement_marker.tscn")
const ROBBER_MARKER=preload("res://scenes/world/robber_marker.tscn")
const PRODUCTION_RING=preload("res://scenes/world/production_ring.tscn")
const CHIMNEY_SMOKE=preload("res://scenes/world/chimney_smoke.tscn")
# Roads sit directly on the terrain surface around each vertex.
const ROAD_BASE=.201
const DICE_THROW=preload("res://scenes/world/dice_throw.tscn")
const SHIP=preload("res://assets/models/props/ship.glb")
const TREASURE=preload("res://assets/models/props/treasure.glb")
const FOG_BANK=preload("res://assets/models/props/fog_bank.glb")
# Matches the tile_centers array in water.gdshader.
const MAX_WATER_TILES=48
# Ships ride just above the calm water line.
const SHIP_BASE=.04
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
@onready var pollen: GPUParticles3D=$SunlitPollen
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
## The ship picked to move while mode is "move_to".
var move_from=-1
@onready var boats: Array[Node3D]=[$Scenery/Boat0,$Scenery/Boat1,$Scenery/Boat2]
var sea_traffic=preload("res://scripts/sea_traffic.gd").new()
@onready var lighthouse=$Scenery/Lighthouse
@onready var beacon: Node3D=lighthouse.beacon
@onready var beacon_lamp: MeshInstance3D=lighthouse.lamp
@onready var beacon_spot: SpotLight3D=lighthouse.spot
var elapsed=0.0
var birds=[]
var seagulls=preload("res://scripts/seagulls.gd").new()
var reduce_motion=false
var camera_speed=1.0
## Number tokens and port signboards, turned each frame to face the camera.
var facing=[]
var quality=2
var art=CatanTileArt.new()
var render_values=CatanSettings.DEFAULTS.duplicate()
var tile_nodes=[]
## Number tokens by tile, so a treasure that moves on can reprint its number.
var tokens={}
var water_centers=PackedVector2Array()
var camera_focus=Vector3(0,0,1.0)
var camera_zoom=1.0
## Input moves these goals; the camera eases toward them each frame.
var goal_focus=Vector3(0,0,1.0)
var goal_zoom=1.0
var goal_yaw=0.0
var goal_pitch=.745
## The view Home returns to, fitted to the board's tiles.
var home_focus=Vector3(0,0,1.0)
var home_zoom=1.0
## A left press on open ground becomes a pan once it moves a few pixels.
var press_at=Vector2.INF
var left_panning=false
var last_water_quality=-1
var last_shadow_quality=-1
var show_labels=true
## Off in menus and under dialogs: the camera and pieces only answer the mouse
## and keys while the board itself is what the player is looking at.
var accepts_input=false
var view_region=Rect2()
var day_seconds=150.0
## Whole days since the game began; the weather outline changes with each one.
var day_count=0
var active_dice: CatanDiceThrow
var living_world=preload("res://scripts/living_world.gd").new()
## Paints the "Owner" surfaces of authored pieces in the player's color.
var tint=CatanModelTint.new()
var actors=[]
var harbors=[]
var band_actors=[]
var dwellers=[]
var road_travel=preload("res://scripts/road_travel.gd").new()
var night_lights=[]
var daylight=1.0
@onready var weather=$Weather
## The sea floor under the see-through water, sized to each board.
var seabed: MeshInstance3D
var seabed_material: ShaderMaterial
## Beaches and rock shelves at the cliff foot, rebuilt with each board.
var coast=CatanCoast.new()
## Fish, weed and corals under the see-through water.
var sea_life=CatanSeaLife.new()
## Shared by every fog bank, so one animation_time moves them all.
var fog_material: ShaderMaterial

func _ready():
	if "--server" in OS.get_cmdline_user_args():
		set_process(false)
		return
	fog_material=ShaderMaterial.new()
	fog_material.shader=preload("res://shaders/fog_bank.gdshader")
	seabed_material=ShaderMaterial.new()
	seabed_material.shader=preload("res://shaders/seabed.gdshader")
	seabed=MeshInstance3D.new()
	seabed.name="Seabed"
	seabed.mesh=PlaneMesh.new()
	seabed.material_override=seabed_material
	seabed.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	seabed.position.y=ocean.position.y
	# The shader moves every vertex down; keep culling from trusting the flat plane.
	seabed.extra_cull_margin=60.0
	add_child(seabed)
	coast.name="Coast"
	add_child(coast)
	sea_life.name="SeaLife"
	add_child(sea_life)
	# The wave table is shared with boat bobbing on the CPU.
	sea_material.set_shader_parameter("waves",preload("res://scripts/ocean_waves.gd").WAVES)
	_update_camera()
	_world_props()

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
			tile.ground.lod_bias=CatanTileArt.lod_bias(values)
			tile.ground.material_override=art.ground(tile.kind,tile.index)
			tile.cliff.material_override=art.cliff()
			if tile.diorama:art.apply_instance(tile.diorama,values)
		coast.build(state,TILE_SIZE,art,values)
		sea_life.build(state,CatanSeaFloor.new(water_centers,TILE_SIZE*.993),values)
	if old.texture_quality!=values.texture_quality:_apply_surfaces(self)
	art.animate(values)
	sun.shadow_enabled=values.shadow_quality>0
	if last_shadow_quality!=values.shadow_quality:
		RenderingServer.directional_shadow_atlas_set_size([1024,1024,2048,4096,8192][values.shadow_quality],true)
		RenderingServer.directional_soft_shadow_filter_set_quality([0,0,1,3,4][values.shadow_quality])
		last_shadow_quality=values.shadow_quality
	var forward=RenderingServer.get_current_rendering_method()=="forward_plus"
	environment.fog_enabled=values.atmosphere
	# Volumetric fog renders the lighthouse beam in its sea haze; only Forward+ supports it.
	environment.volumetric_fog_enabled=forward and values.atmosphere
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
	for smoke in find_children("Smoke","GPUParticles3D",true,false):
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
	day_count=int(data.get("world_days",0))
	state=data
	board_scale=CatanRules.island_scale(data)
	scenery.scale=Vector3.ONE*board_scale*TILE_SIZE
	_fit_home()
	reset_camera(true)
	facing=[]
	tokens={}
	for n in terrain.get_children(): n.free()
	tile_nodes=[]
	actors=[]
	harbors=[]
	art.configure(render_values)
	var centers=PackedVector2Array()
	for i in state.tiles.size():
		var t=state.tiles[i]
		centers.append(Vector2(t.x,t.z)*TILE_SIZE)
		tile_nodes.append(_build_tile(i))

	water_centers=centers.duplicate()
	while centers.size()<MAX_WATER_TILES:centers.append(Vector2(10000,10000))
	sea_material.set_shader_parameter("tile_centers",centers)
	sea_material.set_shader_parameter("tile_count",state.tiles.size())
	sea_material.set_shader_parameter("tile_radius",TILE_SIZE*.993)
	_fit_seabed(centers)
	coast.build(state,TILE_SIZE,art,render_values)
	sea_life.build(state,CatanSeaFloor.new(water_centers,TILE_SIZE*.993),render_values)
	# Face away from the owning tile; random coasts are not convex.
	for e in state.edges:
		var a=state.vertices[e.a]
		var b=state.vertices[e.b]
		if e.tiles!=1 or a.port==-2 or a.port!=b.port:continue
		var pos=Vector3((a.x+b.x)*.5,0,(a.z+b.z)*.5)
		var tangent=Vector3(b.x-a.x,0,b.z-a.z).normalized()
		var outward=Vector3(-tangent.z,0,tangent.x)
		for t in a.tiles:
			if t in b.tiles and outward.dot(pos-Vector3(state.tiles[t].x,0,state.tiles[t].z))<0:outward=-outward
		var harbor=living_world.harbor(a.port)
		harbor.position=pos
		harbor.rotation.y=atan2(outward.x,outward.z)
		terrain.add_child(harbor)
		harbors.append(harbor)
		# The signboard stands on the pier's seaward end, beside the lantern.
		var port_sign=CatanPortSign.make(a.port)
		port_sign.position=Vector3(-.1,.04,.6)
		harbor.add_child(port_sign)
		facing.append(port_sign)
	refresh(data)
	sea_traffic.configure(self)
	seagulls.configure()
	_update_boat_wakes()

## One hex: cliff, sculpted ground, its diorama and villagers, and the number
## token. A hex still under the fog is bare ground under a fog bank.
func _build_tile(i: int) -> Dictionary:
	var t=state.tiles[i]
	var hidden=int(t.kind)==CatanRules.FOG
	# The treasure lies on a sandy tile like the desert's.
	var kind=mini(int(t.kind),CatanRules.DESERT)
	var root=Node3D.new()
	root.name="Tile_%02d_%s" % [i,"fog" if hidden else "treasure" if t.kind==CatanRules.TREASURE else CatanTileArt.BIOMES[kind]]
	root.position=Vector3(t.x,0,t.z)
	terrain.add_child(root)
	var side=MeshInstance3D.new()
	side.name="StratifiedCliff"
	side.mesh=art.cliff_mesh()
	side.material_override=art.cliff()
	root.add_child(side)
	var top=MeshInstance3D.new()
	top.name="SculptedGround"
	top.mesh=art.ground_mesh(kind)
	top.lod_bias=CatanTileArt.lod_bias(render_values)
	top.material_override=art.ground(kind,i)
	root.add_child(top)
	var entry={"root":root,"ground":top,"cliff":side,"diorama":null,"kind":kind,"index":i,"shown":int(t.kind)}
	if hidden:
		var bank: Node3D=FOG_BANK.instantiate()
		bank.name="FogBank"
		bank.rotation.y=float(i)*1.7
		for part in bank.find_children("*","MeshInstance3D",true,false):part.material_override=fog_material
		root.add_child(bank)
		return entry
	var diorama=art.instantiate(kind,i,render_values)
	root.add_child(diorama)
	entry.diorama=diorama
	actors.append_array(living_world.populate(root,kind,i,art))
	if t.kind==CatanRules.TREASURE:
		var spot=Vector2(-.34,-.22)
		var chest: Node3D=TREASURE.instantiate()
		_apply_surfaces(chest)
		chest.position=Vector3(spot.x,art.height_at(spot,kind),spot.y)
		chest.rotation.y=.5
		chest.scale=Vector3.ONE*2.0
		living_world.wire_lights(chest)
		root.add_child(chest)
	if t.number>0:
		var marker=CatanWorldLayout.point(CatanWorldLayout.data.token)
		var token=NUMBER_TOKEN.instantiate()
		token.position=Vector3(marker.x,0,marker.y)
		# Larger than the model so the printed number reads from the usual camera height.
		token.scale=Vector3.ONE*1.3
		root.add_child(token)
		token.show_number(t.number)
		facing.append(token)
		tokens[i]=token
	return entry

## Hexes that came out of the fog since the last state: the hex is built for
## real and its fog bank rises and thins away. The shore follows the new land.
func _reveal_tiles() -> bool:
	var changed=false
	for i in mini(tile_nodes.size(),state.tiles.size()):
		var entry=tile_nodes[i]
		if int(entry.get("shown",-1))==int(state.tiles[i].kind):continue
		changed=true
		var bank: Node3D=entry.root.get_node_or_null("FogBank")
		if bank:
			var at=bank.global_transform
			entry.root.remove_child(bank)
			terrain.add_child(bank)
			bank.global_transform=at
			if reduce_motion:bank.queue_free()
			else:
				var lift=create_tween().set_parallel()
				lift.tween_property(bank,"position:y",bank.position.y+.9,1.6).set_ease(Tween.EASE_IN)
				lift.tween_property(bank,"scale",Vector3(1.4,.05,1.4),1.6).set_ease(Tween.EASE_IN)
				lift.chain().tween_callback(bank.queue_free)
		entry.root.free()
		tile_nodes[i]=_build_tile(i)
	if changed:coast.build(state,TILE_SIZE,art,render_values)
	return changed

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
	_reveal_tiles()
	dwellers=[]
	for n in pieces_root.get_children(): n.free()
	var joins={}
	for e in state.edges:
		if e.owner<0 or e.get("ship",false):continue
		for vid in [e.a,e.b]:
			if state.vertices[vid].owner>=0:continue
			var key=Vector2i(vid,e.owner)
			joins[key]=joins.get(key,0)+1
	for e in state.edges:
		if e.owner<0: continue
		var a=state.vertices[e.a]
		var b=state.vertices[e.b]
		if e.get("ship",false):
			_ship(e)
			continue
		var road=CatanPieceBuilder.road(_look(e.owner),player_color(e.owner),_full_detail())
		var start=Vector3(a.x,0,a.z)
		var end=Vector3(b.x,0,b.z)
		var direction=(end-start).normalized()
		var gap=maxf(0,(start.distance_to(end)-.77)*.5)
		if joins.get(Vector2i(e.a,e.owner),0)<2:start+=direction*gap
		if joins.get(Vector2i(e.b,e.owner),0)<2:end-=direction*gap
		road.scale.z=start.distance_to(end)/CatanPieceBuilder.ROAD_LENGTH
		road.position=(start+end)*.5+Vector3.UP*ROAD_BASE
		road.rotation.y=atan2(b.x-a.x,b.z-a.z)
		if road.has_node("NightWindows"):living_world.wire_lights(road)
		pieces_root.add_child(road)
	for key in joins:
		if joins[key]<2:continue
		var v=state.vertices[key.x]
		var join=CatanPieceBuilder.road_joint(_look(key.y),player_color(key.y),_full_detail())
		join.position=Vector3(v.x,ROAD_BASE,v.z)
		pieces_root.add_child(join)
	var town_residents={}
	for vid in state.vertices.size():
		var v=state.vertices[vid]
		if v.owner<0: continue
		var village=Node3D.new()
		village.position=Vector3(v.x,0.22,v.z)
		pieces_root.add_child(village)
		var first_resident=dwellers.size()
		_house(village,player_color(v.owner),v.level==2,_look(v.owner),_gate_parity(vid))
		town_residents[vid]=dwellers[first_resident]
		if not reduce_motion and not old.is_empty() and (old.vertices[vid].owner!=v.owner or old.vertices[vid].level!=v.level):
			village.scale=Vector3.ONE*0.1
			create_tween().tween_property(village,"scale",Vector3.ONE,0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	for i in tokens:
		if i<state.tiles.size() and is_instance_valid(tokens[i]) and tokens[i].number!=int(state.tiles[i].number):
			tokens[i].show_number(int(state.tiles[i].number))
	road_travel.assign(state,town_residents,pieces_root)
	var t=state.tiles[state.robber]
	var band=living_world.robber_band(mini(int(t.kind),CatanRules.DESERT),art)
	band.root.position=Vector3(t.x,0,t.z)
	pieces_root.add_child(band.root)
	band_actors=band.actors
	night_lights=find_children("NightLight*","OmniLight3D",true,false)
	advance_day(0)
	set_mode(mode,seat)
	CatanDiagnostics.event("board.refresh.complete")

## A ship sits well out on its edge's sea side, clear of the beach and the cliff.
func _ship(e: Dictionary):
	var a=state.vertices[e.a]
	var b=state.vertices[e.b]
	var middle=Vector3((a.x+b.x)*.5,0,(a.z+b.z)*.5)
	var along=Vector3(b.x-a.x,0,b.z-a.z).normalized()
	var across=Vector3(-along.z,0,along.x)
	for t in a.tiles:
		if t in b.tiles and across.dot(middle-Vector3(state.tiles[t].x,0,state.tiles[t].z))<0:across=-across
	var ship: Node3D=tint.paint(SHIP.instantiate(),player_color(e.owner),"Owner")
	_apply_surfaces(ship)
	ship.position=middle+across*(.36 if int(e.tiles)==1 else 0.0)+Vector3.UP*SHIP_BASE
	ship.rotation.y=atan2(along.x,along.z)
	# The hull is .5 long, a little shorter than an edge, so bow and stern clear the coast corners.
	ship.scale=Vector3.ONE*1.05
	living_world.wire_lights(ship)
	pieces_root.add_child(ship)

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
	var robber_sites=rules.robber_sites(seat) if mode=="robber" else []
	var movable=rules.movable_ships(seat) if mode=="move_ship" else rules.ship_moves(seat,move_from) if mode=="move_to" else []
	var edges=mode in ["road","ship","route","move_ship","move_to"]
	# Free roads can't place a piece the player has run out of.
	var roads_left=rules.pieces(seat,"road")<CatanRules.PIECE_LIMITS.road
	var ships_left=rules.pieces(seat,"ship")<CatanRules.PIECE_LIMITS.ship
	var source=state.edges if edges else state.tiles if mode=="robber" else state.vertices
	for i in source.size():
		var good=false
		var pos=Vector3.ZERO
		var kind=mode
		if mode in ["move_ship","move_to"]:
			good=i in movable
			var a=state.vertices[source[i].a]
			var b=state.vertices[source[i].b]
			pos=Vector3((a.x+b.x)/2,.45 if mode=="move_ship" else .2,(a.z+b.z)/2)
		elif edges:
			# "route" offers both, for free roads on an archipelago.
			good=mode!="ship" and roads_left and rules.valid_edge(seat,i,state.phase=="setup_road")
			kind="road"
			if not good and mode!="road" and ships_left and rules.valid_ship(seat,i):
				good=true
				kind="ship"
			var a=state.vertices[source[i].a]
			var b=state.vertices[source[i].b]
			pos=Vector3((a.x+b.x)/2,0.33 if kind=="road" else .2,(a.z+b.z)/2)
		elif mode=="settlement":
			good=rules.valid_vertex(seat,i,state.phase=="setup_settlement")
			pos=Vector3(source[i].x,0.33,source[i].z)
		elif mode=="city":
			good=source[i].owner==seat and source[i].level==1
			pos=Vector3(source[i].x,0.8,source[i].z)
		elif mode=="robber":
			good=i in robber_sites
			pos=Vector3(source[i].x,0.7,source[i].z)
		if good:
			var marker=(ROBBER_MARKER if mode=="robber" else PLACEMENT_MARKER).instantiate()
			marker.position=pos
			markers.add_child(marker)
			targets.append({"id":i,"pos":markers.to_global(pos),"kind":kind})
			marker_nodes.append(marker)

func _process(delta):
	_steer_camera(delta)
	var yaw=camera.global_rotation.y
	for node in facing:
		if not is_instance_valid(node):continue
		if node is CatanPortSign:
			node.face(yaw)
			node.board.visible=show_labels
		else:
			node.rotation.y=yaw-node.get_parent().global_rotation.y
			node.print_label.visible=show_labels
	if fps_label.visible:fps_label.text=tr("%d FPS · %.1f ms · %.0f MB VRAM") % [Engine.get_frames_per_second(),1000.0/maxf(1,Engine.get_frames_per_second()),Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0]
	if reduce_motion: delta=0.0
	elapsed+=delta
	sea_material.set_shader_parameter("animation_time",elapsed)
	if seabed_material:seabed_material.set_shader_parameter("animation_time",elapsed)
	if fog_material:fog_material.set_shader_parameter("animation_time",elapsed)
	_point_fish()
	sea_life.animate(delta,elapsed)
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

const CAMERA_EASE=11.0
const ZOOM_RANGE=Vector2(.16,1.6)
const PITCH_RANGE=Vector2(.27,1.28)

func _unhandled_input(event):
	if not accepts_input:return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed and hover>=0:picked.emit(targets[hover].get("kind",mode),targets[hover].id)
			press_at=event.position if event.pressed and hover<0 else Vector2.INF
			left_panning=false
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			# Trackpads send fractional wheel steps; factor scales the zoom to match.
			var steps=event.factor if event.factor>0 else 1.0
			zoom_at(event.position,pow(.86 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.16,steps))
	if event is InputEventMagnifyGesture:zoom_at(event.position,1.0/maxf(event.factor,.01))
	if event is InputEventPanGesture:
		pan_by(-event.delta*6.0,false)
	if event is InputEventMouseMotion:
		if event.button_mask&MOUSE_BUTTON_MASK_MIDDLE:
			_grab(event.position-event.relative,event.position)
		elif event.button_mask&MOUSE_BUTTON_MASK_RIGHT:
			goal_yaw-=event.relative.x*.006*camera_speed
			goal_pitch=clampf(goal_pitch+event.relative.y*.004*camera_speed,PITCH_RANGE.x,PITCH_RANGE.y)
			# Orbiting follows the hand directly; easing it feels like lag.
			yaw=goal_yaw;pitch=goal_pitch
			_update_camera()
		elif event.button_mask&MOUSE_BUTTON_MASK_LEFT and press_at!=Vector2.INF:
			if not left_panning and event.position.distance_to(press_at)>6:left_panning=true
			if left_panning:_grab(event.position-event.relative,event.position)
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_HOME:reset_camera()
		if event.keycode==KEY_F:focus_tile_at_cursor()
		if event.keycode in [KEY_EQUAL,KEY_KP_ADD]:zoom_at(get_viewport().get_visible_rect().size*.5,.8)
		if event.keycode in [KEY_MINUS,KEY_KP_SUBTRACT]:zoom_at(get_viewport().get_visible_rect().size*.5,1.25)

## Zooms by factor while the ground under the pointer stays put. Scaling the
## camera about that ground point keeps it on the same pixel.
func zoom_at(screen: Vector2,factor: float):
	var next=clampf(goal_zoom*factor,ZOOM_RANGE.x,ZOOM_RANGE.y)
	var k=next/goal_zoom
	var anchor=_ground_at(screen)
	goal_zoom=next
	goal_focus=anchor+(goal_focus-anchor)*k
	_clamp_goal()

## Pans by a screen-space offset in pixels, scaled to the camera distance.
func pan_by(pixels: Vector2,direct: bool):
	var right=Vector3(cos(goal_yaw),0,-sin(goal_yaw))
	var back=Vector3(sin(goal_yaw),0,cos(goal_yaw))
	var shift=(right*pixels.x+back*pixels.y)*camera.position.distance_to(camera_focus)*.0011*camera_speed
	goal_focus+=shift
	_clamp_goal()
	if direct:
		camera_focus=goal_focus
		_update_camera()

## Drags the board so the ground under the pointer follows it exactly.
func _grab(from: Vector2,to: Vector2):
	var shift=_ground_at(from)-_ground_at(to)
	var reach=camera.position.distance_to(camera_focus)
	# Near the horizon the ground point races away; fall back to a plain pan.
	if shift.length()>reach*.25:shift=shift.normalized()*reach*.25
	goal_focus+=Vector3(shift.x,0,shift.z)
	_clamp_goal()
	camera_focus=goal_focus
	_update_camera()

func _steer_camera(delta: float):
	if accepts_input and not _typing():
		var keys=Vector2(_held(KEY_D,KEY_RIGHT)-_held(KEY_A,KEY_LEFT),_held(KEY_S,KEY_DOWN)-_held(KEY_W,KEY_UP))
		if keys!=Vector2.ZERO:pan_by(keys.normalized()*900*delta,false)
		goal_yaw+=(_held(KEY_E,KEY_PAGEDOWN)-_held(KEY_Q,KEY_PAGEUP))*1.8*delta*camera_speed
	var settled=camera_focus.distance_to(goal_focus)<.001 and absf(camera_zoom-goal_zoom)<.0001 and absf(yaw-goal_yaw)<.0001 and absf(pitch-goal_pitch)<.0001
	if settled:return
	var weight=1.0 if reduce_motion else 1.0-exp(-CAMERA_EASE*delta)
	camera_focus=camera_focus.lerp(goal_focus,weight)
	# Zoom eases in log space, so each wheel step feels the same near and far.
	camera_zoom=exp(lerpf(log(camera_zoom),log(goal_zoom),weight))
	yaw=lerpf(yaw,goal_yaw,weight)
	pitch=lerpf(pitch,goal_pitch,weight)
	_update_camera()

func _held(key: Key,alternate: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(key) or Input.is_key_pressed(alternate) else 0.0

## Letters typed into chat or a trade note must not move the camera.
func _typing() -> bool:
	var focus=get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit

func _ground_at(screen: Vector2) -> Vector3:
	var origin=camera.project_ray_origin(screen)
	var direction=camera.project_ray_normal(screen)
	if direction.y>-.01:return camera_focus
	return origin+direction*((.20*TILE_SIZE-origin.y)/direction.y)

## Tells the fish where the pointer meets open water, so they can scatter
## from it. Beaches, land and the HUD don't count.
func _point_fish():
	sea_life.cursor_active=false
	var viewport=get_viewport()
	var screen=viewport.get_mouse_position()
	if not viewport.get_visible_rect().has_point(screen) or viewport.gui_get_hovered_control()!=null:return
	if sea_life.floor_map==null or not DisplayServer.window_is_focused():return
	var origin=camera.project_ray_origin(screen)
	var direction=camera.project_ray_normal(screen)
	if direction.y>-.01:return
	var hit=sea_life.to_local(origin+direction*((CatanSeaLife.WATER_Y-origin.y)/direction.y))
	if sea_life.floor_map.shore_distance(Vector2(hit.x,hit.z))<4.0:return
	sea_life.cursor=hit
	sea_life.cursor_active=true

func _mouse_ground() -> Vector3:
	return _ground_at(get_viewport().get_mouse_position())

func _clamp_goal():
	var limit=6*TILE_SIZE*board_scale
	goal_focus.x=clampf(goal_focus.x,-limit,limit)
	goal_focus.z=clampf(goal_focus.z,-limit,limit)
	goal_focus.y=.20*TILE_SIZE

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
		goal_focus=Vector3(tile.x*TILE_SIZE,.20*TILE_SIZE,tile.z*TILE_SIZE)
		goal_zoom=.24

## Eases back to the fitted overview; snap jumps there at once.
func reset_camera(snap: bool=false):
	camera.fov=35
	# Unwind any full turns first, so the camera takes the short way back.
	yaw=wrapf(yaw,-PI,PI)
	goal_yaw=0.0
	goal_pitch=.745
	goal_focus=home_focus
	goal_zoom=home_zoom
	if snap:
		yaw=0.0;pitch=goal_pitch;camera_focus=goal_focus;camera_zoom=goal_zoom
	_update_camera()

## Spreads the bed well past the outermost tiles; by its edge the water is too
## deep to see through, so the border never shows.
func _fit_seabed(centers: PackedVector2Array):
	if not seabed:return
	var reach=0.0
	for i in state.tiles.size():reach=maxf(reach,maxf(absf(centers[i].x),absf(centers[i].y)))
	var size=2.0*(reach+170.0)
	seabed.mesh.size=Vector2(size,size)
	seabed.mesh.subdivide_width=clampi(int(size/5.0),80,220)
	seabed.mesh.subdivide_depth=seabed.mesh.subdivide_width
	seabed_material.set_shader_parameter("tile_centers",centers)
	seabed_material.set_shader_parameter("tile_count",state.tiles.size())
	seabed_material.set_shader_parameter("tile_radius",TILE_SIZE*.993)

## Frames the tiles' bounding box instead of the world origin, so spread-out
## boards like the archipelago fill the view. Classic boards keep zoom 1.
func _fit_home():
	var low=Vector2.INF
	var high=-Vector2.INF
	for t in state.get("tiles",[]):
		low=low.min(Vector2(t.x,t.z));high=high.max(Vector2(t.x,t.z))
	if low==Vector2.INF:
		home_focus=Vector3(0,0,1.0);home_zoom=1.0;return
	var centre=(low+high)*.5
	var reach=maxf(high.x-low.x,high.y-low.y)*.5+1.0
	home_zoom=clampf(reach/CatanRules.CLASSIC_EXTENT/board_scale,.6,1.0)
	home_focus=Vector3(centre.x*TILE_SIZE,0,centre.y*TILE_SIZE+1.0)

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

# Scenery models name their textured surfaces PBR_*; the texture tier decides which maps they get.
func _apply_surfaces(root: Node):
	for node in root.find_children("*","MeshInstance3D",true,false):
		for i in node.mesh.get_surface_count():
			var base=node.mesh.surface_get_material(i)
			if base and base.resource_name.begins_with("PBR_"):node.set_surface_override_material(i,art.surface(base.resource_name,null,render_values))

func _world_props():
	_apply_surfaces(scenery)
	seagulls.setup(self)

func _look(player: int) -> PackedByteArray:
	var looks=state.get("piece_looks",[])
	return looks[player] if player>=0 and player<looks.size() and looks[player] is PackedByteArray else CatanAppearance.default_bytes()

func _full_detail() -> bool:
	return render_values.model_quality>0

## 0 when one of the vertex's roads can leave towards +z, 1 when one leaves towards -z.
func _gate_parity(vid: int) -> int:
	var v=state.vertices[vid]
	var e=state.edges[v.edges[0]]
	var other=state.vertices[e.b if e.a==vid else e.a]
	var rise=float(other.z)-float(v.z)
	return 0 if rise>.7 or (rise<0 and rise>-.7) else 1

func _house(parent: Node3D,color: Color,city: bool,look: PackedByteArray,parity: int):
	var root=living_world.town(look,color,city,parity,_full_detail())
	parent.add_child(root)
	dwellers.append_array(root.get_meta("dwellers",[]))
	var chimneys: Array=root.get_meta("chimneys",[])
	if chimneys.is_empty():return
	var smoke=CHIMNEY_SMOKE.instantiate()
	smoke.position=chimneys[0]
	smoke.emitting=render_values.particles>0 and not reduce_motion
	root.add_child(smoke)

func show_production(roll: int):
	if reduce_motion: return
	for tid in state.tiles.size():
		var tile=state.tiles[tid]
		if tile.number!=roll or tid==state.robber: continue
		var ring=PRODUCTION_RING.instantiate()
		ring.position=Vector3(tile.x,0.27,tile.z)
		terrain.add_child(ring)

func _animate_beacon():
	lighthouse.shine(elapsed,1.0-daylight)

func _float_boat(boat: Node3D):
	var p=Vector2(boat.global_position.x,boat.global_position.z)
	var storm=float(weather.current.storm) if is_instance_valid(weather) else 0.0
	var height=preload("res://scripts/ocean_waves.gd").height(p,elapsed*render_values.wind,storm,render_values.water_quality,water_centers,TILE_SIZE*.993)
	boat.position.y+=height/boat.get_parent().global_basis.get_scale().y

# A complete day lasts ten minutes of active play. Solo pause freezes the clock.
func advance_day(delta: float):
	if day_seconds+delta>=600.0:day_count+=1
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
		weather.update_weather(day_seconds,daylight,render_values,board_scale,day_count,int(state.get("seed",0)))
		var conditions=weather.current
		var overcast=float(conditions.clouds)
		var storm=float(conditions.storm)
		var direct_sun=float(conditions.sun_visibility)
		var sky_overcast=smoothstep(.28,.72,overcast)
		# Cloudy, rainy and stormy skies light the board diffusely, without sun shadows.
		# Clouds scatter the sun instead of blocking it: a third of it stays as
		# soft, shadowless light, and the sky fill rises to match.
		sun.light_energy*=lerpf(.34,1.0,direct_sun)
		sun.shadow_enabled=render_values.get("shadow_quality",3)>0 and direct_sun>.3
		env.ambient_light_energy=lerpf(lerpf(.65,.95,overcast*daylight),.6,storm)
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
		sky.set_shader_parameter("flash_direction",Vector3(-sin(conditions.strike_angle+.85),.35,-cos(conditions.strike_angle+.85)).normalized())
		sky.set_shader_parameter("rain_haze",float(conditions.rain))
		sea_material.set_shader_parameter("sun_strength",daylight*direct_sun)
		if seabed_material:seabed_material.set_shader_parameter("sun_strength",daylight*lerpf(.25,1.0,direct_sun))
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
	active_dice=DICE_THROW.instantiate();add_child(active_dice)
	active_dice.scale=Vector3.ONE*(TILE_SIZE/2.2)
	active_dice.setup(values,Vector3(tile.x*2.2,.9,(tile.z+.64)*2.2),reduce_motion)
	active_dice.settled.connect(show_production)

func player_color(player: int) -> Color:
	var colors=state.get("player_colors",[])
	var value=str(colors[player]) if player>=0 and player<colors.size() else ""
	return Color(value) if not value.is_empty() and CatanNetwork.valid_color(value) else PLAYERS[clampi(player,0,5)]
