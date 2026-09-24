extends CatanDialog
## Asks before leaving; online players are told what leaving does to the room.

signal leave_requested

func show_leave(solo: bool):
	%Message.visible=not solo
	%Message.text=tr("Leaving pauses this match for the other players.\nIf you host, the room will close.")
