class_name CatanNetwork
extends Node

signal changed
signal received(state: Dictionary)
signal notice(message: String)
## A refused action or a failed connection: shown like a notice, with the error sound.
signal rejected(message: String)
signal applied(player: int, action: Dictionary)
signal log_received(entries: Array)
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
var my_look: PackedByteArray=CatanAppearance.default_bytes()
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
const TURN_SECONDS=60.0
## Seconds other players have to answer a trade offer before the offerer picks.
const TRADE_WINDOW=4.0
## Seconds a disconnected player has to come back before a bot plays their seat.
const STAND_IN_SECONDS=60.0
## Actions a player may send in a burst, and how many a second refill it.
const ACTION_BURST=8.0
const ACTION_RATE=10.0
const DEFAULT_SETTINGS={"seed":0,"island":"random","turn_seconds":int(TURN_SECONDS),"points":10,"friendly_robber":false,"random_start":false,"start_card":false,"treasure":false,"move_ships":false,"fog":false}
## House rules and the map seed, chosen in the lobby by the room controller.
var room_settings=DEFAULT_SETTINGS.duplicate()
var turn_seconds=TURN_SECONDS
var offer_clock=0.0
var game_count=0
var turn_clock=TURN_SECONDS
var turn_mark=[]
var turn_expired=false
var world_seconds=150.0
var world_days=0
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
## Save and resume: the host keeps one saved game for solo play and one for
## online rooms, rewritten about once a second while a game runs.
const SAVE_DIR="user://saves"
const SAVE_FORMAT=1
## The save being resumed while the lobby waits for its players, or empty.
var resuming={}
var save_dirty=false
var save_clock=0.0
## Seconds each disconnected seat has been away, kept by the host.
var away_clock={}


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
	rejected.emit(message)

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
	_reset_settings()
	if not dedicated:
		roster=[{"id":1,"name":pname,"ready":false,"connected":true,"bot":false,"look":CatanAppearance.sanitize(my_look),"color":my_color}]
		seat=0
	changed.emit()
	return OK

func join_room(address: String,pname: String,password: String="") -> Error:
	CatanDiagnostics.event("network.join")
	address=address.strip_edges()
	var endpoint=SECURE_INVITE.decode(address)
	if endpoint.is_empty():
		rejected.emit("Paste a valid invite code from the host.")
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
	if _can_save():save_game()
	resuming={}
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
	away_clock={}
	turn_clock=TURN_SECONDS
	turn_mark=[]
	turn_expired=false
	started=false
	roster=[]
	seat=-1
	last_action={}
	room_settings=DEFAULT_SETTINGS.duplicate()
	_reset_music()
	if continuing_music.get("ready",false):
		music_track=continuing_music.track
		music_position=continuing_music.position
		music_paused=continuing_music.paused
		music_context=continuing_music.duplicate(true)
	changed.emit()

func _connected():
	CatanDiagnostics.event("network.connected")
	_register.rpc_id(1,my_name,room_password,PROTOCOL,reconnect_token,my_look,CatanBuildInfo.VERSION,my_color)

