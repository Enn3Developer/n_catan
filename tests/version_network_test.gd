extends SceneTree
var failures=0
var notices=[]
func check(ok,message):
	if not ok:failures+=1;printerr("FAIL: ",message)
func make_peer(label):
	var branch=Node.new();branch.name=label;root.add_child(branch)
	set_multiplayer(SceneMultiplayer.new(),branch.get_path())
	var net=CatanNetwork.new();net.name="Network";branch.add_child(net);return net
func _initialize():call_deferred("run")
func run():
	var host=make_peer("Host");var client=make_peer("Client")
	check(host.host("Host","")==OK,"host starts")
	client.notice.connect(func(message):notices.append(message))
	client.multiplayer.connected_to_server.disconnect(client._connected)
	var incompatible=func():client._register.rpc_id(1,"Guest","",CatanBuildInfo.PROTOCOL-1,"",0,"v0.1.0")
	client.multiplayer.connected_to_server.connect(incompatible)
	client.join_room(host.invite("127.0.0.1"),"Guest","")
	await create_timer(1).timeout
	check(host.roster.size()==1 and not client.online,"incompatible client rejected")
	check(not notices.is_empty() and "Incompatible multiplayer" in notices[0] and "v0.1.0" in notices[0],"version mismatch provides versions and update guidance")
	client.multiplayer.connected_to_server.disconnect(incompatible)
	client.multiplayer.connected_to_server.connect(client._connected)
	client.join_room(host.invite("127.0.0.1"),"Guest","")
	await create_timer(1).timeout
	check(host.roster.size()==2 and client.seat==1,"compatible client joins after rejection")
	client.leave();host.leave();print("VERSION_NETWORK_TEST: ",failures," failures");quit(1 if failures else 0)
