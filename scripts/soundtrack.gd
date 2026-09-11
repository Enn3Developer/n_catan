class_name CatanSoundtrack
extends RefCounted

const CROSSFADE_SECONDS=8.0
const FULL_BANDS=[1.0,1.0,1.0,1.0,1.0,1.0]

# Durations are source PCM frame counts / 44100, also verified against imports.
const TRACKS=[
	{"id":"harbor","bpm":82,"beats":4,"title":"Harbor at Dawn","mood":"Harp, flute and the first light on the harbor","file":"res://assets/audio/harbor.wav","gain_db":-2.7,"duration":46.82925170068027},
	{"id":"sunlit_fields","bpm":92,"beats":4,"title":"Sunlit Fields","mood":"Bright harp, flute and warm strings","file":"res://assets/audio/sunlit_fields.ogg","tail_seconds":3.0,"duration":86.47825396825397},
	{"id":"trade_winds","bpm":84,"beats":4,"title":"Trade Winds","mood":"Nylon strings, marimba and gentle percussion","file":"res://assets/audio/trade_winds.ogg","tail_seconds":3.0,"duration":94.42857142857143},
	{"id":"lantern_water","bpm":64,"beats":4,"title":"Lanterns on the Water","mood":"Soft piano, glass bells and evening strings","file":"res://assets/audio/lantern_water.ogg","tail_seconds":3.0,"duration":93.0},
	{"id":"voyager_waltz","bpm":86,"beats":3,"title":"Voyager's Waltz","mood":"Pizzicato strings, woodwinds and a lilting waltz","file":"res://assets/audio/voyager_waltz.ogg","tail_seconds":3.0,"duration":69.97673469387755}
]

# All planning and envelopes are pure functions of the shared transport clock.
# A late joiner reconstructs the same outgoing voices and the same EQ blend.
static func beat_seconds(index: int) -> float:
	return 60.0/TRACKS[index].bpm

static func active_end(index: int) -> float:
	return TRACKS[index].duration-float(TRACKS[index].get("tail_seconds",0.0))

static func playback_span(index: int) -> float:
	var bar=beat_seconds(index)*TRACKS[index].beats
	return round(active_end(index)/bar-2.0)*bar

static func gain_db(index: int) -> float:
	return CatanSoundtrackAnalysis.DATA[index].gain_db

static func _chroma(index: int,position: float) -> Array:
	var bars=CatanSoundtrackAnalysis.DATA[index].bars
	var bar=int(position/(beat_seconds(index)*TRACKS[index].beats))
	return bars[clampi(bar,0,bars.size()-1)].chroma

static func _cue(index: int,source: Dictionary) -> float:
	var reference=_chroma(source.track,source.position)
	var bar_seconds=beat_seconds(index)*TRACKS[index].beats
	var best=-INF
	var cue=0.0
	# These are the accompaniment-led entries in the existing arrangements.
	for bar in [0,1,8,9]:
		var position=bar*bar_seconds
		if position>playback_span(index)*.4:continue
		var candidate=_chroma(index,position)
		var score=0.0
		for i in 12:score+=candidate[i]*reference[i]
		# Prefer the beginning unless another entry is musically more compatible.
		score-=position*.001
		if score>best:best=score;cue=position
	return cue

static func _smooth(value: float) -> float:
	var x=clampf(value,0.0,1.0)
	return x*x*(3.0-2.0*x)

static func _band_progress(progress: float,band: int) -> float:
	# A short bass handoff avoids two competing pulses. Melody changes in the
	# middle while the upper texture bridges the entire transition.
	var window=Vector2(.38,.62) if band<2 else (Vector2(.22,.78) if band<4 else Vector2(0,1))
	return _smooth((progress-window.x)/(window.y-window.x))

static func _rate(blend: Dictionary) -> float:
	var t=clampf(float(blend.elapsed)/float(blend.duration),0,1)
	# Hold a matched pulse through the first half, relax to natural tempo only
	# once the old rhythm has mostly left. Pitch is compensated in the mixer.
	return lerpf(float(blend.rate),1.0,_smooth((t-.5)*2.0))

static func _distance(blend: Dictionary,elapsed: float) -> float:
	var duration=float(blend.duration)
	var t=maxf(0,elapsed)
	var halfway=duration*.5
	if t<=halfway:return t*float(blend.rate)
	var u=clampf((t-halfway)/halfway,0,1)
	var integral=u*u*u-.5*u*u*u*u
	return halfway*float(blend.rate)+(t-halfway)*float(blend.rate)+(1.0-float(blend.rate))*halfway*integral

