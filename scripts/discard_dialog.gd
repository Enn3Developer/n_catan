extends CatanDialog
## Choose which resources to return to the bank after a seven.

signal discard_requested(cards: Array)

@onready var amounts: Array[SpinBox]=[%TimberAmount,%BrickAmount,%WoolAmount,%GrainAmount,%OreAmount]

func _ready():
	for spin in amounts:style_amount(spin)

func show_discard(needed: int,hand: Array):
	%Instructions.text=tr("Return exactly %d resources to the bank.") % needed
	for resource in 5:amounts[resource].max_value=hand[resource]

func _on_discard_pressed():
	var cards=[]
	for spin in amounts:cards.append(int(spin.value))
	discard_requested.emit(cards)