@rpc("any_peer","call_remote","reliable")
func _register(pname: String,password: String,version: int,token: String="",look: PackedByteArray=PackedByteArray(),client_version: String="unknown",requested_color: String=""):
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
				roster[p].erase("stand_in")
				away_clock.erase(p)
				if old_id!=id and old_id in multiplayer.get_peers():multiplayer.multiplayer_peer.disconnect_peer(old_id)
				_session.rpc_id(id,token)
				rules._log(CatanI18n.message("%s reconnected. The expedition continues.",[roster[p].name]))
				_broadcast_lobby()
				_sync()
				return
	if started and password==room_password and _seat_for(id)==-1:
		# A seat resumed without its player, played by a bot until they come back.
		for p in roster.size():
			if roster[p].get("stand_in",false) and not seat_tokens.has(p) and str(roster[p].name).to_lower()==pname.strip_edges().to_lower():
				roster[p].id=id
				roster[p].connected=true
				roster[p].erase("stand_in")
				roster[p].look=CatanAppearance.sanitize(look)
				if not requested_color.is_empty() and valid_color(requested_color):roster[p].color=requested_color.to_lower()
				away_clock.erase(p)
				_give_session(p,id)
				rules._log(CatanI18n.message("%s rejoined and takes their seat back.",[roster[p].name]))
				_broadcast_lobby()
				_sync()
				return
	if not started and not resuming.is_empty() and password==room_password and _seat_for(id)==-1:
		_claim_saved_seat(id,pname,look,requested_color)
		return
	if version!=PROTOCOL or password!=room_password or started or roster.size()>=MAX_PLAYERS or _seat_for(id)!=-1:
		_registration_failed.rpc_id(id,"The password is incorrect." if password!=room_password else "This game has started. Use Reconnect to return to your saved seat." if started else "This room is full. Ask the host to free a seat." if roster.size()>=MAX_PLAYERS else "You already have a seat in this room.")
		return
	pname=pname.strip_edges().replace("\n"," ").substr(0,20)
	if pname.is_empty(): pname="Voyager"
	roster.append({"id":id,"name":pname,"ready":false,"connected":true,"bot":false,"look":CatanAppearance.sanitize(look),"color":requested_color if valid_color(requested_color) else ""})
	_give_session(roster.size()-1,id)
	_broadcast_lobby()

## A new bearer token for a seat, sent to the player who holds it.
func _give_session(p: int,id: int):
	var session_token=Crypto.new().generate_random_bytes(24).hex_encode()
	seat_tokens[p]=session_token
	_session.rpc_id(id,session_token)

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
		if err!=OK:rejected.emit("Could not reconnect. Ask the host for a new invite code.")

func _seat_for(id: int) -> int:
	for i in roster.size():
		if int(roster[i].id)==id: return i
	return -1

func _broadcast_lobby():
	for row in roster:
		if row.id>1 and row.connected: _lobby.rpc_id(row.id,roster,started,dedicated,room_settings)
	changed.emit()

@rpc("authority","call_remote","reliable")
func _lobby(players: Array,in_game: bool,server_dedicated: bool=false,settings: Dictionary={}):
	dedicated=server_dedicated
	room_settings=DEFAULT_SETTINGS.duplicate()
	room_settings.merge(settings,true)
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
		if not row.ready and not _waiting_seat(row): return
	if not resuming.is_empty():
		_restore()
		return
	world_seconds=150.0
	world_days=0
	_new_game()

func _new_game():
	var names=[]
	for row in roster: names.append(row.name)
	var options={"island":room_settings.island,"points":room_settings.points}
	for rule in CatanRules.HOUSE_RULES:options[rule]=bool(room_settings.get(rule,false))
	rules.create(names,int(room_settings.seed),options)
	game_count+=1
	rules.s.game_id=game_count
	turn_seconds=float(room_settings.turn_seconds)
	started=true
	bot_brains={}
	bot_turn=-1
	bot_action_count=0
	turn_mark=[]
	offer_clock=0.0
	_refresh_turn_clock()
	_broadcast_lobby()
	_sync()

## The controller starts another game with the same seats and rules on a fresh map.
func rematch():
	if multiplayer.is_server(): _rematch(1)
	else: _rematch_request.rpc_id(1)

@rpc("any_peer","call_remote","reliable")
func _rematch_request():
	if multiplayer.is_server(): _rematch(multiplayer.get_remote_sender_id())

func _rematch(id: int):
	if not started or tutorial or rules.s.is_empty() or int(rules.s.winner)==-1: return
	if id!=1 and (not dedicated or _seat_for(id)!=0): return
	if waiting_for_player():
		_send_error(id,"Wait for every player to reconnect before starting another game.")
		return
	room_settings.seed=_random_seed()
	_new_game()

static func _random_seed() -> int:
	return randi_range(1,999999)

func _reset_settings():
	room_settings=DEFAULT_SETTINGS.duplicate()
	room_settings.seed=_random_seed()

