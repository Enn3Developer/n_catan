extends CatanScreen
## Main menu: the player name, online host/join forms and the solo, tutorial
## and utility entries. Buttons only report intent; main.gd acts on it.

signal solo_requested
signal tutorial_requested
signal host_requested
signal join_requested
signal reconnect_requested
signal settings_requested
signal cosmetics_requested
signal music_requested
signal updates_requested
signal exit_requested

@onready var name_field: LineEdit=%PlayerName
@onready var address_field: LineEdit=%ServerAddress
@onready var password_field: LineEdit=%RoomPassword
@onready var host_password_field: LineEdit=%HostPassword

func _ready():
	%Version.text=CatanBuildInfo.VERSION

## Fills the form; a saved seat opens the join form with its connection details.
func setup(player_name: String,reconnect_address: String,reconnect_password: String,can_reconnect: bool):
	name_field.text=player_name
	%Reconnect.visible=can_reconnect
	if can_reconnect:
		%ShowOnline.button_pressed=true
		address_field.text=reconnect_address
		password_field.text=reconnect_password
		show_online_mode(false)

func show_online_mode(hosting: bool):
	%HostOptions.visible=hosting
	%JoinOptions.visible=not hosting
	%HostTab.set_pressed_no_signal(hosting)
	%JoinTab.set_pressed_no_signal(not hosting)
	layout_changed.emit()

func show_update_stage(stage: String):
	%CheckUpdates.text=tr("Update available") if stage=="available" else tr("Update ready") if stage=="ready" else tr("Game updates")

func arrange(viewport: Vector2,_overlay_bottom: float) -> Rect2:
	var panel: Control=%Expedition
	panel.offset_right=minf(390,viewport.x-90)
	var fixed_height=panel.get_theme_stylebox("panel").get_minimum_size().y+30
	for header: Control in [%Brand,%Title,%MenuNote]:fixed_height+=header.get_combined_minimum_size().y
	var scroll_height=minf(%MenuItems.get_combined_minimum_size().y,viewport.y-48-fixed_height)
	%MenuScroll.custom_minimum_size.y=maxf(0,scroll_height)
	panel.offset_top=-(fixed_height+scroll_height)*.5
	panel.offset_bottom=(fixed_height+scroll_height)*.5
	return Rect2(minf(410,viewport.x*.42),24,maxf(300,viewport.x-430),viewport.y-48)

func _on_show_online_toggled(shown: bool):
	%OnlineForm.visible=shown
	layout_changed.emit()
