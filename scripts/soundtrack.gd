class_name CatanSoundtrack
extends RefCounted

# Durations are source PCM frame counts / 44100, also verified against imports.
const TRACKS=[
	{"id":"harbor","title":"Harbor at Dawn","mood":"Harp, flute and the first light on the harbor","file":"res://assets/audio/harbor.wav","gain_db":-2.7,"duration":46.82925170068027},
	{"id":"sunlit_fields","title":"Sunlit Fields","mood":"Bright harp, flute and warm strings","file":"res://assets/audio/sunlit_fields.ogg","duration":86.47825396825397},
	{"id":"trade_winds","title":"Trade Winds","mood":"Nylon strings, marimba and gentle percussion","file":"res://assets/audio/trade_winds.ogg","duration":94.42857142857143},
	{"id":"lantern_water","title":"Lanterns on the Water","mood":"Soft piano, glass bells and evening strings","file":"res://assets/audio/lantern_water.ogg","duration":93.0},
	{"id":"voyager_waltz","title":"Voyager's Waltz","mood":"Pizzicato strings, woodwinds and a lilting waltz","file":"res://assets/audio/voyager_waltz.ogg","duration":69.97673469387755}
]

static func advance(sample: Dictionary,seconds: float) -> Dictionary:
	var result=sample.duplicate()
	if not result.get("paused",false):result.position+=maxf(0,seconds)
	# Extrapolation crosses track boundaries even between network samples.
	while result.position>=TRACKS[result.track].duration:
		result.position-=TRACKS[result.track].duration
		result.track=(int(result.track)+1)%TRACKS.size()
	return result

static func time_text(seconds: float) -> String:
	return "%d:%02d" % [int(seconds/60.0),int(seconds)%60]
