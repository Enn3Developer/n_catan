extends SceneTree
var failures=0
func check(ok,message):
	if not ok:failures+=1;printerr("FAIL: ",message)
func make_peer(label):
	var branch=Node.new();branch.name=label;root.add_child(branch)
	set_multiplayer(SceneMultiplayer.new(),branch.get_path())
	var net=CatanNetwork.new();net.name="Network";branch.add_child(net);return net
func _initialize():call_deferred("run")
func run():
	var host=make_peer("Host");var client=make_peer("Client")
	check(host.host("Host","secret")==OK,"plain ENet server starts")
	check(host.invite("127.0.0.1:24567")=="127.0.0.1:24567","invite contains only endpoint")
	for address in ["",":24567","127.0.0.1:0","127.0.0.1:65536","127.0.0.1:bad","n-catan://127.0.0.1#old-cert"]:
		check(client.join_room(address,"Guest","secret")==ERR_INVALID_PARAMETER,"invalid or old certificate invite rejected")
	client.join_room("127.0.0.1:24567","Guest","wrong")
	await create_timer(.5).timeout
	check(host.roster.size()==1 and not client.online,"wrong password rejected")
	check(client.join_room("127.0.0.1","Guest","secret")==OK,"bare address accepted")
	await create_timer(.5).timeout
	check(client.seat==1 and host.roster.size()==2,"plain client joins after rejection")
	client.leave();host.leave();host.host("Host")
	client.join_room("127.0.0.1:24567","Guest")
	await create_timer(.5).timeout
	check(client.seat==1,"password-free room joins")
	host.leave();await create_timer(.3).timeout
	check(not client.online,"host disconnect leaves client cleanly")
	client.leave()
	print("ENET_TRANSPORT_TEST: ",failures," failures")
	quit(1 if failures else 0)
