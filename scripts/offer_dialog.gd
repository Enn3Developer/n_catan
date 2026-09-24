extends CatanDialog
## The open trade offer. Other players accept, decline or counter; the offering
## player then picks one partner from everyone who said yes.

signal response_requested(action: Dictionary)
signal withdraw_requested

const RESOURCE_ROW=preload("res://scenes/ui/resource_row.tscn")
const ANSWERED_COLOR=Color("8c522d")
const WAITING_COLOR=Color("796347")
var state: Dictionary
var seat=-1
var offer_id=-1

func _ready():
	style_amount(%CounterGiveAmount)
	style_amount(%CounterGetAmount)

func show_offer(snapshot: Dictionary,player: int,net: CatanNetwork):
	state=snapshot
	seat=player
	var offer: Dictionary=state.offer
	var own=int(offer.from)==seat
	var rules=CatanRules.new();rules.s=state
	var responses: Dictionary=offer.get("responses",{})
	var mine: Dictionary=responses.get(str(seat),{})
	var waiting: bool=offer.get("waiting",false)
	%Offerer.text=tr("You offer:") if own else tr("%s offers:") % state.players[offer.from].name
	%Give.show_amounts(offer.give)
	%Receive.show_amounts(offer.receive)
	if int(offer.get("id",0))!=offer_id:
		offer_id=int(offer.get("id",0))
		_prefill_counter(offer)
	var accepted=responses.values().filter(func(answer):return answer.answer in ["accept","counter"]).size()
	if own:
		%Status.text=tr("Waiting for answers…") if waiting else tr("Choose who to trade with.") if accepted>0 else tr("Nobody has accepted yet.") if responses.size()<state.players.size()-1 else tr("Everyone declined. Withdraw the offer to make a new one.")
	else:
		%Status.text={"accept":tr("You accepted. %s picks a partner."),"counter":tr("You sent a counter-offer. %s picks a partner."),"decline":tr("You declined. You can still change your answer.")}.get(mine.get("answer",""),tr("Accept, decline or propose a counter-offer."))
		if "%s" in %Status.text:%Status.text=%Status.text % state.players[offer.from].name
	for child in %Responses.get_children():child.free()
	for p in state.players.size():
		if p!=int(offer.from):_add_response(p,responses.get(str(p),{}),own and not waiting,rules,net.player_color(p))
	%Answers.visible=not own
	%Accept.disabled=not rules.can_pay(seat,offer.receive) or mine.get("answer","")=="accept"
	%Decline.disabled=mine.get("answer","")=="decline"
	%Missing.visible=not own and not rules.can_pay(seat,offer.receive)
	if %Missing.visible:%Missing.text=CatanI18n.render(CatanI18n.message("You need %s more to accept this offer.",[rules._missing(seat,offer.receive)]))
	%CounterPanel.visible=not own and %Counter.button_pressed
	%Withdraw.visible=own
	_refresh_counter()

func _add_response(p: int,response: Dictionary,can_pick: bool,rules: CatanRules,color: Color):
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	var accent=ColorRect.new()
	accent.custom_minimum_size=Vector2(4,30)
	accent.color=color
	row.add_child(accent)
	var name_label=Label.new()
	name_label.text=state.players[p].name
	name_label.custom_minimum_size.x=96
	name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.auto_translate_mode=Node.AUTO_TRANSLATE_MODE_DISABLED
	row.add_child(name_label)
	var answer=str(response.get("answer",""))
	var status=Label.new()
	status.text={"accept":tr("Accepts"),"decline":tr("Declines"),"counter":tr("Counters:")}.get(answer,tr("Thinking…"))
	status.add_theme_color_override("font_color",ANSWERED_COLOR if not answer.is_empty() else WAITING_COLOR)
	status.add_theme_font_size_override("font_size",15)
	row.add_child(status)
	var give: Array=response.get("give",[])
	var receive: Array=response.get("receive",[])
	if answer=="counter":
		# From the counter's author: what they hand over, then what they want.
		for part in [[receive,""],[give,tr("for")]]:
			if not part[1].is_empty():
				var joiner=Label.new();joiner.text=part[1];row.add_child(joiner)
			var amounts=RESOURCE_ROW.instantiate()
			amounts.icon_size=18
			row.add_child(amounts)
			amounts.show_amounts(part[0])
	var spacer=Control.new()
	spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	if can_pick and answer in ["accept","counter"]:
		var terms_give: Array=give if answer=="counter" else state.offer.give
		var terms_receive: Array=receive if answer=="counter" else state.offer.receive
		var pick=Button.new()
		pick.text=tr("Trade")
		pick.custom_minimum_size=Vector2(0,34)
		pick.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		pick.theme_type_variation=&"PrimaryButton"
		pick.add_to_group("ui_click")
		pick.disabled=not rules.can_pay(seat,terms_give)
		if pick.disabled:pick.tooltip_text=CatanI18n.render(CatanI18n.message("You need %s more to make this offer.",[rules._missing(seat,terms_give)]))
		elif state.players[p].get("resource_count",99)<rules.total(terms_receive):pick.disabled=true
		pick.pressed.connect(func():response_requested.emit({"type":"confirm_trade","id":p}))
		row.add_child(pick)
	%Responses.add_child(row)

func _answer(action_type: String):
	response_requested.emit({"type":action_type})

## A counter starts from the offer seen from this side of the table.
func _prefill_counter(offer: Dictionary):
	for side in [[%CounterGive,%CounterGiveAmount,offer.receive],[%CounterGet,%CounterGetAmount,offer.give]]:
		for r in 5:
			if side[2][r]>0:
				side[0].select(r)
				side[1].set_value_no_signal(side[2][r])
				break

func _on_counter_toggled(_pressed: bool):
	%CounterPanel.visible=%Counter.button_pressed
	_refresh_counter()

func _on_counter_changed(_value):
	_refresh_counter()

func _refresh_counter():
	if state.is_empty() or not %CounterPanel.visible:return
	var give=%CounterGive.selected
	var get_resource=%CounterGet.selected
	var hand: Array=state.players[seat].hand
	var different=give!=get_resource
	var affordable=hand[give]>=int(%CounterGiveAmount.value)
	%SendCounter.disabled=not different or not affordable
	%CounterReason.text=tr("Choose different resources.") if not different else tr("You need %d more %s.") % [int(%CounterGiveAmount.value)-hand[give],tr(CatanRules.RES[give])] if not affordable else tr("%s can take your counter instead of the original offer.") % state.players[state.offer.from].name

func _on_send_counter_pressed():
	# Counters keep the offer's orientation: "give" is what the offering player hands over.
	var give=[0,0,0,0,0]
	var receive=[0,0,0,0,0]
	give[%CounterGet.selected]=int(%CounterGetAmount.value)
	receive[%CounterGive.selected]=int(%CounterGiveAmount.value)
	response_requested.emit({"type":"counter_trade","give":give,"receive":receive})
	%Counter.button_pressed=false
