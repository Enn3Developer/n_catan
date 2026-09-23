extends CatanScreen
## Main menu: the player name, online host/join forms and the solo, tutorial
## and utility entries. Buttons only report intent; main.gd acts on it.

signal solo_requested
signal tutorial_requested
signal host_requested
signal join_requested
signal join_cancel_requested
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

const SECURE_INVITE=preload("res://scripts/secure_invite.gd")
const INVITE_HELP="Ask the host to copy the invite from their room."
var connecting=false

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
	_on_invite_changed(address_field.text)

## Opens the join form with the details of the last attempt.
func open_join(address: String,password: String):
	%ShowOnline.button_pressed=true
	show_online_mode(false)
	address_field.text=address
	password_field.text=password
	_on_invite_changed(address)

## While connecting the form is locked and offers Cancel instead of Join.
func show_connecting(active: bool):
	connecting=active
	for field: LineEdit in [name_field,address_field,password_field]:field.editable=not active
	for button: Button in [%PasteInvite,%HostTab,%JoinTab,%ShowOnline,%Reconnect,%Singleplayer,%Learn]:button.disabled=active
	%CancelJoin.visible=active
	%JoinOnline.disabled=active
	%JoinOnline.text=tr("Connecting…") if active else tr("Join room")
	if active:_status(tr("Reaching the host. This can take up to 10 seconds."))
	else:_on_invite_changed(address_field.text)
	layout_changed.emit()

## Keeps a failed join visible next to the form instead of in a passing toast.
func show_join_error(message: String):
	show_connecting(false)
	_status(CatanI18n.render(message),true)
	if "password" in message.to_lower():
		password_field.clear()
		password_field.grab_focus.call_deferred()

func _status(text: String,error: bool=false):
	%JoinStatus.text=text
	%JoinStatus.theme_type_variation=&"ErrorLabel" if error else &""

func _invite_valid(code: String) -> bool:
	return not SECURE_INVITE.decode(code).is_empty()

func show_online_mode(hosting: bool):
	if not hosting and address_field.text.strip_edges().is_empty():
		var clipboard=DisplayServer.clipboard_get().strip_edges()
		if _invite_valid(clipboard):
			address_field.text=clipboard
			_on_invite_changed(clipboard)
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

func _on_invite_changed(code: String):
	if connecting:return
	code=code.strip_edges()
	var valid=_invite_valid(code)
	%JoinOnline.disabled=not valid
	if code.is_empty():_status(tr(INVITE_HELP))
	elif valid:_status(tr("Invite code ready. Add the password if the host set one."))
	elif not code.begins_with(SECURE_INVITE.PREFIX):_status(tr("Invite codes start with NC1-. Copy the whole code from the host's room."),true)
	else:_status(tr("This invite code is incomplete or mistyped. Copy it again from the host."),true)

func _on_paste_invite_pressed():
	address_field.text=DisplayServer.clipboard_get().strip_edges()
	_on_invite_changed(address_field.text)
	if _invite_valid(address_field.text):password_field.grab_focus()

func _on_invite_submitted(_code: String):
	password_field.grab_focus()

func _on_join_pressed():
	if connecting or not _invite_valid(address_field.text):return
	join_requested.emit()
