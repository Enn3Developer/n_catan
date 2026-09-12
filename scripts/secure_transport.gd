extends RefCounted
# The public UDP socket serves the certificate and forwards DTLS datagrams to
# Godot's ENet listener on loopback. Only the existing public port is required.
# This relay never encrypts/decrypts game traffic; Godot/mbedTLS owns every session.
signal connected(connection: ENetConnection)
signal failed(message: String)
const INVITE=preload("res://scripts/secure_invite.gd")
const CERT_NAME="n-catan-room"
const REQUEST="NCAT-CERT1?"
const RESPONSE="NCAT-CERT1!"
const DISCOVERY_SIZE=1400
const NONCE_SIZE=16
const MAX_ROUTES=24
var certificate: X509Certificate
var public_certificate=PackedByteArray()
var listener: UDPServer
var backend_port=0
var routes=[]
var discovery: PacketPeerUDP
var target={}
var nonce=PackedByteArray()
var pending: ENetConnection
var peer_id=0
var deadline=0
var next_request=0

static func _certificate_date(unix: int) -> String:
	var date=Time.get_datetime_dict_from_unix_time(unix)
	return "%04d%02d%02d%02d%02d%02d"%[date.year,date.month,date.day,date.hour,date.minute,date.second]

func start_host(peer: ENetMultiplayerPeer,port: int) -> Error:
	stop()
	var crypto=Crypto.new();var key=crypto.generate_rsa(2048)
	if key==null:return ERR_CANT_CREATE
	var now=int(Time.get_unix_time_from_system())
	certificate=crypto.generate_self_signed_certificate(key,"CN="+CERT_NAME+",O=N Catan",_certificate_date(now-3600),_certificate_date(now+30*86400))
	if certificate==null:return ERR_CANT_CREATE
	# Avoid the engine's trailing-NUL PEM string conversion. This temporary file
	# contains only the public certificate; the private key stays in memory.
	var path="user://.room-certificate-%s.crt"%get_instance_id()
	var err=certificate.save(path)
	if err==OK:
		public_certificate=FileAccess.get_file_as_bytes(path)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		while not public_certificate.is_empty() and public_certificate[-1]==0:public_certificate.resize(public_certificate.size()-1)
	if err!=OK or public_certificate.is_empty() or public_certificate.size()+RESPONSE.length()+NONCE_SIZE>DISCOVERY_SIZE:
		stop();return ERR_CANT_CREATE
	err=peer.get_host().dtls_server_setup(TLSOptions.server(key,certificate))
	if err!=OK:stop();return err
	backend_port=peer.get_host().get_local_port()
	listener=UDPServer.new();listener.max_pending_connections=MAX_ROUTES
	err=listener.listen(port)
	if err!=OK:stop()
	return err

func start_client(info: Dictionary,id: int) -> Error:
	stop();target=info.duplicate();peer_id=id
	nonce=Crypto.new().generate_random_bytes(NONCE_SIZE)
	discovery=PacketPeerUDP.new()
	var err=discovery.connect_to_host(target.host,target.port)
	if err!=OK:stop();return err
	deadline=Time.get_ticks_msec()+10000;next_request=0
	return OK

func _fail(message: String):
	stop();failed.emit(message)

func poll():
	if listener!=null:_poll_host()
	if discovery!=null:_poll_certificate()
	if pending!=null:
		var event=pending.service(0)
		if event[0]==ENetConnection.EVENT_CONNECT:
			var connection=pending;pending=null;connected.emit(connection)
		elif event[0] in [ENetConnection.EVENT_ERROR,ENetConnection.EVENT_DISCONNECT] or Time.get_ticks_msec()>deadline:
			_fail("Secure connection failed. Check the invite, host availability and UDP port.")

