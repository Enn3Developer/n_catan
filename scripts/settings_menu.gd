extends Control
signal preferences_changed
signal close_requested
signal updates_requested
signal exit_requested
const OPTIONS=[
	["Lighting","DayNightCycle","day_night_cycle","Day/night cycle","toggle",[],"Turn off to keep the island in daylight. This setting is personal.","Negligible"],
	["World","Language","language","Language","option",["English","Italiano"],"Choose the language used on this computer.","Accessibility"],
	["Lighting","Weather","weather","Weather","option",["Automatic","Clear skies","Cloudy","Rain","Thunderstorm"],"Choose changing weather or keep one condition. Rain and thunder use the ambience volume. Reduced motion disables rain and lightning flashes.","Clouds and rain"],
	["Display","Fullscreen","fullscreen","Fullscreen","toggle",[],"Fill the current display. Window size is used only in windowed mode.","Display"],
	["Display","WindowSize","window_size","Window size","option",["1280 × 720","1440 × 900","1920 × 1080","2560 × 1440","3840 × 2160"],"Size of the game window. Fullscreen uses your desktop resolution; render scale controls 3D resolution independently.","GPU workload increases with resolution"],
	["Display","VSync","vsync","Vertical sync","toggle",[],"Synchronize frame presentation with the display to prevent tearing. The frame limit can cap rendering below its refresh rate.","Can add input latency"],
	["Display","FrameLimit","frame_limit","Frame limit","option",["Unlimited","30 FPS","60 FPS","90 FPS","120 FPS","144 FPS","240 FPS"],"Limit rendering to reduce GPU load and power use. Does not change game rules or bot speed.","Power / smoothness"],
	["Display","RenderScale","render_scale","3D render scale","slider",[50,150,5,100],"Render the world below or above native resolution. Interface text stays at native resolution. 100% is native; 150% supersamples fine detail.","High GPU impact"],
	["Display","Upscaling","upscaling","Upscaling filter","option",["Bilinear","AMD FSR 1.0"],"FSR sharpens the world when rendering below 100%. It is spatial upscaling, without frame generation.","Useful at reduced render scale"],
	["Display","ShowFPS","show_fps","Performance overlay","toggle",[],"Show the live frame rate and rendering statistics during gameplay.","Negligible"],
	["Graphics","Quality","quality","Graphics preset","option",["Low","Medium","High","Ultra","Custom"],"Apply a coordinated set of model, texture, lighting, water and anti-aliasing settings. Individual changes switch this to Custom. Display and audio preferences are preserved.","Ultra favors image quality over frame rate"],
	["Graphics","ModelQuality","model_quality","Model detail","option",["Low","Medium","High","Ultra"],"Adjust terrain tessellation, mesh level-of-detail bias and small scene details. Large landmarks and gameplay pieces stay visible at every level.","CPU / GPU geometry"],
	["Graphics","TextureQuality","texture_quality","Texture resolution","option",["Low · 512 px","Medium · 1024 px","High · 2048 px"],"Change the actual albedo, normal and occlusion/roughness textures used by terrain, stone and wood. Higher settings retain detail during close inspection.","Video memory"],
	["Graphics","AntiAliasing","anti_aliasing","Anti-aliasing","option",["Off","FXAA","MSAA 2×","MSAA 4×","MSAA 8×","TAA"],"MSAA smooths geometry edges. FXAA is inexpensive. TAA also reduces vegetation shimmer but can soften moving details. Interface text remains sharp.","MSAA 8× has a high GPU cost"],
	["Graphics","Anisotropy","anisotropy","Anisotropic filtering","option",["Disabled","2×","4×","8×","16×"],"Keep terrain, roof and timber textures clear when viewed at an angle.","Low GPU impact"],
	["Graphics","FoliageQuality","foliage_quality","Vegetation density","option",["Sparse","Medium","Dense","Ultra"],"Control grass, ferns, wheat detail and flowers. Trees and resource-identifying landmarks remain visible.","Geometry and shadow cost"],
	["Graphics","Particles","particles","Particle effects","option",["Off","Low","High"],"Control drifting pollen, chimney smoke and atmospheric motes. Reduced motion also disables animated effects.","Low to moderate GPU impact"],
	["Lighting","ShadowQuality","shadow_quality","Shadow quality","option",["Off","Low · 1K","Medium · 2K","High · 4K","Ultra · 8K"],"Adjust directional shadow-map resolution and soft-shadow filtering. Higher levels preserve fine branches and architecture in shadows.","High GPU and memory impact"],
	["Lighting","AmbientOcclusion","ambient_occlusion","Ambient occlusion","option",["Off","Low","High"],"Add contact shading under grass, in rock cracks and around buildings using screen-space ambient occlusion.","Moderate GPU impact"],
	["Lighting","GlobalIllumination","global_illumination","Global illumination","option",["Ambient only","Screen-space bounce","SDFGI · Medium","SDFGI · High"],"Screen-space indirect lighting adds nearby bounced light. SDFGI traces a world-space distance field for broader indirect lighting. SDFGI may take a moment to converge after a change.","SDFGI has a high GPU cost"],
	["Lighting","Reflections","reflections","Reflections","option",["Sky only","Screen-space · Low","Screen-space · High"],"Reflect visible scenery on water and shiny surfaces. Screen-space reflections cannot include objects outside the camera view; sky reflection fills those regions.","Moderate to high GPU impact"],
	["Lighting","Bloom","bloom","Bloom","toggle",[],"Subtle light bleed from bright reflections and highlights. Does not blur interface text.","Low GPU impact"],
	["Lighting","Atmosphere","atmosphere","Atmospheric haze","toggle",[],"Use distance haze to soften distant water and scenery while keeping the board clear.","Low GPU impact"],
	["Lighting","DepthOfField","depth_of_field","Cinematic depth of field","toggle",[],"Gently soften scenery beyond the camera focus distance. Off keeps the whole board sharp for play. Focus a tile with F for close inspection.","Moderate GPU impact"],
	["Lighting","Exposure","exposure","Exposure","slider",[60,150,5,100],"Adjust scene brightness before cinematic tone mapping. Does not change the interface.","Negligible"],
	["World","WaterQuality","water_quality","Water detail","option",["Low","Medium","High","Ultra"],"Adjust ocean mesh resolution, wave layers, fine ripples and shoreline foam. Reflections are controlled in this Graphics tab.","Moderate GPU impact"],
	["World","Wind","wind","Wind strength","slider",[0,100,5,100],"Control foliage sway and wind-driven wave motion. Reduced motion overrides animated movement.","Negligible"],
	["World","ReducedMotion","reduce_motion","Reduced motion","toggle",[],"Stop wind, waves, scenery movement, particles and construction animations while retaining all gameplay actions.","Accessibility"],
	["World","LargeText","large_text","Larger small text","toggle",[],"Increase smaller interface labels for readability. Menus scroll when necessary.","Accessibility"],
	["World","Sensitivity","camera_speed","Camera sensitivity","slider",[0.4,2.0,0.1,1],"Adjust orbit and pan speed. Right-drag orbits; middle-drag pans; the wheel zooms; Home fits the board.","Controls"],
	["World","BotSpeed","bot_speed","Bot turn speed","option",["Relaxed","Normal","Fast"],"Adjust the pause between bot actions without changing their difficulty or decisions.","Gameplay"],
	["Audio","Master","master","Master volume","slider",[0,100,1,100],"Overall volume, including music, effects and ocean ambience.","Audio"],
	["Audio","Music","music","Music","slider",[0,100,1,100],"Volume of the original instrumental soundtrack.","Audio"],
	["Audio","Effects","effects","Sound effects","slider",[0,100,1,100],"Volume of interface and gameplay cues.","Audio"],
	["Audio","Ambience","ambience","Ocean ambience","slider",[0,100,1,100],"Volume of the ocean soundscape.","Audio"]]
