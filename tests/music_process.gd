extends SceneTree
var net
var audio
var role=""
var folder=""
var stage=0
var clock=0.0
var max_drift=0.0
var samples=0
var saw_pause=false
var saw_tracks={}
var reported=false
func _initialize():call_deferred("run")
func run():
	Engine.max_fps=60
	role=OS.get_cmdline_user_args()[0];folder=OS.get_cmdline_user_args()[1]
	var game=Node.new();game.name="Catan";root.add_child(game)
	net=CatanNetwork.new();net.name="Network";game.add_child(net)
	audio=load("res://scenes/audio.tscn").instantiate();game.add_child(audio)
	if role=="host":net.host("Host","music")
	else:net.join_room(FileAccess.get_file_as_string(folder+"/invite"),role,"music")
	if role=="host":
		var invite_file=FileAccess.open(folder+"/invite",FileAccess.WRITE)
		invite_file.store_string(net.secure_invite("127.0.0.1"));invite_file.close()
	create_timer(18).timeout.connect(func():quit(1))
func _process(delta):
	if net==null or audio==null:return false
	var sample=net.music_state()
	audio.follow_soundtrack(sample,delta)
	if sample.get("ready",false):
		saw_tracks[int(sample.track)]=true
		if sample.paused and audio.music.stream_paused:saw_pause=true
		if not sample.paused and sample.position>.75:
			max_drift=maxf(max_drift,absf(sample.position-audio.audible_position()));samples+=1
	if role=="host":
		clock+=delta
		if stage==0 and net.roster.size()==3:net.music_control("select",2);stage=1;clock=0
		elif stage==1 and clock>2:net.music_control("toggle");stage=2;clock=0
		elif stage==2 and clock>1:net.music_control("select",4);stage=3;clock=0
		elif stage==3 and clock>2.5:
			var file=FileAccess.open(folder+"/finish",FileAccess.WRITE);file.store_string("done");file.close();stage=4
	if FileAccess.file_exists(folder+"/finish") and not reported:
		reported=true
		var passed=saw_pause and saw_tracks.has(2) and saw_tracks.has(4) and samples>60 and max_drift<.18
		print("MUSIC_PROCESS ",role," samples=",samples," max_drift_ms=",max_drift*1000," shared_pause=",saw_pause," result=",("PASS" if passed else "FAIL"))
		finish.call_deferred(passed)
	return false
func finish(passed):
	await create_timer(.3).timeout
	net.leave();audio.queue_free();await process_frame;await process_frame
	quit(0 if passed else 1)
