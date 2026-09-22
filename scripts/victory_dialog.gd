extends CatanDialog
## Announces the winner; the only way on is back to the menu.

signal leave_requested

func show_winner(winner_name: String):
	%Winner.text=tr("%s wins!") % winner_name
