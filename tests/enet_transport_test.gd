extends SceneTree
const INVITE=preload("res://scripts/secure_invite.gd")
const TRANSPORT=preload("res://scripts/secure_transport.gd")
var failures=0
var messages=[]

# An untrusted forwarding hop captures the actual public wire traffic. It can
# also substitute discovery bytes without changing the trusted invite.
class WireProxy extends Node:
	var server=UDPServer.new()
	var routes=[]
	var packets=[]
	var replacement=PackedByteArray()
	var destination=24567
	func _process(_delta):
		server.poll()
		while server.is_connection_available():
			var tunnel=PacketPeerUDP.new();tunnel.connect_to_host("127.0.0.1",destination)
			routes.append([server.take_connection(),tunnel])
		for route in routes:
			while route[0].get_available_packet_count():
				var packet=route[0].get_packet();packets.append(packet);route[1].put_packet(packet)
			while route[1].get_available_packet_count():
				var packet: PackedByteArray=route[1].get_packet()
				if not replacement.is_empty() and packet.slice(0,TRANSPORT.RESPONSE.length())==TRANSPORT.RESPONSE.to_ascii_buffer():
					packet.resize(TRANSPORT.RESPONSE.length()+TRANSPORT.NONCE_SIZE);packet.append_array(replacement)
				packets.append(packet);route[0].put_packet(packet)
	func _exit_tree():
		for route in routes:route[0].close();route[1].close()
		server.stop()

func check(ok,message):
	if not ok:failures+=1;printerr("FAIL: ",message)
func make_peer(label):
	var branch=Node.new();branch.name=label;root.add_child(branch)
	set_multiplayer(SceneMultiplayer.new(),branch.get_path())
	var node=CatanNetwork.new();node.name="Network";branch.add_child(node)
	node.notice.connect(func(message):messages.append(message))
	return node
func wait_for(predicate: Callable,seconds=3.0):
	var end=Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec()<end:await process_frame
func _initialize():call_deferred("run")
func run():
	var pin=INVITE.fingerprint("codec fixture".to_utf8_buffer())
	for address in ["127.0.0.1","192.0.2.1:1","203.0.113.255:65535","room.example.org","room.example.org:25000"]:
		var code=INVITE.encode(address,pin);var decoded=INVITE.decode(code)
		check(not decoded.is_empty() and decoded.pin==pin and decoded.host==address.split(":")[0],"endpoint and fingerprint round trip")
		check(INVITE.decode(code+"=").is_empty(),"noncanonical base64 rejected")
		for offset in range(4,code.length()):
			var modified=code;modified[offset]="A" if code[offset]!="A" else "B"
			check(INVITE.decode(modified).is_empty(),"single-character invite typo rejected")
	check(INVITE.encode("127.0.0.1",pin).length()==35,"default IPv4 invite is 35 characters")
	check(INVITE.encode("127.0.0.1:25000",pin).length()==38,"custom port invite is 38 characters")
	for address in ["",":24567","127.0.0.1:0","127.0.0.1:65536","127.0.0.1:bad","999.0.0.1","bad..host","-host","host/path"]:
		check(INVITE.encode(address,pin).is_empty(),"invalid host address rejected")
	var host=make_peer("Host");var client=make_peer("Guest")
	check(host.host("Host","wire-password-marker")==OK,"encrypted server starts")
	var code=host.invite("127.0.0.1")
	check(code.length()==35,"host generates compact invite")
	for invalid in ["","127.0.0.1","127.0.0.1:24567","n-catan://127.0.0.1#old-cert",code+"junk"]:
		check(client.join_room(invalid,"Guest")==ERR_INVALID_PARAMETER,"bare addresses and old or malformed invites rejected")
	var proxy=WireProxy.new();root.add_child(proxy)
	check(proxy.server.listen(24568,"127.0.0.1")==OK,"wire proxy starts")
	var proxy_code=host.invite("127.0.0.1:24568")
	# Substituting the public certificate must fail before any DTLS or registration.
	proxy.replacement="substituted certificate".to_utf8_buffer()
	client.join_room(proxy_code,"Guest","wire-password-marker")
	await wait_for(func():return not client.online)
	check(not client.online and host.roster.size()==1,"substituted discovery certificate rejected before admission")
	check(messages.has("This invite does not match the host. Ask for a new invite."),"certificate mismatch explained: "+str(messages))
	check(proxy.packets.all(func(packet):return not TRANSPORT._dtls_packet(packet)),"no handshake or credentials before fingerprint verification")
	proxy.replacement.clear();proxy.packets.clear()
	var wrong_pin=INVITE.decode(code);wrong_pin.pin[0]^=1
	client.join_room(INVITE.encode("127.0.0.1",wrong_pin.pin),"Guest","wire-password-marker")
	await wait_for(func():return not client.online)
	check(not client.online and host.roster.size()==1,"wrong fingerprint rejected")
	# Ordinary unencrypted ENet must never reach registration on the public port.
	var plain=ENetMultiplayerPeer.new();plain.create_client("127.0.0.1",24567)
	for i in 12:plain.poll();await create_timer(.02).timeout
	check(plain.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED and host.roster.size()==1,"plaintext ENet rejected")
	plain.close()
	client.join_room(proxy_code,"Guest","wrong")
	await wait_for(func():return not client.online)
	check(not client.online and host.roster.size()==1 and messages.has("The password is incorrect."),"wrong room password rejected over DTLS")
	check(client.join_room(proxy_code,"wire-player-marker","wire-password-marker")==OK,"compact invite connects")
	await wait_for(func():return client.seat==1)
	check(client.seat==1 and host.roster.size()==2 and not client.reconnect_token.is_empty(),"verified encrypted client registered")
	check(client.invite("ignored")==proxy_code,"guest can copy the same invite")
	check(proxy.packets.any(func(packet):return TRANSPORT._dtls_packet(packet) and packet[0]==23),"application traffic uses DTLS records on the wire")
	for packet in proxy.packets:
		var hex=packet.hex_encode()
		for secret in ["wire-password-marker","wire-player-marker",client.reconnect_token]:
			if not secret.is_empty():check(not hex.contains(secret.to_utf8_buffer().hex_encode()),"credentials absent from public wire packets")
	client.leave()
	await wait_for(func():return host.roster.size()==1)
	check(host.roster.size()==1,"client leave reaches host")
	var old_certificate=host.secure_transport.public_certificate.duplicate()
	host.leave();await process_frame
	check(host.host("Host")==OK,"room restarts")
	check(host.invite("127.0.0.1")!=code,"new room rotates certificate")
	# Copying the real public certificate cannot impersonate its private key.
	proxy.replacement=old_certificate;messages.clear()
	print("Expect certificate verification errors during the impersonation check.")
	client.join_room(proxy_code,"Guest","wire-password-marker")
	client.secure_transport.deadline=Time.get_ticks_msec()+2000
	await wait_for(func():return not client.online)
	check(not client.online and host.roster.size()==1,"copied certificate without matching private key cannot register")
	check(not messages.has("This invite does not match the host. Ask for a new invite."),"impersonation rejected by DTLS after matching the discovery fingerprint")
	proxy.replacement.clear()
	client.join_room(host.invite("127.0.0.1"),"Guest")
	await wait_for(func():return client.seat==1)
	check(client.seat==1,"password-free room still uses authenticated DTLS")
	host.leave()
	await wait_for(func():return not client.online)
	check(not client.online,"host disconnect leaves client cleanly")
	client.leave();proxy.queue_free();await process_frame
	print("ENET_TRANSPORT_TEST: ",failures," failures")
	quit(1 if failures else 0)