## Validates and stores one room setting. Only the controller may change them, and only in the lobby.
func choose_setting(key: String,value: Variant):
	if not online:return
	if multiplayer.is_server():_set_setting(1,key,value)
	else:_setting_request.rpc_id(1,key,value)

@rpc("any_peer","call_remote","reliable")
func _setting_request(key: String,value: Variant):
	if online and multiplayer.is_server():_set_setting(multiplayer.get_remote_sender_id(),key,value)

func _set_setting(sender: int,key: String,value: Variant):
	if started or not resuming.is_empty() or (sender!=1 and (not dedicated or _seat_for(sender)!=0)):return
	match key:
		"seed":
			if not (value is int) or value<1 or value>999999999:return
		"island":
			if not (value is String) or value not in CatanRules.ISLANDS:return
		"turn_seconds":
			if not (value is int) or value not in CatanRules.TURN_TIMERS:return
		"points":
			if not (value is int) or value<CatanRules.POINT_TARGETS[0] or value>CatanRules.POINT_TARGETS[1]:return
		_:
			if key not in CatanRules.HOUSE_RULES or not (value is bool):return
	if room_settings.get(key)==value:return
	room_settings[key]=value
	_broadcast_lobby()

func act(action: Dictionary):
	if not started or seat<0: return
	if tutorial and not tutorial_expected.is_empty() and str(action.get("type",""))!=tutorial_expected:
		rejected.emit("Follow the current tutorial step, or choose Skip lesson.")
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
	# A burst of quick clicks goes through; only a flood is turned away.
	var now=Time.get_ticks_msec()
	var budget: Array=last_action.get(id,[ACTION_BURST,now])
	budget[0]=minf(ACTION_BURST,budget[0]+(now-int(budget[1]))/1000.0*ACTION_RATE)
	budget[1]=now
	last_action[id]=budget
	if budget[0]<1.0:
		_send_error(id,"Too many actions at once. Wait a moment and try again.")
		return
	budget[0]-=1.0
	_apply_seat(p,action,id)

## Applies an action for a seat. Errors go back to the player who sent it;
## bots and seats a bot plays for pass 0 and are not told.
func _apply_seat(p: int,action: Dictionary,reply_to: int):
	var id=reply_to
	if waiting_for_player():
		_send_error(id,"Game paused while a disconnected player reconnects.")
		return
	CatanDiagnostics.event("action.begin","seat=%d type=%s turn=%s phase=%s"%[p,str(action.get("type","")).substr(0,40),rules.s.get("turn",-1),rules.s.get("phase","")])
	var error=rules.apply(p,action)
	CatanDiagnostics.event("action.complete","accepted=%s"%error.is_empty())
	if not error.is_empty(): _send_error(id,error)
	else:
		_refresh_turn_clock()
		if str(action.get("type",""))=="offer_trade":offer_clock=TRADE_WINDOW
		applied.emit(p,action)
		_sync()

func _sync():
	for p in roster.size():
		if not roster[p].connected or roster[p].get("bot",false): continue
		var state=rules.snapshot(p)
		state["world_seconds"]=world_seconds
		state["world_days"]=world_days
		state["turn_limit"]=turn_limit()
		state["turn_seconds"]=turn_clock
		state["player_colors"]=[]
		for row in roster:state.player_colors.append(str(row.get("color","")))
		state["piece_looks"]=[]
		for row in roster:state.piece_looks.append(row.get("look",CatanAppearance.default_bytes()))
		if roster[p].id==1: received.emit(state)
		else: _state.rpc_id(roster[p].id,state)
	save_dirty=true

@rpc("authority","call_remote","reliable")
func _state(state: Dictionary):
	started=true
	received.emit(state)

func _send_error(id: int,message: String):
	if id==1: rejected.emit(message)
	elif id>1 and id in multiplayer.get_peers(): _error.rpc_id(id,message)

@rpc("authority","call_remote","reliable")
func _error(message: String):
	rejected.emit(message)