func _poll_certificate():
	var now=Time.get_ticks_msec()
	if now>deadline:
		_fail("Secure connection failed. Check the invite, host availability and UDP port.");return
	if now>=next_request:
		var request=REQUEST.to_ascii_buffer();request.append_array(nonce);request.resize(DISCOVERY_SIZE)
		discovery.put_packet(request);next_request=now+400
	for i in mini(4,discovery.get_available_packet_count()):
		var packet=discovery.get_packet();var header=RESPONSE.length()+NONCE_SIZE
		if packet.size()<=header or packet.size()>DISCOVERY_SIZE:continue
		if packet.slice(0,RESPONSE.length())!=RESPONSE.to_ascii_buffer() or packet.slice(RESPONSE.length(),header)!=nonce:continue
		var pem=packet.slice(header)
		if not Crypto.new().constant_time_compare(INVITE.fingerprint(pem),target.pin):
			_fail("This invite does not match the host. Ask for a new invite.");return
		var trusted=X509Certificate.new()
		if trusted.load_from_string(pem.get_string_from_ascii())!=OK:
			_fail("Secure connection failed. Check the invite, host availability and UDP port.");return
		discovery.close();discovery=null
		pending=ENetConnection.new()
		var err=pending.create_host(1,3)
		if err==OK:pending.compress(ENetConnection.COMPRESS_RANGE_CODER)
		# Trust only the certificate whose fingerprint came from the invite.
		if err==OK:err=pending.dtls_client_setup(CERT_NAME,TLSOptions.client(trusted,CERT_NAME))
		if err==OK and pending.connect_to_host(target.host,target.port,3,peer_id)==null:err=ERR_CANT_CONNECT
		if err!=OK:_fail("Secure connection failed. Check the invite, host availability and UDP port.")
		return

static func _dtls_packet(packet: PackedByteArray) -> bool:
	return packet.size()>=13 and packet[0] in [20,21,22,23] and packet[1]==254 and packet[2] in [253,255]

func _poll_host():
	var now=Time.get_ticks_msec()
	listener.poll()
	for i in MAX_ROUTES:
		if not listener.is_connection_available():break
		var external=listener.take_connection()
		if routes.size()>=MAX_ROUTES:external.close();continue
		routes.append({"external":external,"local":null,"seen":now,"request_after":0})
	for i in range(routes.size()-1,-1,-1):
		var route=routes[i]
		for j in mini(64,route.external.get_available_packet_count()):
			var packet: PackedByteArray=route.external.get_packet()
			if packet.size()==DISCOVERY_SIZE and packet.slice(0,REQUEST.length())==REQUEST.to_ascii_buffer():
				if now<route.request_after:continue
				route.request_after=now+300
				var response=RESPONSE.to_ascii_buffer()
				response.append_array(packet.slice(REQUEST.length(),REQUEST.length()+NONCE_SIZE))
				response.append_array(public_certificate)
				# Request padding prevents the public certificate endpoint amplifying UDP traffic.
				route.external.put_packet(response);route.seen=now
			elif _dtls_packet(packet):
				if route.local==null:
					# Allocate a relay only for a DTLS ClientHello, never plaintext ENet.
					if packet.size()<25 or packet[0]!=22 or packet[13]!=1:continue
					var tunnel=PacketPeerUDP.new()
					var err=tunnel.bind(0,"127.0.0.1")
					if err==OK:err=tunnel.connect_to_host("127.0.0.1",backend_port)
					if err!=OK:tunnel.close();continue
					route.local=tunnel
				route.local.put_packet(packet);route.seen=now
		if route.local!=null:
			for j in mini(64,route.local.get_available_packet_count()):
				route.external.put_packet(route.local.get_packet());route.seen=now
		var lifetime=30000 if route.local!=null else 2000
		if now-route.seen>lifetime:
			route.external.close()
			if route.local!=null:route.local.close()
			routes.remove_at(i)

func stop():
	if discovery!=null:discovery.close();discovery=null
	if pending!=null:pending.destroy();pending=null
	for route in routes:
		route.external.close()
		if route.local!=null:route.local.close()
	routes.clear()
	if listener!=null:listener.stop();listener=null
	certificate=null;public_certificate.clear();target.clear();nonce.clear();peer_id=0;backend_port=0