static func mix_voices(sample: Dictionary) -> Array:
	var incoming={"id":int(sample.get("generation",0)),"track":int(sample.track),"position":float(sample.position),"rate":1.0,"bands":FULL_BANDS.duplicate(),"paused":sample.get("paused",false)}
	var blend=sample.get("blend",{})
	if blend.is_empty():return [incoming]
	var progress=clampf(float(blend.elapsed)/float(blend.duration),0,1)
	incoming.rate=_rate(blend)
	incoming.paused=incoming.paused or blend.elapsed<0
	var result=[]
	for voice in blend.from:
		if voice.position>=active_end(voice.track):continue
		var outgoing=voice.duplicate(true)
		outgoing.paused=sample.get("paused",false)
		for band in 6:outgoing.bands[band]*=cos(_band_progress(progress,band)*PI*.5)*_smooth((active_end(voice.track)-voice.position)/.25)
		result.append(outgoing)
	for band in 6:incoming.bands[band]=sin(_band_progress(progress,band)*PI*.5)
	result.append(incoming)
	return result

static func switch_to(sample: Dictionary,index: int,manual: bool=true,restart: bool=false) -> Dictionary:
	var result=sample.duplicate(true)
	var voices=mix_voices(result).filter(func(voice):return float(voice.bands.max())>.001)
	var dominant=voices[0] if not voices.is_empty() else {"track":sample.track,"position":sample.position,"rate":1.0}
	for voice in voices:
		if float(voice.bands.max())>float(dominant.get("bands",[0.0]).max()):dominant=voice
	var beat=beat_seconds(dominant.track)/dominant.rate
	var wait=0.0
	if manual and not sample.get("paused",false):
		wait=fposmod(-float(dominant.position)/float(dominant.rate),beat)
		if wait<.08:wait+=beat
	var duration=minf(CROSSFADE_SECONDS,beat*TRACKS[dominant.track].beats*2.0)
	# Never crossfade through the silence/release at the end of a recording.
	var remaining=(active_end(dominant.track)-float(dominant.position))/float(dominant.rate)-wait
	duration=maxf(.15,minf(duration,remaining))
	var cue=0.0 if restart else _cue(index,{"track":dominant.track,"position":dominant.position+wait*dominant.rate})
	var ratio=float(TRACKS[dominant.track].bpm)*float(dominant.rate)/float(TRACKS[index].bpm)
	# Large changes would smear the acoustic instruments; use the spectral
	# handoff at natural tempo instead of forcing a drastic time stretch.
	var rate=ratio if absf(ratio-1.0)<=.14 else 1.0
	result.generation=int(result.get("generation",0))+1
	result.track=index;result.position=cue
	result.blend={"elapsed":-wait,"duration":duration,"rate":rate,"from":voices}
	if sample.get("paused",false):result.erase("blend")
	return result

static func _travel(result: Dictionary,seconds: float):
	if result.has("blend"):
		var blend=result.blend
		var previous=float(blend.elapsed)
		blend.elapsed+=seconds
		result.position+=_distance(blend,blend.elapsed)-_distance(blend,previous)
		for voice in blend.from:voice.position+=seconds*voice.rate
		if blend.elapsed>=blend.duration-.000001:result.erase("blend")
	else:result.position+=seconds

static func advance(sample: Dictionary,seconds: float) -> Dictionary:
	var result=sample.duplicate(true)
	if result.get("paused",false):return result
	var remaining=maxf(0,seconds)
	while true:
		var span=playback_span(result.track)
		if result.position>=span-.000001:
			var overshoot=maxf(0,result.position-span)
			result.position=span
			result=switch_to(result,(int(result.track)+1)%TRACKS.size(),false)
			remaining+=overshoot
			span=playback_span(result.track)
		if remaining<=.000001:break
		var step=minf(remaining,span-float(result.position))
		if result.has("blend"):
			step=minf(step,float(result.blend.duration)-float(result.blend.elapsed))
			# Only needed for a manually supplied position very near a boundary.
			if _distance(result.blend,result.blend.elapsed+step)-_distance(result.blend,result.blend.elapsed)>span-result.position:
				var low=0.0;var high=step
				for i in 24:
					var mid=(low+high)*.5
					if _distance(result.blend,result.blend.elapsed+mid)-_distance(result.blend,result.blend.elapsed)>span-result.position:high=mid
					else:low=mid
				step=high
		_travel(result,step)
		remaining-=step
	return result

static func time_text(seconds: float) -> String:
	return "%d:%02d" % [int(seconds/60.0),int(seconds)%60]
