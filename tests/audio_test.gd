extends SceneTree
var failures=0
func check(ok: bool,message: String):
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
	var player=load("res://scenes/audio.tscn").instantiate()
	root.add_child(player)
	var stream=player.music.stream
	check(stream.format==AudioStreamWAV.FORMAT_16_BITS and stream.mix_rate==44100,"original music PCM preserved")
	check(stream.loop_mode==AudioStreamWAV.LOOP_DISABLED,"score transitions instead of repeating track intro")
	stream=player.ambience.stream
	check(stream.loop_end==stream.data.size()/4,"ambience loop spans complete stereo source")
	player.ambience.play(15.85)
	await create_timer(.4).timeout
	check(player.ambience.playing and player.ambience.get_playback_position()<1,"ambience wraps cleanly")
	player.queue_free();await create_timer(.2).timeout
	await process_frame
	print("AUDIO_TEST: 4 checks, ",failures," failures")
	quit(1 if failures else 0)
