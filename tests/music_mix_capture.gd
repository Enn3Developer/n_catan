extends SceneTree
var sample={"track":0,"position":13.0,"paused":false,"generation":0}
var player
var elapsed=0.0
var stage=0
var recording: AudioEffectRecord
var output="/tmp/catan-music-mix.wav"
var automatic=false
var finishing=false
func _initialize():call_deferred("run")
func run():
	Engine.max_fps=60
	var args=OS.get_cmdline_user_args()
	if not args.is_empty():output=args[0]
	automatic="--automatic" in args
	if automatic:sample={"track":4,"position":CatanSoundtrack.playback_span(4)-3.0,"paused":false,"generation":0}
	player=load("res://scenes/audio.tscn").instantiate();root.add_child(player)
	var values=CatanSettings.DEFAULTS.duplicate();values.master=1.0;values.music=1.0;values.ambience=0;player.apply(values)
	recording=AudioEffectRecord.new();recording.format=AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Music"),recording)
	recording.set_recording_active(true)
func _process(delta):
	if player==null or finishing:return false
	elapsed+=delta
	sample=CatanSoundtrack.advance(sample,delta)
	if not automatic and stage<3 and elapsed>3+stage*9:
		sample=CatanSoundtrack.switch_to(sample,stage+1);stage+=1
	player.follow_soundtrack(sample,delta)
	if elapsed>(12 if automatic else 31):
		finishing=true;finish.call_deferred()
	return false
func finish():
	recording.set_recording_active(false)
	var wav=recording.get_recording()
	var err=wav.save_to_wav(output)
	print("MUSIC_MIX_CAPTURE: ",output," frames=",wav.data.size()/4," result=",err)
	player.queue_free();await create_timer(.2).timeout;quit(0 if err==OK else 1)
