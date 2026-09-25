extends CatanDialog
## Year of plenty takes two resources from the bank; Monopoly names one to claim.
## Year of plenty greys out what the bank has run out of.

signal play_requested(action: Dictionary)

var card=2
var bank=[19,19,19,19,19]

func show_card(id: int,bank_stock: Array=[19,19,19,19,19]):
	card=id
	bank=bank_stock.duplicate()
	%Title.text=tr("Year of plenty") if id==2 else tr("Monopoly")
	%Effect.text=tr("Take two resources from the bank.") if id==2 else tr("Take one resource type from every player.")
	%FirstLabel.text=tr("First resource") if id==2 else tr("Resource to claim")
	%SecondLabel.visible=id==2
	%Second.visible=id==2
	if id==2:
		var stocked=range(5).filter(func(resource):return bank[resource]>0)
		if not stocked.is_empty():
			%First.selected=stocked[0]
			%Second.selected=stocked[0] if bank[stocked[0]]>1 else stocked[mini(1,stocked.size()-1)]
		_refresh()

func _on_choice_changed(_resource: int):
	if card==2:_refresh()

func _refresh():
	var first_reasons=[]
	var second_reasons=[]
	for resource in 5:
		var empty=tr("The bank has none of that resource.")
		first_reasons.append(empty if bank[resource]<1 else "")
		# The second pick can't take the bank's last one twice.
		var left=bank[resource]-(1 if resource==%First.selected else 0)
		second_reasons.append(empty if left<1 else "")
	# The current choice stays clickable, so it can be seen.
	first_reasons[%First.selected]=""
	second_reasons[%Second.selected]=""
	%First.set_unavailable(first_reasons)
	%Second.set_unavailable(second_reasons)
	var cards=[0,0,0,0,0]
	cards[%First.selected]+=1
	cards[%Second.selected]+=1
	var short=range(5).filter(func(resource):return cards[resource]>bank[resource])
	%PlayCard.disabled=not short.is_empty()
	%Reason.text=tr("The bank has only %d %s. Choose a different resource.") % [bank[short[0]],tr(CatanRules.RES[short[0]])] if not short.is_empty() else ""
	%Reason.visible=not short.is_empty()
	%PlayCard.tooltip_text=%Reason.text

func _on_play_pressed():
	var action={"type":"play_card","id":card,"resource":%First.selected}
	if card==2:
		var cards=[0,0,0,0,0]
		cards[%First.selected]+=1
		cards[%Second.selected]+=1
		action.cards=cards
	play_requested.emit(action)