## True while the game waits for someone who left and no bot plays for them yet.
func waiting_for_player() -> bool:
	return roster.any(func(row):return not row.connected and not row.get("stand_in",false) and not _waiting_seat(row))

## A saved seat still waiting in the lobby for its player.
static func _waiting_seat(row: Dictionary) -> bool:
	return row.get("saved_seat",false) and not row.connected

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
		away_clock[p]=0.0
		rules._log(CatanI18n.message("%s disconnected. The game is paused, and a bot takes their seat if they are not back in a minute.",[roster[p].name]))
		_sync()
	elif roster[p].get("saved_seat",false):
		# A saved seat stays open for its player to come back.
		roster[p].id=0
		roster[p].connected=false
		roster[p].ready=false
		seat_tokens.erase(p)
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
	if _can_save():save_game()
	if multiplayer.multiplayer_peer:multiplayer.multiplayer_peer.close()
	secure_transport.stop()
	if upnp_thread: upnp_thread.wait_to_finish()

func host_solo(pname: String):
	leave()
	online=true
	solo=true
	dedicated=false
	seat=0
	_reset_settings()
	roster=[{"id":1,"name":pname,"ready":true,"connected":true,"bot":false,"look":CatanAppearance.sanitize(my_look),"color":my_color}]
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
	# A resumed game keeps its seats, though bots may still change difficulty.
	if not resuming.is_empty() and operation!="difficulty": return
	if sender!=1 and (not dedicated or _seat_for(sender)!=0): return
	if operation=="add" and roster.size()<MAX_PLAYERS:
		var id=-1
		while _seat_for(id)>=0: id-=1
		var bot_name=["Juniper","Flint","Coral","Atlas","Willow","Slate"][(-id-1)%6]
		roster.append({"id":id,"name":bot_name,"ready":true,"connected":true,"bot":true,"difficulty":difficulty,"look":_bot_look(id)})
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

## Bots wear a preset with their own variation seed, so two Harbor bots still differ.
func _bot_look(id: int) -> PackedByteArray:
	var values=CatanAppearance.preset((-id)%CatanAppearance.PRESETS.size())
	values.seed=(-id*37)%256
	return CatanAppearance.encode(values)

func choose_look(look: PackedByteArray,target: int=-1):
	look=CatanAppearance.sanitize(look)
	if target<0:target=seat
	if not online or target<0:
		my_look=look
		return
	if multiplayer.is_server():_set_look(1,target,look)
	else:_look_request.rpc_id(1,target,look)

@rpc("any_peer","call_remote","reliable")
func _look_request(target: int,look: PackedByteArray):
	if online and multiplayer.is_server():_set_look(multiplayer.get_remote_sender_id(),target,look)

func _set_look(sender: int,target: int,look: PackedByteArray):
	if target<0 or target>=roster.size():return
	var own=_seat_for(sender)
	var controller=sender==1 or (dedicated and own==0)
	if target!=own and not (controller and roster[target].get("bot",false)):return
	# Re-encoding clamps every field, whatever the client sent.
	look=CatanAppearance.sanitize(look)
	if roster[target].get("look",PackedByteArray())==look:return
	roster[target].look=look
	if target==seat:my_look=look
	_broadcast_lobby()
	if started:_sync()

func player_look(player: int) -> PackedByteArray:
	if player>=0 and player<roster.size():return roster[player].get("look",CatanAppearance.default_bytes())
	return my_look

