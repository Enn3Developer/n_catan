extends SceneTree
var checks=0
var failures=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func same_mix(a: Dictionary,b: Dictionary) -> bool:
	var first=CatanSoundtrack.mix_voices(a);var second=CatanSoundtrack.mix_voices(b)
	if first.size()!=second.size():return false
	for i in first.size():
		if first[i].id!=second[i].id or first[i].track!=second[i].track:return false
		if absf(first[i].position-second[i].position)>.0001:return false
		for band in 6:
			if absf(first[i].bands[band]-second[i].bands[band])>.0001:return false
	return true
func _initialize():call_deferred("run")
func run():
	for index in 5:
		check(FileAccess.get_sha256(CatanSoundtrack.TRACKS[index].file)==CatanSoundtrackAnalysis.DATA[index].sha256,"analysis matches the original recording")
	for source in 5:
		for target in 5:
			var before={"track":source,"position":11.3,"paused":false,"generation":4}
			var plan=CatanSoundtrack.switch_to(before,target)
			check(plan.blend.elapsed<=0 and plan.blend.elapsed>=-1.1,"manual switch waits at most one beat")
			var mix=CatanSoundtrack.mix_voices(plan)
			check(mix[0].position==before.position and mix[0].bands==CatanSoundtrack.FULL_BANDS,"switch preserves outgoing audio at command time")
			check(float(mix[-1].bands.max())==0,"incoming starts silently")
			var length=plan.blend.duration-plan.blend.elapsed
			for step in 21:
				var sample=CatanSoundtrack.advance(plan,length*step/20.0)
				mix=CatanSoundtrack.mix_voices(sample)
				var power_ok=true
				for band in 6:
					var power=0.0
					for voice in mix:power+=voice.bands[band]*voice.bands[band]
					power_ok=power_ok and absf(power-1)<.0001
				check(power_ok,"every frequency band preserves power throughout transition")
				check(sample.position>=plan.position and sample.position<CatanSoundtrack.playback_span(target),"incoming transport stays inside playable range")
			var midway=CatanSoundtrack.advance(plan,length*.4)
			var received=bytes_to_var(var_to_bytes(midway))
			check(same_mix(CatanSoundtrack.advance(plan,length*.7),CatanSoundtrack.advance(received,length*.3)),"late peer reconstructs identical voices and envelopes")
			var replacement=CatanSoundtrack.switch_to(midway,(target+1)%5)
			var old=CatanSoundtrack.mix_voices(midway);var continued=CatanSoundtrack.mix_voices(replacement)
			check(old.size()+1==continued.size(),"rapid switch retains every audible voice")
			for i in old.size():check(old[i].bands==continued[i].bands,"rapid switch does not reset envelope")
			midway.paused=true
			check(same_mix(midway,CatanSoundtrack.advance(midway,30)),"pause freezes complete transition")
	var initial={"track":0,"position":0.0,"paused":false,"generation":0}
	var stepped=initial
	for i in 1000:stepped=CatanSoundtrack.advance(stepped,.5)
	check(same_mix(stepped,CatanSoundtrack.advance(initial,500)),"playlist boundaries independent of polling interval")
	var rapid=initial
	var maximum=0
	for i in 80:
		rapid=CatanSoundtrack.switch_to(CatanSoundtrack.advance(rapid,.11),(i+1)%5)
		maximum=maxi(maximum,CatanSoundtrack.mix_voices(rapid).size())
	check(maximum<16,"rapid clicking keeps voice count bounded by silent-entry pruning")
	var net=CatanNetwork.new()
	net.music_anchor_ms=Time.get_ticks_msec()-120000
	var rebased=net._music_snapshot()
	check(net.music_context.get("generation",0)==rebased.generation and net.music_track==rebased.track,"host rebases automatic transitions")
	check(absf(net._music_snapshot().position-rebased.position)<.05,"rebasing preserves playback position")
	net.free()
	print("MUSIC_TRANSITION_TEST: ",checks," checks, ",failures," failures; max rapid voices=",maximum)
	quit(1 if failures else 0)
