extends SceneTree
var checks=0
var failures=0
var game
const WEATHER=preload("res://scripts/weather.gd")
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func shot(label: String):
	if DisplayServer.get_name()=="headless":return
	await create_timer(.65).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/catan-weather-"+label+".png")
func run():
	check(WEATHER.sample(150).rain==0,"new game begins dry")
	check(WEATHER.sample(150,1).clouds>0 and WEATHER.sample(150,1).clouds<.25,"clear weather has sparse clouds")
	check(WEATHER.sample(150,1).sun_visibility==1.0,"sparse clouds preserve direct sunlight")
	check(WEATHER.sample(350).storm>.9,"automatic weather reaches a storm")
	for time in range(0,600,5):
		var a=WEATHER.sample(time);var b=WEATHER.sample(time+.01)
		check(absf(a.rain-b.rain)<.001 and absf(a.clouds-b.clouds)<.001,"weather transitions are continuous")
	check(absf(WEATHER.sample(599.99).clouds-WEATHER.sample(0).clouds)<.001,"weather is continuous when the shared clock wraps")
	check(WEATHER.sample(355,4).thunder and not WEATHER.sample(353,4).thunder,"thunder follows the lightning flash")
	game=load("res://scenes/main.tscn").instantiate()
	game.preferences=CatanSettings.new("user://weather-test.cfg");game.preferences.values=CatanSettings.DEFAULTS.duplicate()
	game.preferences.values.day_night_cycle=false
	root.add_child(game);await create_timer(.4).timeout;game.set_process(false)
	var board=game.board;board.set_process(false)
	game.ui.hide();board.view_region=Rect2();board.show_labels=false
	for entry in board.board_labels:entry.label.hide()
	board.camera_focus=Vector3.ZERO;board.camera_zoom=1.05;board.pitch=.55;board._update_camera()
	var nodes=board.weather.get_child_count()
	for mode in range(1,5):
		game.preferences.values.weather=mode;board.apply_preferences(game.preferences.values)
		board.day_seconds=155;board.advance_day(0)
		var state=board.weather.current
		check(board.get_node("WorldEnvironment").environment.sky.sky_material.get_shader_parameter("cloud_cover")==state.clouds,"sky coverage follows selected weather")
		check(board.weather.rain.emitting==(mode>=3),"rain matches selected weather")
		check((board.sea_material.get_shader_parameter("sun_strength")>0)==(mode==1),"cloudy, rainy and stormy skies remove sun reflection")
		check(board.get_node("Sun").shadow_enabled==(mode==1),"cloudy, rainy and stormy skies have no directional shadows")
		check((board.get_node("Sun").light_energy>0)==(mode==1),"cloudy, rainy and stormy skies use diffuse sky lighting")
		game.audio.follow_weather(state,3)
		check(game.audio.rain_ambience.playing==(mode>=3),"rain ambience follows weather")
		await shot(["clear","cloudy","rain","storm"][mode-1])
	board.day_seconds=143;board.advance_day(0)
	check(board.weather.lightning.visible and board.weather.lightning_light.light_energy>0,"thunderstorm includes a distant lightning strike")
	await shot("lightning")
	board.day_seconds=145;board.advance_day(0);game.audio.follow_weather(board.weather.current,.1)
	check(game.audio.thunder_ambience.playing,"thunder audio plays after lightning")
	game.audio.thunder_ambience.stop();game.audio.follow_weather(board.weather.current,.1)
	check(not game.audio.thunder_ambience.playing,"duplicate snapshots do not replay thunder")
	game.audio.apply({"master":.8,"music":.4,"effects":.7,"ambience":0.0})
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Ambience")),"ambience volume mutes both weather sounds")
	board.advance_day(0)
	check(board.weather.get_child_count()==nodes,"weather updates reuse effects rather than creating nodes")
	game.preferences.values.reduce_motion=true;board.apply_preferences(game.preferences.values)
	board.day_seconds=143;board.advance_day(0)
	check(not board.weather.rain.visible and not board.weather.lightning.visible,"reduced motion removes falling rain and flashes")
	var cloud_time=board.get_node("WorldEnvironment").environment.sky.sky_material.get_shader_parameter("animation_time")
	board.day_seconds=151;board.advance_day(0)
	check(board.get_node("WorldEnvironment").environment.sky.sky_material.get_shader_parameter("animation_time")==cloud_time,"reduced motion freezes clouds")
	game.preferences.values.reduce_motion=false;game.preferences.values.particles=0;board.apply_preferences(game.preferences.values)
	check(not board.weather.rain.emitting,"particle setting disables rain particles")
	game.preferences.values.particles=1;board.apply_preferences(game.preferences.values)
	check(board.weather.rain.amount==400,"low particle setting caps rainfall")
	game.preferences.values.particles=2;game.preferences.values.weather=1;game.preferences.values.day_night_cycle=true;board.apply_preferences(game.preferences.values)
	board.day_seconds=450;board.advance_day(0)
	check(board.sea_material.get_shader_parameter("sun_strength")==0.0,"no sunlight reflection at night")
	await shot("night")
	game.preferences.values.day_night_cycle=false;board.apply_preferences(game.preferences.values)
	var sun_direction=board.get_node("Sun").global_basis.z.normalized()
	var focus=Vector3(0,0,-200)
	board.camera.h_offset=0;board.camera.v_offset=0
	board.camera.position=focus+Vector3(-sun_direction.x,sun_direction.y,-sun_direction.z)*260
	board.camera.look_at(focus)
	board.sea_material.set_shader_parameter("animation_time",12.0)
	await shot("sun-water")
	board.sea_material.set_shader_parameter("animation_time",15.0)
	await shot("sun-water-next")
	# A low camera angle exposes the sky layer above the horizon.
	game.preferences.values.weather=1;board.apply_preferences(game.preferences.values)
	board.camera.position=Vector3(0,18,210);board.camera.look_at(Vector3(0,70,-300))
	var sky=board.get_node("WorldEnvironment").environment.sky.sky_material
	sky.set_shader_parameter("animation_time",12.0)
	await shot("clear-sky")
	game.preferences.values.weather=2;board.apply_preferences(game.preferences.values)
	await shot("sky")
	sky.set_shader_parameter("animation_time",24.0)
	await shot("sky-next")
	game.preferences.values.weather=1;game.preferences.values.shadow_quality=0;board.apply_preferences(game.preferences.values)
	check(not board.get_node("Sun").shadow_enabled,"clear weather respects disabled shadows")
	var waves=preload("res://scripts/ocean_waves.gd")
	check(absf(waves.height(Vector2(200,0),0,0,2,board.water_centers,24.825)-waves.height(Vector2(200,0),2,0,2,board.water_centers,24.825))>.1,"offshore wave crests travel over time")
	check(is_zero_approx(waves.height(board.water_centers[0],12,1,2,board.water_centers,24.825)),"swells taper away beneath the island")
	game._open_settings();game.ui.show()
	root.size=Vector2i(800,600)
	check(game.modal.controls.has("weather"),"weather selector is available in settings")
	CatanI18n.apply(1)
	check(TranslationServer.translate("Thunderstorm")=="Temporale","weather names translate into Italian")
	await shot("settings-it")
	game.queue_free();await create_timer(.2).timeout;await process_frame
	print("WEATHER_TEST: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