func _process(delta: float):
	secure_transport.poll()
	_process_music(delta)
	save_clock-=delta
	if save_dirty and save_clock<=0.0 and _can_save():
		save_clock=1.0
		save_game()
	if online and started and multiplayer.is_server() and not paused and not waiting_for_player():
		if world_seconds+delta>=600.0:world_days+=1
		world_seconds=fposmod(world_seconds+delta,600.0)
	if not online or not started or not multiplayer.is_server() or tutorial or paused or rules.s.is_empty() or rules.s.winner!=-1: return
	_advance_away_clock(delta)
	if waiting_for_player(): return
	_advance_turn_clock(delta)
	_advance_offer_clock(delta)
	bot_clock-=delta
	if bot_clock>0: return
	bot_clock=bot_delay
	if bot_turn!=rules.s.turn:
		bot_turn=rules.s.turn
		bot_action_count=0
	for p in roster.size():
		var forced=_timed_out(p)
		var automatic=roster[p].get("bot",false) or roster[p].get("stand_in",false)
		if not automatic and not forced: continue
		if not bot_brains.has(p): bot_brains[p]=CatanBot.new()
		var action=_timeout_action(p) if forced and not automatic else bot_brains[p].choose(rules.snapshot(p),p,int(roster[p].get("difficulty",1)))
		if action.is_empty(): continue
		if p==rules.s.turn:
			bot_action_count+=1
			if bot_action_count>30 and rules.s.phase=="play" and rules.s.rolled: action={"type":"end"}
		_apply_seat(p,action,0 if automatic else int(roster[p].id))
		return

## A player who stays away past STAND_IN_SECONDS gets a bot in their seat. It
## plays until they reconnect, so one lost connection doesn't stop the game.
func _advance_away_clock(delta: float):
	for p in roster.size():
		var row: Dictionary=roster[p]
		if row.connected or row.get("stand_in",false) or row.get("bot",false):continue
		away_clock[p]=float(away_clock.get(p,0.0))+delta
		if away_clock[p]<STAND_IN_SECONDS:continue
		row.stand_in=true
		rules._log(CatanI18n.message("%s is still away. A bot plays their seat until they return.",[row.name]))
		_broadcast_lobby()
		_sync()

func _advance_offer_clock(delta: float):
	if rules.s.offer.is_empty() or not rules.s.offer.get("waiting",false):return
	offer_clock-=delta
	if offer_clock>0.0:return
	rules.open_offer()
	_sync()

## Clients receive only the newest log lines with each state; the log dialog
## asks for the whole history when it has a gap.
func request_log():
	if not online or not started:return
	if multiplayer.is_server():log_received.emit(CatanRules.log_for(seat,rules.s.get("log",[])))
	else:_log_request.rpc_id(1)

@rpc("any_peer","call_remote","reliable")
func _log_request():
	if not online or not multiplayer.is_server() or not started:return
	var sender=multiplayer.get_remote_sender_id()
	var p=_seat_for(sender)
	if p<0:return
	_full_log.rpc_id(sender,CatanRules.log_for(p,rules.s.get("log",[])))

@rpc("authority","call_remote","reliable")
func _full_log(entries: Array):
	log_received.emit(entries)

## Seconds a seat may hold the game before the host plays the turn out for it.
func turn_limit() -> float:
	return 0.0 if solo or tutorial else turn_seconds

# The clock rearms whenever the set of seats the game waits on changes. Setup
# alternates twice per seat and the extension pairs two seats per turn, so the
# seat number alone does not identify a turn; a seven hands the wait to whoever
# has to discard, and they have not had any of this turn's time yet.
func _turn_mark() -> Array:
	return [int(rules.s.get("turn",-1)),int(rules.s.get("setup",-1)),bool(rules.s.get("paired",false)),str(rules.s.get("phase",""))=="discard"]

func _refresh_turn_clock():
	var mark=_turn_mark()
	if mark==turn_mark: return
	turn_mark=mark
	turn_clock=turn_limit()
	turn_expired=false

func _advance_turn_clock(delta: float):
	_refresh_turn_clock()
	if turn_expired or turn_limit()<=0.0: return
	turn_clock=maxf(0.0,turn_clock-delta)
	if turn_clock>0.0: return
	turn_expired=true
	for p in roster.size():
		if _timed_out(p) and not roster[p].get("bot",false):
			_send_error(roster[p].id,"Your turn time ran out.")

# A seat is played out only while it is the one holding the game up.
func _timed_out(p: int) -> bool:
	if not turn_expired or p<0 or p>=roster.size(): return false
	if rules.s.phase=="discard": return rules.s.discards.has(str(p))
	return p==int(rules.s.turn)

