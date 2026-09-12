class_name CatanNetwork
extends Node

signal changed
signal received(state: Dictionary)
signal notice(message: String)
signal applied(player: int, action: Dictionary)
const PORT=24567
const SECURE_INVITE=preload("res://scripts/secure_invite.gd")
var secure_transport=preload("res://scripts/secure_transport.gd").new()
const PROTOCOL=CatanBuildInfo.PROTOCOL
const MIN_PLAYERS=3
const MAX_PLAYERS=6
var rules=CatanRules.new()
var roster: Array=[]
var seat=-1
var started=false
var dedicated=false
var online=false
var my_name="Voyager"
var my_style=0
var my_color=""
var room_password=""
func invite(address: String) -> String:
	if secure_transport.certificate==null:return reconnect_address if online and not solo else ""
	return SECURE_INVITE.encode(address,SECURE_INVITE.fingerprint(secure_transport.public_certificate))

var last_action={}
var upnp_thread: Thread
var mapper: UPNP
var reconnect_token=""
var reconnect_address=""
var reconnect_name=""
var reconnect_password=""
var seat_tokens={}
var solo=false
var tutorial=false
var tutorial_expected=""
var paused=false
var bot_delay=0.7
var bot_clock=0.0
var bot_brains={}
var bot_action_count=0
var bot_turn=-1
var world_seconds=150.0
var music_track=0
var music_paused=false
var music_position=0.0
var music_anchor_ms=0
var music_revision=0
var music_context={}
var music_remote={}
var music_received_ms=0
var music_one_way=0.0
var music_ping_clock=0.0
var music_ping_sent=-1
var music_last_command=-1000


func _ready():
	multiplayer.server_relay=false
	secure_transport.connected.connect(_secure_connected)
	secure_transport.failed.connect(_connection_ended,CONNECT_DEFERRED)
	_reset_music()
	_load_session()
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_connection_ended.bind("Connection failed. Check the address, UDP port and firewall."),CONNECT_DEFERRED)
	multiplayer.server_disconnected.connect(_connection_ended.bind("Connection lost. Use Reconnect to return to your seat if the server is still running."),CONNECT_DEFERRED)
	multiplayer.peer_disconnected.connect(_disconnected)

func _connection_ended(message: String):
	leave()
	notice.emit(message)

func host(pname: String,password: String="",server_only: bool=false) -> Error:
	CatanDiagnostics.event("network.host","dedicated=%s"%server_only)
	leave()
	var peer=ENetMultiplayerPeer.new()
	peer.set_bind_ip("127.0.0.1")
	var err=peer.create_server(0,8)
	if err==OK:err=secure_transport.start_host(peer,PORT)
	if err!=OK:
		peer.close();secure_transport.stop();return err
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer=peer
	online=true
	dedicated=server_only
	my_name=pname
	room_password=password
	seat_tokens={}
	reconnect_token=""
	if not dedicated:
		roster=[{"id":1,"name":pname,"ready":false,"connected":true,"bot":false,"piece_style":my_style,"color":my_color}]
		seat=0
	changed.emit()
	return OK

func join_room(address: String,pname: String,password: String="") -> Error:
	CatanDiagnostics.event("network.join")
	address=address.strip_edges()
	var endpoint=SECURE_INVITE.decode(address)
	if endpoint.is_empty():
		notice.emit("Paste a valid invite code from the host.")
		return ERR_INVALID_PARAMETER
	leave()
	my_name=pname
	room_password=password
	if address!=reconnect_address or pname!=reconnect_name:reconnect_token=""
	reconnect_address=address
	reconnect_name=pname
	reconnect_password=password
	var peer=ENetMultiplayerPeer.new()
	var id=peer.generate_unique_id()
	var err=peer.create_mesh(id)
	if err==OK:err=secure_transport.start_client(endpoint,id)
	if err!=OK:
		peer.close();secure_transport.stop();return err
	multiplayer.multiplayer_peer=peer
	online=true
	changed.emit()
	return OK

