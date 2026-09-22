class_name CatanAudio
extends Node
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var rain_ambience: AudioStreamPlayer
var thunder_ambience: AudioStreamPlayer
var weather_last_thunder=-1
var voices=[]
var sounds={}
var voice_index=0
var music_spare: AudioStreamPlayer
var track_streams={}
var current_track=0
var seek_count=0
var shutting_down=false
var fading_tracks=[]
var music_voices={}
var music_bus_names=[]

func _ready():
	if "--server" in OS.get_cmdline_user_args(): return
	get_tree().node_added.connect(_on_node_added)
	for bus_name in ["Music","Effects","Ambience"]:
		if AudioServer.get_bus_index(bus_name)<0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus_name)
	$Music.queue_free()
	ambience=$Ambience
	ambience.bus="Ambience"
	for index in CatanSoundtrack.TRACKS.size():track_stream(index)
	ambience.stream=_loop("sea")
	for effect in ["click","build","trade","card","turn","error","dice","win"]:
		sounds[effect]=load("res://assets/audio/%s.wav" % effect)
	for i in 8:
		var voice=AudioStreamPlayer.new()
		voice.bus="Effects"
		add_child(voice)
		voices.append(voice)
	apply(CatanSettings.new().values)
	follow_soundtrack({"track":0,"position":0.0,"paused":false,"generation":0},.016)
	ambience.play()
	rain_ambience=AudioStreamPlayer.new();rain_ambience.name="RainAmbience";rain_ambience.bus="Ambience";add_child(rain_ambience)
	rain_ambience.stream=_loop("rain");rain_ambience.volume_db=-60
	thunder_ambience=AudioStreamPlayer.new();thunder_ambience.name="ThunderAmbience";thunder_ambience.bus="Ambience";add_child(thunder_ambience)
	thunder_ambience.stream=load("res://assets/audio/thunder.wav")
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
# Buttons opt into the interface click by joining the ui_click group in their scene.
func _on_node_added(node: Node):
	if node is BaseButton and node.is_in_group(&"ui_click") and not node.pressed.is_connected(_click):
		node.pressed.connect(_click)

func _click():
	play("click")

func play(effect: String):
	if shutting_down or not sounds.has(effect) or voices.is_empty(): return
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
		if stream is AudioStreamOggVorbis:stream.loop=false
		if stream is AudioStreamWAV:stream.loop_mode=AudioStreamWAV.LOOP_DISABLED
		track_streams[index]=stream
	return track_streams[index]

func _new_music_voice(voice: Dictionary) -> Dictionary:
	var bus_name="Score_%s_%s_%s"%[get_instance_id(),voice.id,voice.track]
	AudioServer.add_bus()
	var bus=AudioServer.bus_count-1
	AudioServer.set_bus_name(bus,bus_name);AudioServer.set_bus_send(bus,"Music")
	var eq=AudioEffectEQ6.new();AudioServer.add_bus_effect(bus,eq)
	music_bus_names.append(bus_name)
	var wet_name=bus_name+"_Tempo"
	AudioServer.add_bus()
	var wet_bus=AudioServer.bus_count-1
	AudioServer.set_bus_name(wet_bus,wet_name);AudioServer.set_bus_send(wet_bus,bus_name)
	var pitch=AudioEffectPitchShift.new()
	pitch.fft_size=AudioEffectPitchShift.FFT_SIZE_1024
	AudioServer.add_bus_effect(wet_bus,pitch)
	music_bus_names.append(wet_name)
	var player=AudioStreamPlayer.new();player.bus=bus_name
	player.stream=track_stream(voice.track);player.volume_linear=0;add_child(player)
	var wet=AudioStreamPlayer.new();wet.bus=wet_name
	wet.stream=player.stream;wet.volume_linear=0;add_child(wet)
	return {"player":player,"wet":wet,"eq":eq,"pitch":pitch,"bus":bus_name,"wet_bus":wet_name,"clock":0.0,"age":0.0}

func _remove_music_voice(key: String):
	var row=music_voices[key]
	for player in [row.player,row.wet]:player.stop();player.stream=null;player.queue_free()
	for name_value in [row.wet_bus,row.bus]:
		var bus=AudioServer.get_bus_index(name_value)
		if bus>=0:AudioServer.remove_bus(bus)
		music_bus_names.erase(name_value)
	music_voices.erase(key)

func _position(player: AudioStreamPlayer,extra_latency: float=0.0) -> float:
	if player.stream_paused:return player.get_playback_position()
	return maxf(0,player.get_playback_position()+(AudioServer.get_time_since_last_mix()-AudioServer.get_output_latency()-extra_latency)*player.pitch_scale)