# Time out into the shortest legal exit: the bot only picks the placements the
# rules demand before the turn can pass on.
func _timeout_action(p: int) -> Dictionary:
	match str(rules.s.phase):
		"play": return {"type":"end"} if rules.s.rolled else {"type":"roll"}
		"free_roads": return {"type":"finish_roads"}
	return bot_brains[p].choose(rules.snapshot(p),p,0)


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
		rejected.emit("The room host controls the shared soundtrack. Your volume is personal.")
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


static func save_path(solo_game: bool) -> String:
	return SAVE_DIR+("/solo.save" if solo_game else "/room.save")

func _can_save() -> bool:
	return online and started and not tutorial and multiplayer.is_server() and not rules.s.is_empty()

## Writes the whole game: the rules state with its hidden deck, dice and dice
## stream, the seats and the room settings. A finished game clears its slot.
func save_game():
	save_dirty=false
	var path=save_path(solo)
	if int(rules.s.get("winner",-1))!=-1:
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
		return
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var seats=[]
	for row in roster:
		seats.append({"name":str(row.name),"bot":bool(row.get("bot",false)),"difficulty":int(row.get("difficulty",1)),"look":row.get("look",CatanAppearance.default_bytes()),"color":str(row.get("color","")),"host":int(row.id)==1})
	var data={"format":SAVE_FORMAT,"protocol":PROTOCOL,"version":CatanBuildInfo.VERSION,"saved":int(Time.get_unix_time_from_system()),"solo":solo,
		"rules":rules.s,"rng_seed":rules.rng.seed,"rng_state":rules.rng.state,"seats":seats,"settings":room_settings,"world_seconds":world_seconds,"world_days":world_days}
	# Write beside the save and swap it in, so a crash mid-write keeps the old one.
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:return
	file.store_var(data)
	file.close()
	DirAccess.rename_absolute(path+".tmp",path)

## The saved game for this kind of room, or an empty dictionary when there is
## none or it came from a build that plays by different rules.
static func load_save(solo_game: bool) -> Dictionary:
	var data=_read_save(solo_game)
	if data.is_empty() or int(data.get("format",0))!=SAVE_FORMAT or int(data.get("protocol",0))!=PROTOCOL:return {}
	for key in ["rules","seats","settings"]:
		if not data.has(key):return {}
	if not data.rules is Dictionary or not data.seats is Array or data.seats.size()<MIN_PLAYERS or data.seats.size()>MAX_PLAYERS:return {}
	return data

## What the lobby shows about the saved game: who played, how far it got and when.
func saved_summary() -> Dictionary:
	if not online or not multiplayer.is_server() or dedicated or started or not resuming.is_empty():return {}
	var data=load_save(solo)
	if data.is_empty():
		# A save from a build with different rules can't be resumed; say so.
		var raw=_read_save(solo)
		if raw.is_empty():return {}
		return {"outdated":true,"version":str(raw.get("version","?")).substr(0,40)}
	var names=[]
	for seat_row in data.seats:names.append(str(seat_row.name))
	return {"names":names,"turn":maxi(0,data.rules.get("points_history",[]).size()-1),"saved":int(data.get("saved",0))}

static func _read_save(solo_game: bool) -> Dictionary:
	var path=save_path(solo_game)
	if not FileAccess.file_exists(path):return {}
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null:return {}
	var data=file.get_var(false)
	return data if data is Dictionary else {}

