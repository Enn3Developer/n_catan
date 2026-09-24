extends CatanDialog
## Year of plenty takes two resources from the bank; Monopoly names one to claim.

signal play_requested(action: Dictionary)

var card=2

func show_card(id: int):
	card=id
	%Title.text=tr("Year of plenty") if id==2 else tr("Monopoly")
	%Effect.text=tr("Take two resources from the bank.") if id==2 else tr("Take one resource type from every player.")
	%FirstLabel.text=tr("First resource") if id==2 else tr("Resource to claim")
	%SecondLabel.visible=id==2
	%Second.visible=id==2

func _on_play_pressed():
	var action={"type":"play_card","id":card,"resource":%First.selected}
	if card==2:
		var cards=[0,0,0,0,0]
		cards[%First.selected]+=1
		cards[%Second.selected]+=1
		action.cards=cards
	play_requested.emit(action)