func audible_position() -> float:
	return _position(music) if is_instance_valid(music) else 0.0

func follow_soundtrack(sample: Dictionary,delta: float):
	if shutting_down:return
	if not sample.get("ready",true):
		for row in music_voices.values():row.player.stream_paused=true;row.wet.stream_paused=true
		return
	var desired=CatanSoundtrack.mix_voices(sample)
	var keep=[]
	fading_tracks.clear()
	for voice in desired:
		var key="%s:%s"%[voice.id,voice.track]
		keep.append(key)
		if not music_voices.has(key):music_voices[key]=_new_music_voice(voice)
		var row=music_voices[key]
		var player=row.player as AudioStreamPlayer
		var wet=row.wet as AudioStreamPlayer
		row.age+=delta
		var maximum=float(voice.bands.max())
		# The EQ receives only cuts; a single bus gain carries the common level.
		var bus=AudioServer.get_bus_index(row.bus)
		AudioServer.set_bus_volume_db(bus,CatanSoundtrack.gain_db(voice.track)+linear_to_db(maxf(.00001,maximum*minf(1,row.age/.08))))
		for band in 6:row.eq.set_band_gain_db(band,linear_to_db(maxf(.001,float(voice.bands[band])/maxf(.00001,maximum))))
		var rate=float(voice.rate)
		var latency=AudioServer.get_output_latency()
		# Pitch processing has a 768-sample FIFO. A parallel dry path fades back
		# in near natural tempo, avoiding the engine's abrupt pitch=1 bypass.
		var effect_latency=768.0/AudioServer.get_mix_rate()
		var stretch_mix=CatanSoundtrack._smooth(absf(rate-1.0)/.002)
		player.volume_linear=1.0-stretch_mix;wet.volume_linear=stretch_mix
		row.pitch.pitch_scale=1.0/rate if absf(rate-1.0)>.00002 else 1.00003
		var resuming=player.stream_paused and not voice.paused
		player.pitch_scale=rate;wet.pitch_scale=rate
		if not player.playing or resuming:
			player.play(minf(voice.position+(0.0 if voice.paused else latency*rate),CatanSoundtrack.TRACKS[voice.track].duration-.001))
			row.clock=.5
		if stretch_mix>0 and (not wet.playing or resuming):
			wet.play(minf(voice.position+(0.0 if voice.paused else (latency+effect_latency)*rate),CatanSoundtrack.TRACKS[voice.track].duration-.001))
		elif stretch_mix==0 and wet.playing:wet.stop()
		player.stream_paused=voice.paused;wet.stream_paused=voice.paused
		row.clock-=delta
		if not voice.paused and row.clock<=0:
			row.clock=.5
			var drift=float(voice.position)-_position(player)
			if absf(drift)>.18:
				player.seek(minf(voice.position+latency*rate,CatanSoundtrack.TRACKS[voice.track].duration-.001))
				if wet.playing:wet.seek(minf(voice.position+(latency+effect_latency)*rate,CatanSoundtrack.TRACKS[voice.track].duration-.001))
				seek_count+=1
		if int(voice.id)==int(sample.get("generation",0)) and int(voice.track)==int(sample.track):music=player
		else:fading_tracks.append(player)
	for key in music_voices.keys():
		if not keep.has(key):_remove_music_voice(key)
	current_track=sample.track
	music_spare=fading_tracks.back() if not fading_tracks.is_empty() else music

func follow_weather(conditions: Dictionary,delta: float):
	if shutting_down or not is_instance_valid(rain_ambience):return
	var intensity=float(conditions.get("rain",0.0))
	var volume=lerpf(rain_ambience.volume_linear,intensity*.65,1.0-exp(-delta*2.0))
	rain_ambience.volume_linear=volume
	if volume>.001 and not rain_ambience.playing:rain_ambience.play()
	elif volume<=.001 and rain_ambience.playing:rain_ambience.stop()
	var thunder=bool(conditions.get("thunder",false))
	if thunder and int(conditions.get("strike",-1))!=weather_last_thunder:
		thunder_ambience.volume_db=-5;thunder_ambience.play()
		weather_last_thunder=int(conditions.strike)

func shutdown():
	if shutting_down:return
	shutting_down=true
	for key in music_voices.keys():_remove_music_voice(key)
	for player in [ambience,rain_ambience,thunder_ambience]+voices:
		if is_instance_valid(player):player.stop();player.stream=null;player.queue_free()
	track_streams.clear();sounds.clear();voices.clear();fading_tracks.clear()

func _exit_tree():
	shutdown()
