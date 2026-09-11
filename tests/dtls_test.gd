extends SceneTree
var failures=0
var host
var client
func check(ok,message):
	if not ok:failures+=1;printerr("FAIL: ",message)
func make_peer(label):
	var branch=Node.new();branch.name=label;root.add_child(branch)
	set_multiplayer(SceneMultiplayer.new(),branch.get_path())
	var net=CatanNetwork.new();net.name="Network";branch.add_child(net);return net
func _initialize():call_deferred("run")
func run():
	host=make_peer("Host");client=make_peer("Client")
	check(host.host("Host","secret")==OK,"DTLS server starts")
	var invite=host.secure_invite("127.0.0.1")
	check(not "PRIVATE KEY" in Marshalls.base64_to_raw(invite.get_slice("#",1)).get_string_from_utf8(),"invite only contains public certificate")
	check(client.join_room("127.0.0.1","Guest","secret")==ERR_INVALID_PARAMETER,"bare address rejected")
	var other=Crypto.new()
	var cert=other.generate_self_signed_certificate(other.generate_rsa(2048),"CN=n-catan-room","20240101000000","20400101000000")
	var bad_invite="n-catan://127.0.0.1#"+Marshalls.raw_to_base64(cert.save_to_string().to_utf8_buffer())
	client.join_room(bad_invite,"Guest","secret")
	await create_timer(1).timeout
	check(host.roster.size()==1 and client.seat==-1,"untrusted host certificate rejected")
	client.connection_deadline=0
	await process_frame;await process_frame
	check(not client.online,"failed handshake leaves connection screen")
	var plain=ENetMultiplayerPeer.new();plain.create_client("127.0.0.1",24567)
	for i in 30:
		plain.poll();await create_timer(.02).timeout
	check(plain.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED and host.roster.size()==1,"server rejects plaintext ENet")
	plain.close()
	client.join_room(invite,"Guest","secret")
	await create_timer(.6).timeout
	check(client.seat==1 and host.roster.size()==2,"verified DTLS joins after rejection")
	host.leave();await create_timer(.3).timeout
	check(not client.online,"host disconnect leaves client cleanly")
	client.leave()
	print("DTLS_TEST: certificate pinning, plaintext rejection, recovery and disconnect; ",failures," failures")
	quit(1 if failures else 0)
