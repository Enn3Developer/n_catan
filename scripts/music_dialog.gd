extends CatanDialog
## The shared soundtrack: what is playing, the room's transport controls and
## each player's own volume.

signal control_requested(operation: String,track: int)
signal volume_changed(value: float)
signal mute_toggled

const TRACK_ROW=preload("res://scenes/ui/music_track_row.tscn")

@onready var now_playing: Label=%NowPlaying
@onready var toggle: Button=%Toggle
@onready var volume: HSlider=%Volume
var tracks: Array[Button]=[]

func _ready():
	for i in CatanSoundtrack.TRACKS.size():
		var row=TRACK_ROW.instantiate()
		row.name="MusicTrack%d" % i
		%Tracks.add_child(row)
		row.show_track(CatanSoundtrack.TRACKS[i])
		row.chosen.connect(control_requested.emit.bind("select",i))
		tracks.append(row.button)

func refresh(sample: Dictionary,can_control: bool,shared: bool,music_volume: float):
	var track: Dictionary=CatanSoundtrack.TRACKS[int(sample.track)]
	var playback_ready=sample.get("ready",true)
	var controller=can_control and playback_ready
	now_playing.text=(tr("Paused · ") if sample.paused else "")+tr(track.title) if playback_ready else tr("Joining room soundtrack…")
	now_playing.tooltip_text=tr(track.title)+" · "+tr(track.mood)
	%Description.text=track.mood
	%Progress.max_value=track.duration
	%Progress.value=sample.position
	%Clock.text=CatanSoundtrack.time_text(sample.position)+" / "+CatanSoundtrack.time_text(track.duration)
	for button: Button in [%Previous,toggle,%Next]:button.disabled=not controller
	toggle.icon=CatanIcons.get_icon("play" if sample.paused else "pause")
	toggle.tooltip_text=(tr("Resume soundtrack") if sample.paused else tr("Pause soundtrack")) if controller else tr("The host controls room playback")
	volume.set_value_no_signal(music_volume)
	%Mute.icon=CatanIcons.get_icon("muted" if music_volume<=0 else "volume")
	%Mute.tooltip_text=tr("Unmute music for you") if music_volume<=0 else tr("Mute music for you")
	%Status.text=tr("Shared with the room · ")+(tr("You control playback. Everyone keeps their own volume.") if controller else tr("The host controls playback. Your volume is personal.")) if shared else tr("Your soundtrack · choose a track or let the playlist continue.")
	for i in tracks.size():
		tracks[i].set_pressed_no_signal(i==int(sample.track))
		tracks[i].disabled=not controller

func _on_volume_value_changed(value: float):
	volume_changed.emit(value)