func _secure_connected(connection: ENetConnection):
	var err=multiplayer.multiplayer_peer.add_mesh_peer(1,connection)
	if err!=OK:
		connection.destroy()
		_connection_ended.call_deferred("Secure connection failed. Check the invite, host availability and UDP port.")

func leave():
	CatanDiagnostics.event("network.leave","online=%s started=%s"%[online,started])
	var continuing_music=music_state() if multiplayer.multiplayer_peer.get_connection_status()!=MultiplayerPeer.CONNECTION_DISCONNECTED else {}
	if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
	if secure_transport.listener!=null:secure_transport.poll()
	secure_transport.stop()
	online=false
	solo=false
	tutorial=false
	paused=false
	bot_brains={}
	bot_action_count=0
	bot_turn=-1
	started=false
	roster=[]
	seat=-1
	last_action={}
	_reset_music()
	if continuing_music.get("ready",false):
		music_track=continuing_music.track
		music_position=continuing_music.position
		music_paused=continuing_music.paused
		music_context=continuing_music.duplicate(true)
	changed.emit()

func _connected():
	CatanDiagnostics.event("network.connected")
	_register.rpc_id(1,my_name,room_password,PROTOCOL,reconnect_token,my_style,CatanBuildInfo.VERSION,my_color)

@rpc("any_peer","call_remote","reliable")
func _register(pname: String,password: String,version: int,token: String="",piece_style: int=0,client_version: String="unknown",requested_color: String=""):
	if not online or not multiplayer.is_server(): return
	var id=multiplayer.get_remote_sender_id()
	if version!=PROTOCOL:
		_registration_failed.rpc_id(id,CatanI18n.message("Incompatible multiplayer versions. Host: %s (protocol %d). Yours: %s (protocol %d). Check for updates from the main menu.",[CatanBuildInfo.VERSION,PROTOCOL,client_version.substr(0,40),version]))
		return
	if started and version==PROTOCOL and password==room_password and not token.is_empty():
		for p in roster.size():
			if seat_tokens.get(p,"")==token:
				# The bearer token owns this seat, even before ENet times out the old peer.
				var old_id=int(roster[p].id)
				roster[p].id=id
				roster[p].connected=true
				if old_id!=id and old_id in multiplayer.get_peers():multiplayer.multiplayer_peer.disconnect_peer(old_id)
				_session.rpc_id(id,token)
				rules._log(CatanI18n.message("%s reconnected. The expedition continues.",[roster[p].name]))
				_broadcast_lobby()
				_sync()
				return
	if version!=PROTOCOL or password!=room_password or started or roster.size()>=MAX_PLAYERS or _seat_for(id)!=-1:
		_registration_failed.rpc_id(id,"The password is incorrect." if password!=room_password else "This game has started. Use Reconnect to return to your saved seat." if started else "This room is full. Ask the host to free a seat." if roster.size()>=MAX_PLAYERS else "You already have a seat in this room.")
		return
	pname=pname.strip_edges().replace("\n"," ").substr(0,20)
	if pname.is_empty(): pname="Voyager"
	roster.append({"id":id,"name":pname,"ready":false,"connected":true,"bot":false,"piece_style":piece_style if CatanCosmetics.valid_set(piece_style) else 0,"color":requested_color if valid_color(requested_color) else ""})
	var session_token=Crypto.new().generate_random_bytes(24).hex_encode()
	seat_tokens[roster.size()-1]=session_token
	_session.rpc_id(id,session_token)
	_broadcast_lobby()

@rpc("authority","call_remote","reliable")
func _session(token: String):
	reconnect_token=token
	var file=ConfigFile.new()
	file.set_value("session","token",token)
	file.set_value("session","address",reconnect_address)
	file.set_value("session","name",reconnect_name)
	file.save("user://reconnect.cfg")

func _load_session():
	var file=ConfigFile.new()
	if file.load("user://reconnect.cfg")!=OK:return
	reconnect_token=str(file.get_value("session","token",""))
	reconnect_address=str(file.get_value("session","address",""))
	reconnect_name=str(file.get_value("session","name","Voyager"))

