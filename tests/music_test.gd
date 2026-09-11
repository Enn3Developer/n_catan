extends SceneTree
var checks=0
var failures=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
	var player=load("res://scenes/audio.tscn").instantiate();root.add_child(player)
	check(CatanSoundtrack.TRACKS.size()==5,"five original tracks")
	for i in CatanSoundtrack.TRACKS.size():
		var source=player.track_stream(i)
		check(absf(source.get_length()-CatanSoundtrack.TRACKS[i].duration)<.003,"playlist duration matches imported audio: "+str(i))
		check(source is AudioStreamWAV if i==0 else source is AudioStreamOggVorbis,"new tracks use compressed Vorbis")
		player.follow_soundtrack({"track":i,"position":3.0,"paused":false,"ready":true},.016)
		await create_timer(.3).timeout
		check(player.current_track==i and player.music.playing,"track selection starts playback")
	var boundary=CatanSoundtrack.advance({"track":4,"position":CatanSoundtrack.TRACKS[4].duration-.2,"paused":false},.65)
	check(boundary.track==0 and is_equal_approx(boundary.position,.45),"last track wraps to first at exact boundary")
	var frozen=CatanSoundtrack.advance({"track":2,"position":12.5,"paused":true},100)
	check(frozen.track==2 and frozen.position==12.5,"paused clock stays fixed")
	player.follow_soundtrack({"track":4,"position":3.4,"paused":true},.016)
	await create_timer(.2).timeout
	check(player.music.stream_paused,"shared pause pauses audio")
	var position=player.audible_position();await create_timer(.2).timeout
	check(absf(player.audible_position()-position)<.01,"audio remains at paused position")
	var values=CatanSettings.DEFAULTS.duplicate();values.music=0.0;player.apply(values)
	player.follow_soundtrack({"track":4,"position":3.4,"paused":false},.016)
	await create_timer(.2).timeout
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")),"music mute applies locally")
	check(player.music.playing and not player.music.stream_paused,"muting keeps shared timeline running")
	values.music=.42;player.apply(values)
	player.follow_soundtrack({"track":4,"position":14.0,"paused":false},1.0)
	await create_timer(.1).timeout
	check(player.seek_count>0 and player.audible_position()>13.5,"large drift seeks to room position")
	player.queue_free();await process_frame;await process_frame
	print("MUSIC_TEST: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
