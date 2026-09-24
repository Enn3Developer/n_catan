extends CatanDialog
## Choose which resources to return to the bank after a seven.

signal discard_requested(cards: Array)

var needed=0

func show_discard(count: int,hand: Array):
	needed=count
	%Instructions.text=tr("Return exactly %d resources to the bank.") % needed
	%Steppers.set_limits(hand)
	_on_amount_changed()

func _on_amount_changed():
	var total=%Steppers.total()
	%Chosen.text=tr("%d of %d chosen") % [total,needed]
	%DiscardSelected.disabled=total!=needed

func _on_discard_pressed():
	discard_requested.emit(%Steppers.values.duplicate())