@rpc("authority","call_remote","reliable")
func _registration_failed(message: String):
	CatanDiagnostics.event("network.registration_failed")
	_connection_ended.call_deferred(message)

func reconnect():
	if not reconnect_address.is_empty():
		var err=join_room(reconnect_address,reconnect_name,reconnect_password)
		if err!=OK:notice.emit("Could not reconnect. Ask the host for a new invite code.")

func _seat_for(id: int) -> int:
	for i in roster.size():
		if int(roster[i].id)==id: return i
	return -1

func _broadcast_lobby():
	for row in roster:
		if row.id>1 and row.connected: _lobby.rpc_id(row.id,roster,started,dedicated)
	changed.emit()

@rpc("authority","call_remote","reliable")
func _lobby(players: Array,in_game: bool,server_dedicated: bool=false):
	dedicated=server_dedicated
	roster=players
	seat=_seat_for(multiplayer.get_unique_id())
	started=in_game
	music_ping_clock=0.0
	changed.emit()

func ready_up():
	if multiplayer.is_server(): _set_ready(1)
	else: _ready_request.rpc_id(1)

@rpc("any_peer","call_remote","reliable")
func _ready_request():
	if multiplayer.is_server(): _set_ready(multiplayer.get_remote_sender_id())

func _set_ready(id: int):
	var p=_seat_for(id)
	if started or p<0: return
	roster[p].ready=not roster[p].ready
	_broadcast_lobby()

func start_game():
	if multiplayer.is_server(): _start(1)
	else: _start_request.rpc_id(1)

@rpc("any_peer","call_remote","reliable")
func _start_request():
	if multiplayer.is_server(): _start(multiplayer.get_remote_sender_id())

func _start(id: int):
	if started or roster.size()<MIN_PLAYERS or roster.size()>MAX_PLAYERS: return
	if id!=1 and (not dedicated or _seat_for(id)!=0): return
	for row in roster:
		if not row.ready: return
	var names=[]
	for row in roster: names.append(row.name)
	rules.create(names)
	world_seconds=150.0
	started=true
	_broadcast_lobby()
	_sync()

func act(action: Dictionary):
	if not started or seat<0: return
	if tutorial and not tutorial_expected.is_empty() and str(action.get("type",""))!=tutorial_expected:
		notice.emit("Follow the current tutorial step, or choose Skip lesson.")
		return
	if multiplayer.is_server(): _apply(1,action)
	else: _action.rpc_id(1,action)

@rpc("any_peer","call_remote","reliable")
func _action(action: Dictionary):
	if multiplayer.is_server(): _apply(multiplayer.get_remote_sender_id(),action)

func _apply(id: int,action: Dictionary):
	if not started or var_to_bytes(action).size()>2048: return
	var p=_seat_for(id)
	if p<0: return
	var now=Time.get_ticks_msec()
	if now-int(last_action.get(id,0))<80: return
	last_action[id]=now
	for row in roster:
		if not row.connected:
			_send_error(id,"Game paused while a disconnected player reconnects.")
			return
	CatanDiagnostics.event("action.begin","seat=%d type=%s turn=%s phase=%s"%[p,str(action.get("type","")).substr(0,40),rules.s.get("turn",-1),rules.s.get("phase","")])
	var error=rules.apply(p,action)
	CatanDiagnostics.event("action.complete","accepted=%s"%error.is_empty())
	if not error.is_empty(): _send_error(id,error)
	else:
		applied.emit(p,action)
		_sync()

func _sync():
	for p in roster.size():
		if not roster[p].connected or roster[p].get("bot",false): continue
		var state=rules.snapshot(p)
		state["world_seconds"]=world_seconds
		state["player_colors"]=[]
		for row in roster:state.player_colors.append(str(row.get("color","")))
		state["piece_styles"]=[]
		for row in roster:state.piece_styles.append(int(row.get("piece_style",0)))
		if roster[p].id==1: received.emit(state)
		else: _state.rpc_id(roster[p].id,state)

@rpc("authority","call_remote","reliable")
func _state(state: Dictionary):
	started=true
	received.emit(state)

