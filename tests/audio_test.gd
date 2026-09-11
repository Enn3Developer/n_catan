extends SceneTree
var failures=0
func check(ok: bool,message: String):
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
	var player=load("res://scenes/audio.tscn").instantiate()
	root.add_child(player)
	for pair in [[player.music,60.0/82*64],[player.ambience,16.0]]:
		var stream=pair[0].stream
		check(stream.format==AudioStreamWAV.FORMAT_16_BITS,"lossless PCM loop")
		check(stream.mix_rate==44100,"44.1 kHz audio")
		check(absf(float(stream.loop_end)/stream.mix_rate-pair[1])<.001,"loop spans complete source")
		check(stream.loop_end==stream.data.size()/4,"loop frame count matches stereo PCM")
		pair[0].play(pair[1]-.15)
	await create_timer(.4).timeout
	check(player.music.playing and player.music.get_playback_position()<1,"music wraps cleanly")
	check(player.ambience.playing and player.ambience.get_playback_position()<1,"ambience wraps cleanly")
	player.queue_free()
	await process_frame
	print("AUDIO_TEST: 10 checks, ",failures," failures")
	quit(1 if failures else 0)
