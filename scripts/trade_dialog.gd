extends CatanDialog
## One offer to every other player, of any mix of resources, or a bank trade at
## the best port rate. Players answer the offer and the offering player picks a
## partner in the offer dialog.

signal trade_requested(action: Dictionary)
## The draft outlives the dialog, which is rebuilt with every new snapshot.
signal draft_changed(draft: Dictionary)

## Most of one resource an offer can ask for.
const MOST_ASKED=9
var state: Dictionary
var seat=-1
var rules=CatanRules.new()
var ready_to_draft=false

func show_trade(snapshot: Dictionary,player: int,draft: Dictionary):
	state=snapshot
	seat=player
	rules.s=state
	var paired=state.get("paired",false)
	var hand: Array=state.players[seat].hand
	%PlayersTab.disabled=paired
	%PlayersTab.tooltip_text=tr("Unavailable during a paired turn") if paired else tr("Offer a trade to the other players")
	%PlayersTab.button_pressed=draft.get("players",true) and not paired
	%BankTab.button_pressed=not %PlayersTab.button_pressed
	var have=[]
	for resource in 5:have.append(tr("have %d") % hand[resource])
	%Give.set_limits(hand)
	%Give.set_notes(have)
	%Give.set_values(draft.get("give",[0,0,0,0,0]))
	%Get.set_limits([MOST_ASKED,MOST_ASKED,MOST_ASKED,MOST_ASKED,MOST_ASKED])
	%Get.set_notes(have)
	%Get.set_values(draft.get("receive",[0,0,0,0,0]))
	var captions=[]
	for resource in 5:captions.append("%s\n%d:1" % [tr(CatanRules.RES[resource]),rules.rate(seat,resource)])
	%BankGive.set_captions(captions)
	# Without a draft, start from a resource the bank trade can take.
	var affordable=range(5).filter(func(resource):return hand[resource]>=rules.rate(seat,resource))
	%BankGive.selected=int(draft.get("bank_give",affordable[0] if not affordable.is_empty() else 0))
	%BankGet.selected=int(draft.get("bank_receive",1))
	ready_to_draft=true
	_refresh()

func _on_bank_choice(_resource: int):
	_refresh()

func _refresh():
	if not ready_to_draft:return
	var banking: bool=%BankTab.button_pressed
	%PlayersPage.visible=not banking
	%BankPage.visible=banking
	%BankTrade.visible=banking
	%OfferTrade.visible=not banking
	if banking:_refresh_bank()
	else:_refresh_offer()
	draft_changed.emit({"players":not banking,"give":%Give.values.duplicate(),"receive":%Get.values.duplicate(),"bank_give":%BankGive.selected,"bank_receive":%BankGet.selected})

func _refresh_offer():
	var give: Array=%Give.values
	var receive: Array=%Get.values
	# A resource sits on one side of the offer only.
	var give_locked=[]
	var get_locked=[]
	for resource in 5:
		give_locked.append(receive[resource]>0)
		get_locked.append(give[resource]>0)
	%Give.set_locked(give_locked)
	%Get.set_locked(get_locked)
	var complete=%Give.total()>0 and %Get.total()>0
	%OfferTrade.disabled=not complete or state.get("paired",false)
	%Preview.text=tr("%s for %s") % [_amounts(give),_amounts(receive)] if complete else ""
	%Preview.visible=complete
	%Reason.text=tr("Other players answer first, then you choose who to trade with.") if complete else tr("Choose what you give and what you want in return.")

func _refresh_bank():
	var hand: Array=state.players[seat].hand
	var give: int=%BankGive.selected
	if %BankGet.selected==give:%BankGet.selected=(give+1)%5
	var receive: int=%BankGet.selected
	var give_reasons=[]
	var get_reasons=[]
	for resource in 5:
		var rate=rules.rate(seat,resource)
		give_reasons.append(tr("You need %d more %s.") % [rate-hand[resource],tr(CatanRules.RES[resource])] if hand[resource]<rate else "")
		get_reasons.append(tr("The bank has none of that resource.") if state.bank[resource]<1 else tr("Choose different resources.") if resource==give else "")
	# Tiles stay clickable when they are the current choice, so the choice can be seen.
	give_reasons[give]=""
	get_reasons[receive]=""
	%BankGive.set_unavailable(give_reasons)
	%BankGet.set_unavailable(get_reasons)
	var rate=rules.rate(seat,give)
	var trade=[0,0,0,0,0]
	trade[give]=rate
	var wanted=[0,0,0,0,0]
	wanted[receive]=1
	%Preview.text=tr("%s for %s") % [_amounts(trade),_amounts(wanted)]
	%Preview.visible=true
	var affordable=hand[give]>=rate
	%BankTrade.disabled=not affordable or state.bank[receive]<1
	%Reason.text=tr("You need %d more %s.") % [rate-hand[give],tr(CatanRules.RES[give])] if not affordable else tr("The bank has none of that resource.") if state.bank[receive]<1 else tr("Your best port rate: %d:1 · Bank stock: %d") % [rate,state.bank[receive]]

## "2 Wool and 1 Ore": the amounts in words, for the summary line.
func _amounts(amounts: Array) -> String:
	var parts=[]
	for resource in 5:
		if amounts[resource]>0:parts.append("%d %s" % [amounts[resource],tr(CatanRules.RES[resource])])
	if parts.size()<2:return "".join(parts)
	return tr("%s and %s") % [", ".join(parts.slice(0,-1)),parts[-1]]

func _on_bank_trade_pressed():
	trade_requested.emit({"type":"bank_trade","give":%BankGive.selected,"receive":%BankGet.selected})

func _on_offer_trade_pressed():
	trade_requested.emit({"type":"offer_trade","give":%Give.values.duplicate(),"receive":%Get.values.duplicate()})
