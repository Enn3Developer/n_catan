class_name CatanAudio
extends Node
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var voices=[]
var sounds={}
var voice_index=0
var music_spare: AudioStreamPlayer
var track_streams={}
var current_track=0
var correction_clock=0.0
var music_fade: Tween
var seek_count=0

func _ready():
	if "--server" in OS.get_cmdline_user_args(): return
	for bus_name in ["Music","Effects","Ambience"]:
		if AudioServer.get_bus_index(bus_name)<0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus_name)
	music=$Music
	ambience=$Ambience
	music.bus="Music"
	ambience.bus="Ambience"
	music.stream=_loop("harbor")
	track_streams[0]=music.stream
	music.volume_db=CatanSoundtrack.TRACKS[0].get("gain_db",0.0)
	music_spare=AudioStreamPlayer.new()
	music_spare.name="MusicCrossfade";music_spare.bus="Music";add_child(music_spare)
	ambience.stream=_loop("sea")
	for effect in ["click","build","trade","card","turn","error","dice","win"]:
		sounds[effect]=load("res://assets/audio/%s.wav" % effect)
	for i in 8:
		var voice=AudioStreamPlayer.new()
		voice.bus="Effects"
		add_child(voice)
		voices.append(voice)
	apply(CatanSettings.new().values)
	music.play()
	ambience.play()
func _loop(name_value: String) -> AudioStreamWAV:
	var stream=load("res://assets/audio/%s.wav" % name_value).duplicate() as AudioStreamWAV
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin=0
	stream.loop_end=roundi(stream.get_length()*stream.mix_rate)
	return stream
func apply(values: Dictionary):
	for pair in [["Master","master"],["Music","music"],["Effects","effects"],["Ambience","ambience"]]:
		var index=AudioServer.get_bus_index(pair[0])
		if index<0: continue
		AudioServer.set_bus_mute(index,float(values[pair[1]])<=0.001)
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(0.001,float(values[pair[1]]))))
func play(effect: String):
	if not sounds.has(effect) or voices.is_empty(): return
	var voice=voices[voice_index%voices.size()]
	voice_index+=1
	voice.stream=sounds[effect]
	voice.play()
func transition(previous: Dictionary,current: Dictionary,seat: int):
	if previous.is_empty(): play("turn"); return
	if current.winner!=previous.winner and current.winner!=-1: play("win"); return
	if current.turn!=previous.turn and current.turn==seat: play("turn")
	if current.dice!=previous.dice or (current.rolled and not previous.rolled): play("dice")
	if current.vertices!=previous.vertices or current.edges!=previous.edges: play("build")
	if current.log!=previous.log and not current.log.is_empty():
		var text=str(current.log[-1])
		if "traded" in text: play("trade")
		elif "card" in text: play("card")


func track_stream(index: int) -> AudioStream:
	if not track_streams.has(index):
		var stream=load(CatanSoundtrack.TRACKS[index].file).duplicate() as AudioStream
		if stream is AudioStreamOggVorbis:stream.loop=true
		track_streams[index]=stream
	return track_streams[index]

func _start_track(index: int,position_seconds: float,paused_value: bool):
	if music_fade and music_fade.is_valid():music_fade.kill()
	var old=music
	music=music_spare;music_spare=old
	music.stop();music.stream=track_stream(index);music.pitch_scale=1.0
	current_track=index
	var offset=position_seconds if paused_value else position_seconds+AudioServer.get_output_latency()
	music.play(minf(offset,CatanSoundtrack.TRACKS[index].duration-.001))
	music.stream_paused=paused_value
	var gain=float(CatanSoundtrack.TRACKS[index].get("gain_db",0.0))
	if paused_value or not old.playing:
		old.stop();music.volume_db=gain
	else:
		music.volume_db=-50
		music_fade=create_tween().set_parallel(true)
		music_fade.tween_property(music,"volume_db",gain,.25)
		music_fade.tween_property(old,"volume_db",-50.0,.25)
		music_fade.chain().tween_callback(old.stop)
	correction_clock=.5

func audible_position() -> float:
	if not is_instance_valid(music):return 0
	if music.stream_paused:return music.get_playback_position()
	return maxf(0,music.get_playback_position()+AudioServer.get_time_since_last_mix()-AudioServer.get_output_latency())

func follow_soundtrack(sample: Dictionary,delta: float):
	if not is_instance_valid(music):return
	if not sample.get("ready",true):
		music.stream_paused=true;music_spare.stream_paused=true
		return
	var index=int(sample.track)
	if index!=current_track:
		_start_track(index,float(sample.position),sample.paused)
		return
	if music.stream_paused!=sample.paused:
		music_spare.stop()
		music.stream_paused=sample.paused
		music.pitch_scale=1.0
		music.seek(sample.position+(0.0 if sample.paused else AudioServer.get_output_latency()))
		correction_clock=.5
	if not music.playing:
		music.play(sample.position)
		music.stream_paused=sample.paused
	if sample.paused:return
	correction_clock-=delta
	if correction_clock>0:return
	correction_clock=.5
	var drift=float(sample.position)-audible_position()
	if absf(drift)>.18:
		music.seek(minf(sample.position+AudioServer.get_output_latency(),CatanSoundtrack.TRACKS[index].duration-.001))
		music.pitch_scale=1.0
		seek_count+=1
	else:
		# Correct tiny clock differences gently instead of repeatedly seeking.
		music.pitch_scale=clampf(1.0+drift*.06,.99,1.01) if absf(drift)>.025 else 1.0

func _exit_tree():
	if music_fade and music_fade.is_valid():music_fade.kill()
	for player in [music,music_spare,ambience]+voices:
		if is_instance_valid(player):player.stop();player.stream=null
	track_streams.clear();sounds.clear()
