extends CatanDialog
## Asks before leaving, and says what leaving does to this game.

signal leave_requested

func show_leave(net: CatanNetwork):
	var hosting=net.multiplayer.is_server() and not net.dedicated
	if net.tutorial:%Message.text=tr("The lesson ends here. You can start it again from the main menu.")
	elif net.solo:%Message.text=tr("The game is saved. Choose Play solo, then Resume saved game, to carry on.")
	elif hosting:%Message.text=tr("The room closes for everyone. The game is saved, so you can host again and resume it.")
	else:%Message.text=tr("The others wait a minute for you, then a bot plays your seat. Use Reconnect to take it back.")
	%Message.visible=true
