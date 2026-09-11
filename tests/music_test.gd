extends SceneTree
var checks=0
var failures=0
var player
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func pump(sample: Dictionary,seconds: float) -> Dictionary:
	var start=Time.get_ticks_usec();var previous=start
	while Time.get_ticks_usec()-start<seconds*1000000:
		await process_frame
		var now=Time.get_ticks_usec();var delta=(now-previous)/1000000.0;previous=now
		sample=CatanSoundtrack.advance(sample,delta);player.follow_soundtrack(sample,delta)
	return sample
func run():
	Engine.max_fps=60
	var original_buses=AudioServer.bus_count
	player=load("res://scenes/audio.tscn").instantiate();root.add_child(player)
	check(CatanSoundtrack.TRACKS.size()==5,"five original tracks")
	for i in 5:
		var source=player.track_stream(i)
		check(absf(source.get_length()-CatanSoundtrack.TRACKS[i].duration)<.003,"duration matches original recording")
		check(source is AudioStreamWAV if i==0 else source is AudioStreamOggVorbis,"original formats retained")
	var sample={"track":0,"position":10.0,"paused":false,"generation":0}
	sample=await pump(sample,.6)
	var old=player.music
	sample=CatanSoundtrack.switch_to(sample,1)
	sample=await pump(sample,2.0)
	check(player.current_track==1 and player.music.playing and old.playing,"manual switch overlaps active players")
	var row=player.music_voices["%s:%s"%[sample.generation,sample.track]]
	check(row.eq.get_band_gain_db(0)<row.eq.get_band_gain_db(5),"incoming bass enters after upper texture")
	check(row.wet.playing and row.pitch.pitch_scale>1,"nearby tempo is matched with compensating pitch shift")
	var earlier=old
	sample=CatanSoundtrack.switch_to(sample,2)
	sample=await pump(sample,.2)
	check(is_instance_valid(earlier) and earlier.playing,"rapid switching preserves first outgoing player")
	sample.paused=true;sample=await pump(sample,.15)
	var position=player.audible_position()
	sample=await pump(sample,.2)
	check(absf(player.audible_position()-position)<.01 and player.music_spare.stream_paused,"pause freezes every voice")
	sample.paused=false
	sample=await pump(sample,9)
	check(player.fading_tracks.is_empty() and player.music_voices.size()==1,"completed fade releases outgoing players and buses")
	check(not player.music_voices.values()[0].wet.playing,"natural tempo returns to untouched dry playback")
	var late=load("res://scenes/audio.tscn").instantiate();root.add_child(late)
	var joining=CatanSoundtrack.advance(CatanSoundtrack.switch_to(sample,4),2.0)
	player.follow_soundtrack(joining,.016);late.follow_soundtrack(joining,.016)
	check(player.music_voices.keys()==late.music_voices.keys(),"late join reconstructs all active voices")
	for key in player.music_voices:
		check(is_equal_approx(player.music_voices[key].eq.get_band_gain_db(2),late.music_voices[key].eq.get_band_gain_db(2)),"late join reconstructs current EQ envelope")
	late.queue_free()
	var values=CatanSettings.DEFAULTS.duplicate();values.music=0.0;player.apply(values)
	sample=await pump(joining,.2)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")) and player.music.playing,"local mute preserves playback")
	sample.position+=5
	var seeks=player.seek_count
	sample=await pump(sample,.6)
	check(player.seek_count>seeks,"large room drift corrects playback")
	player.queue_free();await create_timer(.2).timeout
	for i in AudioServer.bus_count:check(not str(AudioServer.get_bus_name(i)).begins_with("Score_"),"voice buses removed on shutdown")
	check(AudioServer.bus_count<=original_buses+3,"no audio bus leak")
	print("MUSIC_TEST: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
