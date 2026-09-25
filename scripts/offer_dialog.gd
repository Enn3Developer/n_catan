extends CatanDialog
## The open trade offer, shown from the viewer's side of the table. Other
## players accept, decline or counter; the offering player then picks one
## partner from everyone who said yes. Countering is a step of its own: the
## offer shrinks to one line, the terms become steppers and the footer holds
## only Back and Send.

signal response_requested(action: Dictionary)
signal withdraw_requested

const RESOURCE_ROW=preload("res://scenes/ui/resource_row.tscn")
var state: Dictionary
var seat=-1
var offer_id=-1
var network: CatanNetwork
## Whether the viewer is writing a counter-offer.
var countering=false

func show_offer(snapshot: Dictionary,player: int,net: CatanNetwork):
	state=snapshot
	seat=player
	network=net
	var offer: Dictionary=state.offer
	var own=int(offer.from)==seat
	if own:countering=false
	var rules=CatanRules.new();rules.s=state
	var responses: Dictionary=offer.get("responses",{})
	var mine: Dictionary=responses.get(str(seat),{})
	var waiting: bool=offer.get("waiting",false)
	var offerer: String=state.players[offer.from].name
	%Title.text=tr("Counter-offer") if countering else tr("A trade on the table")
	%Offerer.text=tr("Your offer to the other players.") if own else tr("%s offers %s for %s. Change the terms and send them back.") % [offerer,_amounts(offer.give),_amounts(offer.receive)] if countering else tr("%s offers you a trade.") % offerer
	%Terms.visible=not countering
	# "give" is always what the offering player hands over.
	%YouGive.show_amounts(offer.give if own else offer.receive)
	%YouGet.show_amounts(offer.receive if own else offer.give)
	var hand: Array=state.players[seat].hand
	if int(offer.get("id",0))!=offer_id:
		# A new offer starts over, even in the middle of a counter.
		countering=false
		%Title.text=tr("A trade on the table")
		%Offerer.text=tr("Your offer to the other players.") if own else tr("%s offers you a trade.") % offerer
		%Terms.visible=true
		offer_id=int(offer.get("id",0))
		var have=[]
		for resource in 5:have.append(tr("have %d") % hand[resource])
		%CounterGive.set_limits(hand)
		%CounterGive.set_notes(have)
		%CounterGet.set_limits([9,9,9,9,9])
		%CounterGet.set_notes(have)
		# A counter starts from the offer as seen from this side of the table.
		%CounterGive.set_values(offer.receive)
		%CounterGet.set_values(offer.give)
	var accepted=responses.values().filter(func(answer):return answer.answer in ["accept","counter"]).size()
	if own:
		%Status.text=tr("Waiting for answers…") if waiting else tr("Everyone declined. Withdraw the offer to make a new one.") if accepted==0 and responses.size()>=state.players.size()-1 else tr("Choose who to trade with.") if accepted>0 else ""
	else:
		%Status.text=tr("You accepted. %s picks who to trade with.") % offerer if mine.get("answer","")=="accept" else tr("You sent a counter-offer. %s picks who to trade with.") % offerer if mine.get("answer","")=="counter" else ""
	%Status.visible=not %Status.text.is_empty() and not countering
	for child in %Responses.get_children():child.free()
	for p in state.players.size():
		if p!=int(offer.from):_add_response(p,responses.get(str(p),{}),own and not waiting,rules,net.player_color(p))
	%Answers.visible=not own and not countering
	%CounterSteps.visible=countering
	%Close.visible=not countering
	%Accept.disabled=not rules.can_pay(seat,offer.receive) or mine.get("answer","")=="accept"
	%Decline.disabled=mine.get("answer","")=="decline"
	# The steppers still hold a counter already sent, so the button offers to change it.
	%Counter.text=tr("Edit counter…") if mine.get("answer","")=="counter" else tr("Counter…")
	%Missing.visible=not own and not countering and not rules.can_pay(seat,offer.receive)
	if %Missing.visible:%Missing.text=CatanI18n.render(CatanI18n.message("You need %s more to accept this offer.",[rules._missing(seat,offer.receive)]))
	%CounterPanel.visible=countering
	%AnswersLabel.visible=not countering
	%Responses.visible=not countering
	%Withdraw.visible=own
	_refresh_counter()

