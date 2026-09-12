extends SceneTree
var checks=0
var failures=0
var game
var client
var notices=[]
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await create_timer(.4).timeout
	check(game.address_field.placeholder_text=="Paste invite code","join form asks for compact invite")
	game._node("ShowOnline").button_pressed=true
	check(game._node("HostOptions").visible and not game._node("JoinOptions").visible,"hosting has its own visible form")
	game.host_password_field.text="test-host-password"
	game.password_field.text="different-join-password"
	game._online_mode(false)
	check(game._node("JoinOptions").visible and not game._node("HostOptions").visible,"join form is separate")
	game._online_mode(true)
	check(game.host_password_field.text=="test-host-password","switching tabs preserves host password")
	game._node("HostOnline").pressed.emit();await create_timer(.2).timeout
	check(game.net.online and game.net.room_password=="test-host-password","create room uses host password, not join password")
	check("Password required" in game._node("RoomSummary").text,"lobby confirms password requirement")
	var branch=Node.new();branch.name="Guest";root.add_child(branch);set_multiplayer(SceneMultiplayer.new(),branch.get_path())
	var peer_root=Node.new();peer_root.name="Catan";branch.add_child(peer_root)
	client=CatanNetwork.new();client.name="Network";peer_root.add_child(client)
	client.notice.connect(func(message):notices.append(message))
	client.join_room(game.net.invite("127.0.0.1"),"Guest","wrong-password");await create_timer(1.5).timeout
	check(game.net.roster.size()==1 and client.seat==-1 and not client.online and not notices.is_empty(),"wrong password rejected")
	client.join_room(game.net.invite("127.0.0.1"),"Guest","test-host-password");await create_timer(1.5).timeout
	check(game.net.roster.size()==2 and client.seat==1,"matching password joins")
	client.leave();game.net.leave();await create_timer(.2).timeout
	game.host_password_field.text="";game.password_field.text="unused-join-password";game._host()
	check(game.net.room_password.is_empty() and "Open room" in game._node("RoomSummary").text,"blank host password creates open room")
	client.join_room(game.net.invite("127.0.0.1"),"Guest");await create_timer(1.5).timeout
	check(game.net.roster.size()==2,"open room permits password-free join")
	var saved_code=game.net.invite("127.0.0.1")
	client.leave();game.net.leave()
	game.net.reconnect_token="saved-test-seat";game.net.reconnect_address=saved_code;game.net.reconnect_password="remembered-in-memory"
	game._home()
	check(game._node("JoinOptions").visible and game._node("OnlineForm").visible,"returning client sees join password form")
	check(game.password_field.text=="remembered-in-memory" and game.address_field.text==saved_code,"reconnect form restores in-memory connection details")
	game.queue_free();await create_timer(.2).timeout;branch.queue_free();await process_frame;await process_frame
	print("HOST_PASSWORD_TEST: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
