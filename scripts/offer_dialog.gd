extends CatanDialog
## The open trade offer: what is offered, what is asked and whether you can accept.

signal accept_requested
signal withdraw_requested

func show_offer(state: Dictionary,seat: int):
	var offer: Dictionary=state.offer
	%Offerer.text=tr("%s offers:") % state.players[offer.from].name
	%Give.show_amounts(offer.give)
	%Receive.show_amounts(offer.receive)
	var own=offer.from==seat
	var rules=CatanRules.new();rules.s=state
	%Accept.visible=not own
	%Accept.disabled=not rules.can_pay(seat,offer.receive)
	%Missing.visible=not own and %Accept.disabled
	if %Missing.visible:%Missing.text=CatanI18n.render(CatanI18n.message("You need %s more to accept this offer.",[rules._missing(seat,offer.receive)]))
	%Withdraw.visible=own
