extends SceneTree
var peers=[]
var snapshots=[{},{}]
var failures=0
var checks=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func make_peer(index: int):
	var branch=Node.new();branch.name="Peer"+str(index);root.add_child(branch)
	set_multiplayer(SceneMultiplayer.new(),branch.get_path())
	var peer=CatanNetwork.new();peer.name="Network";branch.add_child(peer)
	peer.received.connect(func(data):snapshots[index]=data)
	peers.append(peer);return peer
func _initialize():call_deferred("run")
func pause():await create_timer(.3).timeout
func run():
	var host=make_peer(0);var guest=make_peer(1)
	host.my_style=1;guest.my_style=3
	host.my_color="123456";guest.my_color="abcdef"
	check(host.host("Host")==OK,"host starts")
	check(guest.join_room(host.invite("127.0.0.1"),"Guest")==OK,"guest joins")
	for attempt in 40:
		if host.roster.size()==2 and guest.roster.size()==2:break
		await create_timer(.1).timeout
	if host.roster.size()!=2 or guest.roster.size()!=2:
		check(false,"both peers finish registration");guest.leave();host.leave();quit(1);return
	check(host.roster[0].piece_style==1 and host.roster[1].piece_style==3,"handshake preserves both styles")
	check(host.roster[0].color=="123456" and host.roster[1].color=="abcdef","handshake carries both colors")
	host.configure_bot("add")
	await pause()
	guest.choose_color("22aadd")
	guest.choose_piece_style(2)
	await pause()
	check(host.roster[1].piece_style==2 and guest.roster[1].piece_style==2,"guest choice replicates")
	check(host.roster[1].color=="22aadd" and guest.roster[1].color=="22aadd","guest color replicates")
	guest._color_request.rpc_id(1,0,"ffffff")
	guest._color_request.rpc_id(1,2,"ffffff")
	guest._color_request.rpc_id(1,1,"invalid")
	guest._piece_style_request.rpc_id(1,0,3)
	guest._piece_style_request.rpc_id(1,2,3)
	guest._piece_style_request.rpc_id(1,1,900)
	await pause()
	check(host.roster[0].piece_style==1 and host.roster[2].piece_style==1 and host.roster[1].piece_style==2,"reject changing others, bots and invalid style")
	check(host.roster[0].color=="123456" and host.roster[1].color=="22aadd" and host.roster[2].get("color","")=="","reject unauthorized and invalid colors")
	host.choose_color("654321",1)
	check(host.roster[1].color=="22aadd","host cannot recolor another human")
	host.choose_color("aa55cc",2)
	host.choose_piece_style(0,1)
	check(host.roster[1].piece_style==2,"host cannot override another human")
	host.choose_piece_style(0,2)
	await pause()
	check(guest.roster[2].piece_style==0,"host bot choice replicates")
	host.ready_up();guest.ready_up();await pause();host.start_game();host.paused=true
	await pause()
	check(snapshots[0].piece_styles==[1,2,0] and snapshots[1].piece_styles==[1,2,0],"in-game cosmetic snapshot replicated")
	check(snapshots[0].player_colors==["123456","22aadd","aa55cc"] and snapshots[1].player_colors==snapshots[0].player_colors,"all colors replicated to match")
	var state_before=var_to_str(host.rules.s)
	guest.choose_piece_style(3);await pause()
	check(snapshots[0].piece_styles[1]==3 and snapshots[1].piece_styles[1]==3,"in-match style change synchronized")
	check(var_to_str(host.rules.s)==state_before,"cosmetics leave game state untouched")
	check(snapshots[1].players[0].hand.is_empty(),"private hands remain private")
	guest.leave();await pause();guest.reconnect();await pause();await pause()
	check(guest.roster[1].color=="22aadd","reconnect restores color")
	check(guest.seat==1 and guest.roster[1].piece_style==3,"reconnection restores equipped style")
	guest.leave();host.leave()
	print("COSMETICS_NETWORK_TEST: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
