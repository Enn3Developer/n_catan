extends CatanScreen
## Main menu: the player name, the invite field, hosting and the solo, tutorial
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
var connecting=false

func _ready():
	%Version.text=CatanBuildInfo.VERSION

## Fills the menu. The invite field starts empty; Reconnect keeps its own details.
func setup(player_name: String,can_reconnect: bool):
	name_field.text=player_name
	%Reconnect.visible=can_reconnect
	_refresh()

## Restores the details of the last attempt.
func open_join(address: String,password: String):
	address_field.text=address
	password_field.text=password
	_refresh()

## While connecting the form is locked and offers Cancel instead.
func show_connecting(active: bool):
	connecting=active
	for field: LineEdit in [name_field,address_field,password_field]:field.editable=not active
	for button: Button in [%ShowOnline,%HostOnline,%Reconnect,%Singleplayer,%Learn]:button.disabled=active
	%CancelJoin.visible=active
	%JoinOnline.text=tr("Connecting…") if active else tr("Join")
	_refresh()
	if active:_status(tr("Reaching the host. This can take up to 10 seconds."))

## Keeps a failed join next to the form instead of in a passing toast.
func show_join_error(message: String):
	show_connecting(false)
	if "password" in message.to_lower():
		# The password field only appears once a room asks for one.
		var missing=password_field.text.is_empty()
		password_field.clear()
		password_field.show()
		password_field.grab_focus.call_deferred()
		_status(tr("This room needs a password. Enter it and press Enter.") if missing else CatanI18n.render(message),true)
	else:_status(CatanI18n.render(message),true)
	layout_changed.emit()

func _status(text: String,error: bool=false):
	%JoinStatus.text=text
	%JoinStatus.visible=not text.is_empty()
	%JoinStatus.theme_type_variation=&"ErrorLabel" if error else &""
	layout_changed.emit()

func _invite_valid(code: String) -> bool:
	return not SECURE_INVITE.decode(code).is_empty()

func _refresh():
	if not password_field.text.is_empty():password_field.show()
	var code=address_field.text.strip_edges()
	%JoinOnline.disabled=connecting or not _invite_valid(code)
	if connecting:return
	if code.is_empty() or _invite_valid(code):_status("")
	elif not code.begins_with(SECURE_INVITE.PREFIX):_status(tr("Invite codes start with NC1-. Copy the whole code from the host's room."),true)
	else:_status(tr("This invite code is incomplete or mistyped. Copy it again from the host."),true)

func show_update_stage(stage: String):
	%CheckUpdates.text=tr("Update available") if stage=="available" else tr("Update ready") if stage=="ready" else tr("Game updates")

func arrange(viewport: Vector2,_overlay_bottom: float) -> Rect2:
	var panel: Control=%Expedition
	panel.offset_right=minf(420,viewport.x-90)
	# The panel's own padding plus the gap between the logo and the menu.
	var fixed_height=panel.get_theme_stylebox("panel").get_minimum_size().y+%ExpeditionBody.get_theme_constant("separation")
	for header: Control in [%Title]:fixed_height+=header.get_combined_minimum_size().y
	var scroll_height=minf(%MenuItems.get_combined_minimum_size().y,viewport.y-48-fixed_height)
	%MenuScroll.custom_minimum_size.y=maxf(0,scroll_height)
	panel.offset_top=-(fixed_height+scroll_height)*.5
	panel.offset_bottom=(fixed_height+scroll_height)*.5
	return Rect2(minf(440,viewport.x*.42),24,maxf(300,viewport.x-460),viewport.y-48)

func _on_show_online_toggled(shown: bool):
	%OnlineForm.visible=shown
	layout_changed.emit()

func _on_invite_changed(code: String):
	if connecting:return
	password_field.clear()
	password_field.hide()
	_refresh()
	# A pasted or completely typed invite joins without another click.
	if _invite_valid(code):_on_join_pressed()

func _on_join_pressed():
	if connecting or not _invite_valid(address_field.text):return
	join_requested.emit()