## Seats the lobby from the save: bots return as they were, the host takes
## their old seat, and every other seat waits for its player to rejoin.
func resume_saved():
	if not online or not multiplayer.is_server() or dedicated or started:return
	var data=load_save(solo)
	if data.is_empty():
		rejected.emit("The saved game could not be read.")
		return
	resuming=data
	room_settings=DEFAULT_SETTINGS.duplicate()
	room_settings.merge(data.settings,true)
	room_settings.resuming=true
	var guests=[]
	for row in roster:
		if int(row.id)>1 and row.connected:guests.append(row)
	roster=[]
	seat_tokens={}
	for i in data.seats.size():
		var saved: Dictionary=data.seats[i]
		var row={"name":saved.name,"look":CatanAppearance.sanitize(saved.look),"color":saved.color if valid_color(saved.color) else "","bot":saved.bot}
		if saved.bot:
			row.merge({"id":-1-i,"ready":true,"connected":true,"difficulty":clampi(int(saved.difficulty),0,2)})
		elif saved.host:
			row.merge({"id":1,"ready":solo,"connected":true})
		else:
			row.merge({"id":0,"ready":false,"connected":false,"saved_seat":true})
		roster.append(row)
	seat=_seat_for(1)
	if seat>=0:my_look=roster[seat].look
	# Guests already in the room take the seats that wait for them.
	for guest in guests:_claim_saved_seat(int(guest.id),str(guest.name),guest.get("look",PackedByteArray()),str(guest.get("color","")))
	_broadcast_lobby()
	if solo:_start(1)

## Puts a joining player in a saved seat: the one with their name, else the
## first seat still free. With none free, they cannot join this room. The
## player brings their current pieces and colour.
func _claim_saved_seat(id: int,pname: String,look: PackedByteArray=PackedByteArray(),color: String=""):
	var chosen=-1
	for p in roster.size():
		if roster[p].get("saved_seat",false) and not roster[p].connected and str(roster[p].name).to_lower()==pname.strip_edges().to_lower():chosen=p
	if chosen<0:
		for p in roster.size():
			if roster[p].get("saved_seat",false) and not roster[p].connected:
				chosen=p
				break
	if chosen<0:
		_registration_failed.rpc_id(id,"This room is resuming a saved game and every seat is taken.")
		return
	roster[chosen].id=id
	roster[chosen].connected=true
	roster[chosen].ready=false
	if not look.is_empty():roster[chosen].look=CatanAppearance.sanitize(look)
	if not color.is_empty() and valid_color(color):roster[chosen].color=color.to_lower()
	_give_session(chosen,id)
	_broadcast_lobby()

## Drops the saved game from the lobby: the players who are here stay, the
## seats that were waiting for someone go.
func cancel_resume():
	if resuming.is_empty() or started:return
	resuming={}
	room_settings.erase("resuming")
	var kept=[]
	var tokens={}
	for p in roster.size():
		if roster[p].get("saved_seat",false) and not roster[p].connected:continue
		roster[p].erase("saved_seat")
		if seat_tokens.has(p):tokens[kept.size()]=seat_tokens[p]
		kept.append(roster[p])
	roster=kept
	seat_tokens=tokens
	seat=_seat_for(1)
	_broadcast_lobby()

func _restore():
	var data=resuming
	resuming={}
	room_settings.erase("resuming")
	rules.s=data.rules.duplicate(true)
	rules.rng.seed=int(data.get("rng_seed",0))
	rules.rng.state=int(data.get("rng_state",0))
	# An offer waiting for answers when the game was saved would wait forever.
	rules.s.offer={}
	# Seats nobody came back for start with a bot; their player can still
	# rejoin by name with the invite and take over.
	for p in roster.size():
		var row: Dictionary=roster[p]
		if _waiting_seat(row):
			row.id=-100-p
			row.stand_in=true
			row.ready=true
			rules._log(CatanI18n.message("%s is still away. A bot plays their seat until they return.",[row.name]))
		row.erase("saved_seat")
	away_clock={}
	game_count+=1
	rules.s.game_id=game_count
	turn_seconds=float(room_settings.turn_seconds)
	world_seconds=float(data.get("world_seconds",150.0))
	world_days=int(data.get("world_days",0))
	started=true
	bot_brains={}
	bot_turn=-1
	bot_action_count=0
	turn_mark=[]
	offer_clock=0.0
	rules._log("The game resumes from where it was saved.")
	_refresh_turn_clock()
	_broadcast_lobby()
	_sync()