var preferences: CatanSettings
const ROWS={"option":preload("res://scenes/ui/option_setting.tscn"),"toggle":preload("res://scenes/ui/toggle_setting.tscn"),"slider":preload("res://scenes/ui/slider_setting.tscn")}
var tabs={}
var controls={}
var rows={}
var updating=false
var last_tab="Graphics"
## The long Graphics tab is split into these groups, in this order.
const GROUPS=["Graphics","Lighting","Water and wind","Display"]

func _ready():
	%Version.text=CatanBuildInfo.VERSION
	tabs={"Graphics":%GraphicsScroll,"World":%WorldScroll,"Audio":%AudioScroll}
	var pages={"Graphics":%GraphicsOptions,"World":%WorldOptions,"Audio":%AudioOptions}
	var groups={}
	for spec in OPTIONS:
		var page="Graphics" if spec[0] in ["Display","Graphics","Lighting"] or spec[2] in ["water_quality","wind"] else spec[0]
		if page!="Graphics":_add_control(pages[page],spec)
		else:
			var group="Water and wind" if spec[2] in ["water_quality","wind"] else spec[0]
			if not groups.has(group):groups[group]=[]
			groups[group].append(spec)
	for group in GROUPS:
		var heading=Label.new()
		# Labels translate their own text, so the heading follows a language change.
		heading.text=group
		heading.uppercase=true
		heading.theme_type_variation=&"SectionLabel"
		%GraphicsOptions.add_child(heading)
		for spec in groups.get(group,[]):_add_control(%GraphicsOptions,spec)
	_layout()

