extends CatanDialog
## Asks before leaving; online players are told what leaving does to the room.

signal leave_requested

func show_leave(solo: bool):
	%Message.text=tr("Leave this solo expedition?") if solo else tr("Leaving pauses this match for the other players.\nIf you host, the room will close.")
