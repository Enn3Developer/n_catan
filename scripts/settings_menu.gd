extends Control
signal preferences_changed
signal close_requested
const OPTIONS=[
	["World","Language","language","Language","option",["English","Italiano"],"Choose the language used on this computer.","Accessibility"],
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
var tabs={}
var controls={}
var updating=false
var last_tab="Graphics"
var stats_clock=0.0

func _ready():
	resized.connect(_layout)
	_layout()

func _layout():
	if is_instance_valid(find_child("Help",true,false)):find_child("Help",true,false).visible=size.x>=1160

func setup(settings: CatanSettings):
	%Version.text=CatanBuildInfo.VERSION
	preferences=settings
	for title in ["Graphics","World","Audio"]:
		var scroll=ScrollContainer.new()
		scroll.name=title+"Scroll"
		scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		%SettingsContent.add_child(scroll)
		var box=VBoxContainer.new()
		box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation",8)
		scroll.add_child(box)
		var heading=Label.new()
		heading.name=title+"Heading"
		heading.text=title.to_upper()
		heading.add_theme_font_size_override("font_size",17)
		heading.add_theme_color_override("font_color",Color("8c522d"))
		box.add_child(heading)
		tabs[title]=scroll
		var nav=Button.new()
		nav.name=title+"Tab"
		nav.text={"Display":"Display","Graphics":"Graphics","Lighting":"Lighting","World":"Controls","Audio":"Audio"}[title]
		nav.alignment=HORIZONTAL_ALIGNMENT_LEFT
		nav.custom_minimum_size.y=38
		nav.toggle_mode=true
		%Navigation.add_child(nav)
		nav.pressed.connect(func():select_tab(title))
		for spec in OPTIONS:
			var group="Graphics" if spec[0] in ["Display","Graphics","Lighting"] or spec[2] in ["water_quality","wind"] else spec[0]
			if group==title: _add_control(box,spec)
	%CloseSettings.pressed.connect(func():close_requested.emit())
	%ResetSettings.pressed.connect(func():preferences.reset();refresh();preferences_changed.emit())
	refresh()
	select_tab(last_tab)
	_help(OPTIONS[8])

func _add_control(parent: Node,spec: Array):
	var panel=PanelContainer.new()
	panel.name=spec[1]+"Row"
	var style=StyleBoxFlat.new()
	style.bg_color=Color("eedab0")
	style.content_margin_left=14
	style.content_margin_right=14
	style.content_margin_top=10
	style.content_margin_bottom=10
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	panel.add_child(row)
	var label=Label.new()
	label.text=spec[3]
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label.custom_minimum_size.x=160
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",17)
	row.add_child(label)
	var control: Control
	if spec[4]=="option":
		var option=OptionButton.new()
		for text in spec[5]: option.add_item(text)
		option.item_selected.connect(func(value):_change(spec,value))
		control=option
	elif spec[4]=="toggle":
		var toggle=CheckButton.new()
		toggle.text=""
		toggle.toggled.connect(func(value):_change(spec,value))
		control=toggle
	else:
		var slider=HSlider.new()
		slider.min_value=spec[5][0]
		slider.max_value=spec[5][1]
		slider.step=spec[5][2]
		slider.custom_minimum_size.x=130
		slider.value_changed.connect(func(value):_change(spec,value/spec[5][3]))
		control=slider
	control.name=spec[1]
	control.custom_minimum_size.x=200
	control.custom_minimum_size.y=36
	control.tooltip_text=spec[6]
	row.add_child(control)
	control.mouse_entered.connect(func():_help(spec))
	control.focus_entered.connect(func():_help(spec))
	panel.mouse_entered.connect(func():_help(spec))
	controls[spec[2]]=control
	if spec[4]=="slider":
		var value=Label.new()
		value.name=spec[1]+"Value"
		value.custom_minimum_size.x=55
		value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)

func _change(spec: Array,value: Variant):
	if updating:return
	preferences.set_value(spec[2],value)
	if spec[2]=="language":CatanI18n.apply(int(value))
	refresh()
	preferences_changed.emit()

func refresh():
	updating=true
	for spec in OPTIONS:
		var control=controls[spec[2]]
		var value=preferences.values[spec[2]]
		if control is OptionButton: control.select(value)
		elif control is CheckButton: control.set_pressed_no_signal(value)
		else:
			control.set_value_no_signal(value*spec[5][3])
			var label=find_child(spec[1]+"Value",true,false)
			label.text="%.1f×" % value if spec[2]=="camera_speed" else "%d%%" % (value*100)
	controls.window_size.disabled=preferences.values.fullscreen
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

func _help(spec: Array):
	%HelpTitle.text=spec[3]
	%HelpBody.text=spec[6]
	%HelpCost.text=spec[7]

func _process(delta):
	stats_clock-=delta
	if stats_clock>0:return
	stats_clock=.5
	%Performance.text=tr("%d FPS · %.1f ms / frame · %.0f MB VRAM") % [Engine.get_frames_per_second(),1000.0/maxf(1,Engine.get_frames_per_second()),Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0]