func _add_response(p: int,response: Dictionary,can_pick: bool,rules: CatanRules,color: Color):
	var card=PanelContainer.new()
	card.theme_type_variation=&"PlainRow"
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	card.add_child(row)
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
	status.text={"accept":tr("Accepts"),"decline":tr("Declines"),"counter":tr("Counters")}.get(answer,tr("Thinking…"))
	status.theme_type_variation=&"MutedLabel" if answer in ["","decline"] else &"SectionLabel"
	row.add_child(status)
	var give: Array=response.get("give",[])
	var receive: Array=response.get("receive",[])
	if answer=="counter":
		# From the counter's author: what they hand over, then what they want.
		for part in [[tr("gives"),receive],[tr("wants"),give]]:
			var joiner=Label.new()
			joiner.text=part[0]
			joiner.theme_type_variation=&"MutedLabel"
			row.add_child(joiner)
			var amounts=RESOURCE_ROW.instantiate()
			amounts.icon_size=18
			row.add_child(amounts)
			amounts.show_amounts(part[1])
	var spacer=Control.new()
	spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	if can_pick and answer in ["accept","counter"]:
		var terms_give: Array=give if answer=="counter" else state.offer.give
		var terms_receive: Array=receive if answer=="counter" else state.offer.receive
		var pick=Button.new()
		pick.text=tr("Trade")
		pick.custom_minimum_size=Vector2(80,34)
		pick.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		pick.theme_type_variation=&"PrimaryButton"
		pick.add_to_group("ui_click")
		pick.disabled=not rules.can_pay(seat,terms_give)
		if pick.disabled:pick.tooltip_text=CatanI18n.render(CatanI18n.message("You need %s more to make this offer.",[rules._missing(seat,terms_give)]))
		elif state.players[p].get("resource_count",99)<rules.total(terms_receive):pick.disabled=true
		pick.pressed.connect(func():response_requested.emit({"type":"confirm_trade","id":p}))
		row.add_child(pick)
	%Responses.add_child(card)

func _answer(action_type: String):
	response_requested.emit({"type":action_type})

## Switches between answering the offer and writing a counter-offer.
func _set_countering(on: bool):
	countering=on
	if not state.is_empty():show_offer(state,seat,network)
	fit()

## "2 Wool and 1 Ore": the amounts in words.
func _amounts(amounts: Array) -> String:
	var parts=[]
	for resource in 5:
		if amounts[resource]>0:parts.append("%d %s" % [amounts[resource],tr(CatanRules.RES[resource])])
	if parts.size()<2:return "".join(parts)
	return tr("%s and %s") % [", ".join(parts.slice(0,-1)),parts[-1]]

func _refresh_counter():
	if state.is_empty() or not %CounterPanel.visible:return
	var give: Array=%CounterGive.values
	var receive: Array=%CounterGet.values
	var give_locked=[]
	var get_locked=[]
	for resource in 5:
		give_locked.append(receive[resource]>0)
		get_locked.append(give[resource]>0)
	%CounterGive.set_locked(give_locked)
	%CounterGet.set_locked(get_locked)
	var complete=%CounterGive.total()>0 and %CounterGet.total()>0
	var same=give==state.offer.receive and receive==state.offer.give
	%SendCounter.disabled=not complete or same
	%CounterPreview.text=tr("You give %s and get %s.") % [_amounts(give),_amounts(receive)] if complete else ""
	%CounterPreview.visible=complete
	%CounterReason.text=tr("Choose what you give and what you want in return.") if not complete else tr("These are the offer's terms. Change something, or go back and accept.") if same else ""
	%CounterReason.visible=not %CounterReason.text.is_empty()

func _on_send_counter_pressed():
	# Counters keep the offer's orientation: "give" is what the offering player hands over.
	response_requested.emit({"type":"counter_trade","give":%CounterGet.values.duplicate(),"receive":%CounterGive.values.duplicate()})
	_set_countering(false)