func _send_error(id: int,message: String):
	if id==1: notice.emit(message)
	else: _error.rpc_id(id,message)

@rpc("authority","call_remote","reliable")
func _error(message: String):
	notice.emit(message)

func _disconnected(id: int):
	CatanDiagnostics.event("network.disconnected","seat=%d"%_seat_for(id))
	if id==1 and online and not multiplayer.is_server():
		# Mesh clients report the host leaving as peer_disconnected.
		_connection_ended.call_deferred("Connection lost. Use Reconnect to return to your seat if the server is still running.")
		return
	if not multiplayer.is_server(): return
	var p=_seat_for(id)
	if p<0: return
	if started:
		roster[p].connected=false
		rules._log(CatanI18n.message("%s disconnected. The game is paused.",[roster[p].name]))
		_sync()
	else:
		roster.remove_at(p)
		var remapped={}
		for key in seat_tokens:
			if key<p: remapped[key]=seat_tokens[key]
			elif key>p: remapped[key-1]=seat_tokens[key]
		seat_tokens=remapped
	_broadcast_lobby()

func map_router():
	if upnp_thread and upnp_thread.is_alive(): return
	if upnp_thread: upnp_thread.wait_to_finish()
	upnp_thread=Thread.new()
	upnp_thread.start(_map_worker)

func _map_worker():
	mapper=UPNP.new()
	var err=mapper.discover(2000,2,"InternetGatewayDevice")
	var message="Automatic mapping unavailable. Forward UDP 24567 to this computer, or use a public dedicated server."
	if err==UPNP.UPNP_RESULT_SUCCESS and mapper.get_gateway() and mapper.get_gateway().is_valid_gateway():
		if mapper.add_port_mapping(PORT,PORT,"Catan online","UDP",3600)==UPNP.UPNP_RESULT_SUCCESS:
			message="Router mapped for 1 hour. Invite address: %s:%d" % [mapper.query_external_address(),PORT]
	call_deferred("_mapping_done",message)

func _mapping_done(message: String):
	notice.emit(message)

func _exit_tree():
	if multiplayer.multiplayer_peer:multiplayer.multiplayer_peer.close()
	secure_transport.stop()
	if upnp_thread: upnp_thread.wait_to_finish()

func host_solo(pname: String):
	leave()
	online=true
	solo=true
	dedicated=false
	seat=0
	roster=[{"id":1,"name":pname,"ready":true,"connected":true,"bot":false,"piece_style":my_style,"color":my_color}]
	changed.emit()

func is_controller() -> bool:
	return multiplayer.is_server() or (dedicated and seat==0)

func configure_bot(operation: String,index: int=-1,difficulty: int=1):
	if multiplayer.is_server(): _edit_bot(1,operation,index,difficulty)
	else: _bot_request.rpc_id(1,operation,index,difficulty)

@rpc("any_peer","call_remote","reliable")
func _bot_request(operation: String,index: int,difficulty: int):
	if multiplayer.is_server(): _edit_bot(multiplayer.get_remote_sender_id(),operation,index,difficulty)

func _edit_bot(sender: int,operation: String,index: int,difficulty: int):
	if started or difficulty<0 or difficulty>2: return
	if sender!=1 and (not dedicated or _seat_for(sender)!=0): return
	if operation=="add" and roster.size()<MAX_PLAYERS:
		var id=-1
		while _seat_for(id)>=0: id-=1
		var bot_name=["Juniper","Flint","Coral","Atlas","Willow","Slate"][(-id-1)%6]
		roster.append({"id":id,"name":bot_name,"ready":true,"connected":true,"bot":true,"difficulty":difficulty,"piece_style":(-id)%CatanCosmetics.SETS.size()})
	elif index>=0 and index<roster.size() and roster[index].get("bot",false):
		if operation=="difficulty": roster[index].difficulty=difficulty
		elif operation=="remove":
			roster.remove_at(index)
			var remapped={}
			for key in seat_tokens:
				if key<index: remapped[key]=seat_tokens[key]
				elif key>index: remapped[key-1]=seat_tokens[key]
			seat_tokens=remapped
	_broadcast_lobby()

