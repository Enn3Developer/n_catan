extends SceneTree
var peers=[]
var checks=0
var failures=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func make_peer(index):
	var branch=Node.new();branch.name="Peer%d" % index;root.add_child(branch)
	set_multiplayer(SceneMultiplayer.new(),branch.get_path())
	var net=CatanNetwork.new();net.name="Network";branch.add_child(net);peers.append(net);return net
func aligned(label):
	var first=peers[0].music_state()
	for peer in peers.slice(1):
		var sample=peer.music_state()
		check(sample.get("ready",false),label+" ready")
		check(sample.track==first.track and sample.paused==first.paused,label+" same track and transport")
		check(absf(sample.position-first.position)<.08,label+" room clocks within 80 ms")
		var left=CatanSoundtrack.mix_voices(first);var right=CatanSoundtrack.mix_voices(sample)
		check(left.size()==right.size(),label+" shared outgoing voice count")
		if left.size()==right.size():
			for i in left.size():
				check(left[i].id==right[i].id and left[i].track==right[i].track,label+" shared voice identity")
				check(absf(left[i].position-right[i].position)<.08,label+" shared outgoing position")
				check(absf(left[i].bands[2]-right[i].bands[2])<.05,label+" shared spectral envelope")
func run():
	var host=make_peer(0);var a=make_peer(1);var b=make_peer(2)
	check(host.host("Host")==OK,"host starts")
	a.join_room(host.secure_invite("127.0.0.1"),"Ada");b.join_room(host.secure_invite("127.0.0.1"),"Bo")
	await create_timer(.8).timeout;aligned("initial join")
	host.music_control("select",2);await create_timer(.3).timeout;aligned("track change")
	check(a.music_state().track==2,"host selects shared track")
	host.music_control("toggle");await create_timer(.3).timeout;aligned("pause")
	var paused=a.music_state().position;await create_timer(.3).timeout
	check(absf(a.music_state().position-paused)<.001,"all clients hold paused position")
	a._music_command.rpc_id(1,"next",-1);await create_timer(.2).timeout
	check(host.music_state().track==2 and host.music_state().paused,"guest cannot change room playback even through RPC")
	host.music_control("select",4);await create_timer(.3).timeout
	host.music_context.clear();host.music_position=CatanSoundtrack.playback_span(4)-.15;host.music_anchor_ms=Time.get_ticks_msec();host.music_revision+=1;host._broadcast_music()
	await create_timer(.4).timeout;aligned("automatic wrap")
	check(a.music_state().track==0,"clients extrapolate through playlist wrap")
	var old=a.music_remote.duplicate();old.revision-=1;old.track=3
	a._accept_music(old,0);check(a.music_state().track==0,"old packets cannot rewind soundtrack")
	host.ready_up();a.ready_up();b.ready_up();await create_timer(.2).timeout;host.start_game();await create_timer(.2).timeout
	host.music_control("select",3);await create_timer(.3).timeout
	var saved_seat=a.seat;a.leave();await create_timer(.2).timeout;a.reconnect();await create_timer(.65).timeout
	check(a.started and a.seat==saved_seat,"game seat reconnects")
	aligned("reconnected music")
	for peer in [b,a,host]:peer.leave()
	await create_timer(.2).timeout
	check(host.host("Dedicated","",true)==OK,"dedicated host starts")
	a.join_room(host.secure_invite("127.0.0.1"),"Controller");await create_timer(.25).timeout
	b.join_room(host.secure_invite("127.0.0.1"),"Guest");await create_timer(.5).timeout
	check(a.seat==0 and a.can_control_music() and not b.can_control_music(),"first dedicated player controls music")
	a.music_control("select",1);await create_timer(.3).timeout;aligned("dedicated selection")
	for peer in [b,a,host]:peer.leave()
	print("MUSIC_NETWORK_TEST: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
