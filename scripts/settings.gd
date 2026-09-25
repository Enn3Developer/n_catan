class_name CatanSettings
extends RefCounted

const DEFAULTS={"weather":0,"day_night_cycle":true,"master":0.8,"music":0.42,"effects":0.75,"ambience":0.45,"weather_volume":0.5,"fullscreen":false,"vsync":true,"quality":2,"reduce_motion":false,"large_text":false,"camera_speed":1.0,"bot_speed":1,"player_name":"Voyager","window_size":1,"frame_limit":0,"render_scale":1.0,"anti_aliasing":3,"upscaling":0,"anisotropy":4,"model_quality":2,"texture_quality":2,"foliage_quality":2,"shadow_quality":3,"ambient_occlusion":2,"global_illumination":1,"reflections":2,"water_quality":2,"particles":2,"bloom":true,"atmosphere":true,"depth_of_field":false,"exposure":1.0,"wind":0.65,"show_fps":false,"appearance":"","player_color":"","language":0}
const PRESETS=[
	{"model_quality":0,"texture_quality":0,"foliage_quality":0,"shadow_quality":1,"ambient_occlusion":0,"global_illumination":0,"reflections":0,"water_quality":0,"particles":0,"anti_aliasing":1,"anisotropy":1,"bloom":false,"atmosphere":false,"depth_of_field":false},
	{"model_quality":1,"texture_quality":1,"foliage_quality":1,"shadow_quality":2,"ambient_occlusion":1,"global_illumination":0,"reflections":1,"water_quality":1,"particles":1,"anti_aliasing":2,"anisotropy":2,"bloom":true,"atmosphere":true,"depth_of_field":false},
	{"model_quality":2,"texture_quality":2,"foliage_quality":2,"shadow_quality":3,"ambient_occlusion":2,"global_illumination":1,"reflections":2,"water_quality":2,"particles":2,"anti_aliasing":3,"anisotropy":4,"bloom":true,"atmosphere":true,"depth_of_field":false},
	{"model_quality":3,"texture_quality":2,"foliage_quality":3,"shadow_quality":4,"ambient_occlusion":2,"global_illumination":3,"reflections":2,"water_quality":3,"particles":2,"anti_aliasing":4,"anisotropy":4,"bloom":true,"atmosphere":true,"depth_of_field":false}]
const FRAME_LIMITS=[0,30,60,90,120,144,240]
const WINDOW_SIZES=[Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(3840,2160)]
const LIMITS={"weather":4,"language":1,"quality":4,"window_size":4,"frame_limit":6,"anti_aliasing":5,"upscaling":1,"anisotropy":4,"model_quality":3,"texture_quality":2,"foliage_quality":3,"shadow_quality":4,"ambient_occlusion":2,"global_illumination":3,"reflections":2,"water_quality":3,"particles":2,"bot_speed":2}
const SLIDERS={"master":[0.0,1.0],"music":[0.0,1.0],"effects":[0.0,1.0],"ambience":[0.0,1.0],"weather_volume":[0.0,1.0],"camera_speed":[0.4,2.0],"render_scale":[0.5,1.5],"exposure":[0.6,1.5],"wind":[0.0,1.0]}
var values=DEFAULTS.duplicate()
var path="user://settings.cfg"
var applied_window=-1
var applied_fullscreen=-1
var applied_anisotropy=-1

func _init(config_path: String="user://settings.cfg"):
	path=config_path
	var config=ConfigFile.new()
	if config.load(path)==OK:
		for key in DEFAULTS:
			values[key]=_sanitize(key,config.get_value("preferences",key,DEFAULTS[key]))
		# Old three-preset files migrate into the new renderer settings coherently.
		if not config.has_section_key("preferences","model_quality") and values.quality<4:
			values.merge(PRESETS[values.quality],true)
		# The four fixed piece sets became presets of the appearance editor.
		if not config.has_section_key("preferences","appearance") and config.has_section_key("preferences","piece_style"):
			var old_set=clampi(int(config.get_value("preferences","piece_style",0)),0,CatanAppearance.PRESETS.size()-1)
			values.appearance=CatanAppearance.encode(CatanAppearance.preset(old_set)).hex_encode()

func _sanitize(key: String,value: Variant) -> Variant:
	if key=="appearance": return "" if str(value).is_empty() else CatanAppearance.from_hex(str(value)).hex_encode()
	if key=="player_color": return str(value).to_lower() if str(value).is_empty() or (str(value).length()==6 and Color.html_is_valid(str(value))) else ""
	if LIMITS.has(key): return clampi(int(value),0,LIMITS[key]) if value is int or value is float else DEFAULTS[key]
	if SLIDERS.has(key): return clampf(float(value),SLIDERS[key][0],SLIDERS[key][1]) if (value is int or value is float) and is_finite(float(value)) else DEFAULTS[key]
	if DEFAULTS[key] is bool: return value if value is bool else DEFAULTS[key]
	return str(value).substr(0,20)

func set_value(key: String,value: Variant):
	if not DEFAULTS.has(key): return
	values[key]=_sanitize(key,value)
	if key=="quality" and values.quality<4:
		values.merge(PRESETS[values.quality],true)
	elif PRESETS[2].has(key):
		values.quality=4
	save()

func save():
	var config=ConfigFile.new()
	for key in values: config.set_value("preferences",key,values[key])
	config.save(path)

func reset():
	values=DEFAULTS.duplicate()
	save()

## The player's piece appearance, packed for the network.
func look() -> PackedByteArray:
	return CatanAppearance.from_hex(values.appearance)

static func embedded_window() -> bool:
	return Array(OS.get_cmdline_args()).any(func(arg):return arg=="--wid" or arg.begins_with("--wid="))

func apply_display(viewport: Viewport):
	if DisplayServer.get_name()!="headless" and not embedded_window():
		if applied_fullscreen!=int(values.fullscreen):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
			applied_fullscreen=int(values.fullscreen)
			applied_window=-1
		if not values.fullscreen and applied_window!=values.window_size:
			DisplayServer.window_set_size(WINDOW_SIZES[values.window_size])
			applied_window=values.window_size
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=FRAME_LIMITS[values.frame_limit]
	viewport.scaling_3d_scale=values.render_scale
	viewport.scaling_3d_mode=Viewport.SCALING_3D_MODE_FSR if values.upscaling==1 else Viewport.SCALING_3D_MODE_BILINEAR
	viewport.msaa_3d=[Viewport.MSAA_DISABLED,Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X,Viewport.MSAA_8X,Viewport.MSAA_DISABLED][values.anti_aliasing]
	viewport.screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA if values.anti_aliasing==1 else Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_taa=values.anti_aliasing==5 and RenderingServer.get_current_rendering_method()=="forward_plus"
	# This Godot version exposes filtering per viewport, so changes need no restart.
	if applied_anisotropy!=values.anisotropy:
		RenderingServer.viewport_set_anisotropic_filtering_level(viewport.get_viewport_rid(),values.anisotropy)
		applied_anisotropy=values.anisotropy
