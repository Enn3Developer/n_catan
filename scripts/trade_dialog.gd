extends CatanDialog
## Bank trades at the best port rate, or one offer to every other player.

signal trade_requested(action: Dictionary)
## The draft outlives the dialog, which is rebuilt with every new snapshot.
signal draft_changed(with_players: bool,give: int,receive: int)

@onready var selected_give: OptionButton=%GivePicker
@onready var selected_get: OptionButton=%ReceivePicker
@onready var amount_give: SpinBox=%GiveAmount
@onready var amount_get: SpinBox=%ReceiveAmount
@onready var give_choices: Array[Node]=%GiveChoices.get_children()
@onready var get_choices: Array[Node]=%ReceiveChoices.get_children()
var state: Dictionary
var seat=-1
var rules=CatanRules.new()

func _ready():
	style_amount(amount_give)
	style_amount(amount_get)
	for resource in 5:
		give_choices[resource].pressed.connect(_choose.bind(selected_give,resource))
		get_choices[resource].pressed.connect(_choose.bind(selected_get,resource))

func show_trade(snapshot: Dictionary,player: int,with_players: bool,give: int,receive: int):
	state=snapshot
	seat=player
	rules.s=state
	var paired=state.get("paired",false)
	var hand: Array=state.players[seat].hand
	%Hand.show_amounts(hand)
	%BankTab.button_pressed=not with_players or paired
	%PlayersTab.disabled=paired
	%PlayersTab.button_pressed=with_players and not paired
	%PlayersTab.tooltip_text=tr("Unavailable during a paired turn") if paired else tr("Offer a trade to the other players")
	selected_give.select(give)
	selected_get.select(receive)
	for resource in 5:give_choices[resource].text=str(hand[resource])
	_refresh()

func _refresh():
	var banking: bool=%BankTab.button_pressed
	var give=selected_give.selected
	var receive=selected_get.selected
	var hand: Array=state.players[seat].hand
	draft_changed.emit(not banking,give,receive)
	for resource in 5:
		give_choices[resource].set_pressed_no_signal(resource==give)
		get_choices[resource].set_pressed_no_signal(resource==receive)
		give_choices[resource].tooltip_text=tr("%s · You have %d · Bank rate %d:1") % [tr(CatanRules.RES[resource]),hand[resource],rules.rate(seat,resource)]
		get_choices[resource].tooltip_text=tr("%s · Bank has %d") % [tr(CatanRules.RES[resource]),state.bank[resource]]
	%BankTrade.visible=banking
	%OfferTrade.visible=not banking
	amount_give.editable=not banking
	amount_get.editable=not banking
	if banking:
		amount_give.set_value_no_signal(rules.rate(seat,give))
		amount_get.set_value_no_signal(1)
		%BankTrade.text=tr("Bank trade · %d:1") % rules.rate(seat,give)
	var available=hand[give]>=int(amount_give.value)
	var different=give!=receive
	%BankTrade.disabled=not available or not different or state.bank[receive]<1
	%OfferTrade.disabled=not available or not different or state.get("paired",false)
	%Preview.text="%d %s → %d %s" % [int(amount_give.value),tr(CatanRules.RES[give]),int(amount_get.value),tr(CatanRules.RES[receive])]
	%Reason.text=tr("Choose different resources.") if not different else (tr("You need %d more %s.") % [int(amount_give.value)-hand[give],tr(CatanRules.RES[give])] if not available else (tr("The bank has none of that resource.") if banking and state.bank[receive]==0 else (tr("Your best port rate: %d:1 · Bank stock: %d") % [rules.rate(seat,give),state.bank[receive]] if banking else tr("Any player who can afford this offer may accept it."))))

func _choose(picker: OptionButton,resource: int):
	picker.select(resource)
	picker.item_selected.emit(resource)

func _on_selection_changed(_value):
	_refresh()

func _on_players_tab_pressed():
	amount_give.set_value_no_signal(1)
	amount_get.set_value_no_signal(1)
	_refresh()

func _on_bank_trade_pressed():
	trade_requested.emit({"type":"bank_trade","give":selected_give.selected,"receive":selected_get.selected})

func _on_offer_trade_pressed():
	var give=[0,0,0,0,0]
	var receive=[0,0,0,0,0]
	give[selected_give.selected]=int(amount_give.value)
	receive[selected_get.selected]=int(amount_get.value)
	trade_requested.emit({"type":"offer_trade","give":give,"receive":receive})