func choose_piece_style(style: int,target: int=-1):
	if not CatanCosmetics.valid_set(style):return
	if target<0:target=seat
	if not online or target<0:
		my_style=style
		return
	if multiplayer.is_server():_set_piece_style(1,target,style)
	else:_piece_style_request.rpc_id(1,target,style)

@rpc("any_peer","call_remote","reliable")
func _piece_style_request(target: int,style: int):
	if online and multiplayer.is_server():_set_piece_style(multiplayer.get_remote_sender_id(),target,style)

func _set_piece_style(sender: int,target: int,style: int):
	if target<0 or target>=roster.size() or not CatanCosmetics.valid_set(style):return
	var own=_seat_for(sender)
	var controller=sender==1 or (dedicated and own==0)
	if target!=own and not (controller and roster[target].get("bot",false)):return
	roster[target].piece_style=style
	if target==seat:my_style=style
	_broadcast_lobby()
	if started:_sync()

func _process(delta: float):
	secure_transport.poll()
	_process_music(delta)
	if online and started and multiplayer.is_server() and not paused and roster.all(func(row):return row.connected):
		world_seconds=fposmod(world_seconds+delta,600.0)
	if not online or not started or not multiplayer.is_server() or tutorial or paused or rules.s.is_empty() or rules.s.winner!=-1: return
	for row in roster:
		if not row.connected: return
	bot_clock-=delta
	if bot_clock>0: return
	bot_clock=bot_delay
	if bot_turn!=rules.s.turn:
		bot_turn=rules.s.turn
		bot_action_count=0
	for p in roster.size():
		if not roster[p].get("bot",false): continue
		if not bot_brains.has(p): bot_brains[p]=CatanBot.new()
		var action=bot_brains[p].choose(rules.snapshot(p),p,int(roster[p].difficulty))
		if action.is_empty(): continue
		if p==rules.s.turn:
			bot_action_count+=1
			if bot_action_count>30 and rules.s.phase=="play" and rules.s.rolled: action={"type":"end"}
		_apply(roster[p].id,action)
		return


func _reset_music():
	music_track=0;music_position=0.0;music_paused=false;music_revision=0;music_context={}
	music_anchor_ms=Time.get_ticks_msec();music_remote={};music_one_way=0.0
	music_ping_clock=0.0;music_ping_sent=-1;music_last_command=-1000

func can_control_music() -> bool:
	return not online or solo or (seat>=0 and is_controller())

func music_state() -> Dictionary:
	if not online or multiplayer.is_server():
		return _music_snapshot()
	if music_remote.is_empty():return {"track":0,"position":0.0,"paused":true,"ready":false,"revision":-1}
	return CatanSoundtrack.advance(music_remote,float(Time.get_ticks_msec()-music_received_ms)/1000.0)

func _music_snapshot() -> Dictionary:
	var now=Time.get_ticks_msec()
	var sample=music_context.duplicate(true)
	sample.merge({"track":music_track,"position":music_position,"paused":music_paused,"revision":music_revision,"server_ms":now,"ready":true},true)
	var current=CatanSoundtrack.advance(sample,float(now-music_anchor_ms)/1000.0)
	# Rebase at automatic boundaries so long sessions do not replay hours of
	# transition planning on every rendered frame.
	if current.get("generation",0)!=sample.get("generation",0):
		music_context=current.duplicate(true)
		music_track=current.track;music_position=current.position;music_paused=current.paused;music_anchor_ms=now
	return current

func music_control(operation: String,track: int=-1):
	if not can_control_music():
		notice.emit("The room host controls the shared soundtrack. Your volume is personal.")
		return
	if not online or multiplayer.is_server():_set_music(1,operation,track)
	else:_music_command.rpc_id(1,operation,track)

@rpc("any_peer","call_remote","reliable")
func _music_command(operation: String,track: int=-1):
	if online and multiplayer.is_server():_set_music(multiplayer.get_remote_sender_id(),operation,track)

