extends SceneTree
# Joining from the main menu: invite checks, progress, inline failures and cancel.
const INVITE=preload("res://scripts/secure_invite.gd")
var checks=0
var failures=0
var game
var host
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func shot(label: String):
	for i in 8:await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/catan-join-"+label+".png")
func home() -> bool:
	return game.screen.scene_file_path=="res://scenes/ui/home.tscn"
func run():
	# A successful join saves a reconnect seat; put back whatever was there.
	var saved_session=FileAccess.get_file_as_string("user://reconnect.cfg") if FileAccess.file_exists("user://reconnect.cfg") else null
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await create_timer(.4).timeout
	var branch=Node.new();branch.name="Host";root.add_child(branch);set_multiplayer(SceneMultiplayer.new(),branch.get_path())
	var peer_root=Node.new();peer_root.name="Catan";branch.add_child(peer_root)
	host=CatanNetwork.new();host.name="Network";peer_root.add_child(host)
	host.host("Host","harbor")
	var code=host.invite("127.0.0.1")
	DisplayServer.clipboard_set("")
	game.address_field.clear();game.address_field.text_changed.emit("")
	game._node("ShowOnline").button_pressed=true
	game.screen.show_online_mode(false)
	check(game._node("JoinOnline").disabled,"join waits for an invite code")
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD) and DisplayServer.get_name()!="headless":
		game.screen.show_online_mode(true);DisplayServer.clipboard_set(code);game.screen.show_online_mode(false)
		check(game.address_field.text==code and not game._node("JoinOnline").disabled,"an invite on the clipboard fills the join form")
	game.address_field.clear();DisplayServer.clipboard_set("")
	game.address_field.text="192.168.1.4";game.address_field.text_changed.emit(game.address_field.text)
	check(game._node("JoinOnline").disabled and game._node("JoinStatus").theme_type_variation==&"ErrorLabel","a bare address is flagged before joining")
	check("NC1-" in game._node("JoinStatus").text,"the hint says what an invite looks like")
	game.address_field.text=code.substr(0,code.length()-3);game.address_field.text_changed.emit(game.address_field.text)
	check(game._node("JoinOnline").disabled and "incomplete" in game._node("JoinStatus").text,"a truncated invite is flagged")
	game.address_field.text=code;game.address_field.text_changed.emit(code)
	check(not game._node("JoinOnline").disabled and game._node("JoinStatus").theme_type_variation==&"","a valid invite enables joining")
	await shot("ready")

	game.password_field.text="wrong"
	game._node("JoinOnline").pressed.emit();await process_frame;await process_frame
	check(home() and game.joining,"the guest stays on the menu while connecting")
	check(game._node("CancelJoin").visible and game._node("JoinOnline").disabled and not game.address_field.editable,"connecting locks the form and offers cancel")
	await shot("connecting")
	await create_timer(1.5).timeout
	check(not game.joining and not game.net.online and home(),"a refused join returns to the menu")
	check(game._node("JoinOptions").visible and game._node("OnlineForm").visible,"the join form stays open after a refusal")
	check(game.address_field.text==code and game.address_field.editable,"the invite survives a refusal")
	check("password" in game._node("JoinStatus").text.to_lower() and game._node("JoinStatus").theme_type_variation==&"ErrorLabel","the refusal reason stays next to the form")
	check(game.password_field.text.is_empty(),"a wrong password is cleared for retyping")
	check(not game._node("CancelJoin").visible and not game._node("JoinOnline").disabled,"the form unlocks after a refusal")
	await shot("wrong-password")

	game.password_field.text="harbor"
	game.password_field.text_submitted.emit("harbor")
	await create_timer(1.5).timeout
	check(game.net.seat==1 and host.roster.size()==2,"enter in the password field joins")
	check(game.screen.scene_file_path=="res://scenes/ui/lobby.tscn" and not game.joining,"a seated guest reaches the lobby")
	game.net.leave();await create_timer(.3).timeout

	var unreachable=INVITE.encode("127.0.0.1:24990",INVITE.decode(code).pin)
	game.screen.open_join(unreachable,"")
	game._node("JoinOnline").pressed.emit();await create_timer(.3).timeout
	check(game.net.online and game.joining,"an unreachable host keeps connecting")
	game._node("CancelJoin").pressed.emit();await process_frame;await process_frame
	check(not game.net.online and not game.joining and home(),"cancel abandons the connection")
	check(game.address_field.text==unreachable and not game._node("CancelJoin").visible,"cancel keeps the invite for another try")
	game._node("JoinOnline").pressed.emit();await create_timer(11).timeout
	check(not game.net.online and not game.joining and home(),"an unreachable host times out on the menu")
	check("failed" in game._node("JoinStatus").text.to_lower(),"the timeout is explained next to the form")
	await shot("timeout")

	if saved_session==null:DirAccess.remove_absolute(ProjectSettings.globalize_path("user://reconnect.cfg"))
	else:
		var file=FileAccess.open("user://reconnect.cfg",FileAccess.WRITE);file.store_string(saved_session);file.close()
	game.queue_free();host.leave();await create_timer(.2).timeout;branch.queue_free();await process_frame;await process_frame
	print("JOIN_ROOM_TEST: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