func _layout():
	%Help.visible=size.x>=1160

func setup(settings: CatanSettings):
	preferences=settings
	refresh()
	select_tab(last_tab)

func _add_control(parent: Node,spec: Array):
	var row=ROWS[spec[4]].instantiate()
	parent.add_child(row)
	controls[spec[2]]=row.show_spec(spec)
	rows[spec[2]]=row
	row.changed.connect(_change)
	row.hovered.connect(_help)

func _on_reset_pressed():
	preferences.reset()
	refresh()
	preferences_changed.emit()

func _change(spec: Array,value: Variant):
	if updating:return
	preferences.set_value(spec[2],value)
	if spec[2]=="language":CatanI18n.apply(int(value))
	refresh()
	preferences_changed.emit()

func refresh():
	updating=true
	for spec in OPTIONS:rows[spec[2]].show_value(preferences.values[spec[2]])
	controls.fullscreen.disabled=CatanSettings.embedded_window()
	controls.window_size.disabled=preferences.values.fullscreen or CatanSettings.embedded_window()
	var forward=RenderingServer.get_current_rendering_method()=="forward_plus"
	controls.anti_aliasing.set_item_disabled(5,not forward)
	for key in ["global_illumination","ambient_occlusion","reflections","depth_of_field"]:
		controls[key].set("disabled",not forward)
	%RendererInfo.text="FORWARD+ / VULKAN" if forward else tr("COMPATIBILITY / LIMITED LIGHTING")
	%SettingsNote.text=tr("Saved automatically") if forward else tr("Some lighting features require Forward+. Restart using the default renderer to enable them.")
	updating=false

func select_tab(title: String):
	last_tab=title
	for key in tabs: tabs[key].visible=key==title
	for child in %Navigation.get_children():
		if child is Button:child.set_pressed_no_signal(child.name==title+"Tab")
	# Show the first setting of the tab until another one is hovered.
	for row in tabs[title].get_child(0).get_children():
		if row.has_method("show_spec"):
			for spec in OPTIONS:
				if rows.get(spec[2])==row:_help(spec);return

func _help(spec: Array):
	%HelpTitle.text=spec[3]
	%HelpBody.text=spec[6]
	%HelpCost.text=spec[7]

