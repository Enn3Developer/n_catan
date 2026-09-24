extends HBoxContainer
## One soundtrack entry in the music library.

signal chosen

@onready var button: Button=$Track

func show_track(track: Dictionary):
	button.text=track.title
	button.tooltip_text=track.mood
	$Track/Duration.text=CatanSoundtrack.time_text(track.duration)