func _set_music(sender: int,operation: String,track: int):
	if sender!=1 and (not dedicated or _seat_for(sender)!=0):return
	if operation not in ["toggle","previous","next","select"]:return
	if operation=="select" and (track<0 or track>=CatanSoundtrack.TRACKS.size()):return
	var now=Time.get_ticks_msec()
	if now-music_last_command<100:return
	music_last_command=now
	var current=music_state()
	match operation:
		"toggle":current.paused=not current.paused
		"next":current=CatanSoundtrack.switch_to(current,(int(current.track)+1)%CatanSoundtrack.TRACKS.size())
		"previous":
			var target=posmod(int(current.track)-1,CatanSoundtrack.TRACKS.size()) if current.position<3 else int(current.track)
			current=CatanSoundtrack.switch_to(current,target,true,true)
		"select":
			current=CatanSoundtrack.switch_to(current,track)
			current.paused=false
	music_context=current.duplicate(true)
	music_track=current.track;music_position=current.position;music_paused=current.paused;music_anchor_ms=now
	music_revision+=1
	_broadcast_music()

func _broadcast_music():
	var sample=_music_snapshot()
	for row in roster:
		if row.id>1 and row.connected:_music_update.rpc_id(row.id,sample)

func _process_music(delta: float):
	if not online or multiplayer.is_server():return
	if seat<0 or multiplayer.multiplayer_peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED:return
	music_ping_clock-=delta
	if music_ping_clock>0:return
	music_ping_clock=2.0
	music_ping_sent=Time.get_ticks_msec()
	_music_ping.rpc_id(1,music_ping_sent)

@rpc("any_peer","call_remote","reliable")
func _music_ping(sent_ms: int):
	if not online or not multiplayer.is_server():return
	var sender=multiplayer.get_remote_sender_id()
	if _seat_for(sender)<0:return
	_music_pong.rpc_id(sender,sent_ms,_music_snapshot())

@rpc("authority","call_remote","reliable")
func _music_pong(sent_ms: int,sample: Dictionary):
	if sent_ms!=music_ping_sent or sent_ms<0:return
	var rtt=float(Time.get_ticks_msec()-sent_ms)/1000.0
	music_ping_sent=-1
	if rtt<0 or rtt>2.0:return
	music_one_way=rtt*.5
	_accept_music(sample,music_one_way)

@rpc("authority","call_remote","reliable")
func _music_update(sample: Dictionary):
	_accept_music(sample,music_one_way)

func _accept_music(sample: Dictionary,latency: float):
	if not online or multiplayer.is_server():return
	if not music_remote.is_empty():
		if sample.revision<music_remote.revision:return
		if sample.revision==music_remote.revision and sample.server_ms<music_remote.server_ms:return
	music_remote=CatanSoundtrack.advance(sample,latency)
	music_received_ms=Time.get_ticks_msec()

static func valid_color(value: String) -> bool:
	return value.is_empty() or (value.length()==6 and Color.html_is_valid(value))

func player_color(player: int) -> Color:
	var value=str(roster[player].get("color","")) if player>=0 and player<roster.size() else my_color
	return Color(value) if not value.is_empty() and valid_color(value) else CatanBoard.PLAYERS[clampi(player,0,5)]

func choose_color(value: String,target: int=-1):
	if not valid_color(value):return
	if target<0:target=seat
	if not online or target<0:
		my_color=value
		return
	if multiplayer.is_server():_set_color(1,target,value)
	else:_color_request.rpc_id(1,target,value)

@rpc("any_peer","call_remote","reliable")
func _color_request(target: int,value: String):
	if online and multiplayer.is_server():_set_color(multiplayer.get_remote_sender_id(),target,value)

func _set_color(sender: int,target: int,value: String):
	if target<0 or target>=roster.size() or not valid_color(value):return
	var own=_seat_for(sender)
	var controller=sender==1 or (dedicated and own==0)
	if target!=own and not (controller and roster[target].get("bot",false)):return
	roster[target]["color"]=value.to_lower()
	if target==seat:my_color=value.to_lower()
	_broadcast_lobby()
	if started:_sync()
