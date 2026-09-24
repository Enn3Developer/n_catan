extends CatanDialog
## Choose which resources to return to the bank after a seven.

signal discard_requested(cards: Array)

@onready var amounts: Array[SpinBox]=[%TimberAmount,%BrickAmount,%WoolAmount,%GrainAmount,%OreAmount]
var needed=0

func _ready():
	for spin in amounts:style_amount(spin)

func show_discard(count: int,hand: Array):
	needed=count
	%Instructions.text=tr("Return exactly %d resources to the bank.") % needed
	for resource in 5:
		amounts[resource].max_value=hand[resource]
		amounts[resource].get_parent().get_child(2).text=tr("of %d") % hand[resource]
	_on_amount_changed(0)

func _chosen() -> int:
	var total=0
	for spin in amounts:total+=int(spin.value)
	return total

func _on_amount_changed(_value: float):
	var total=_chosen()
	%Chosen.text=tr("%d of %d chosen") % [total,needed]
	%DiscardSelected.disabled=total!=needed

func _on_discard_pressed():
	var cards=[]
	for spin in amounts:cards.append(int(spin.value))
	discard_requested.emit(cards)
