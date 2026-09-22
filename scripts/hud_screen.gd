extends CatanScreen
## In-game HUD: player tallies, the turn clock and tools along the top, the hand
## and turn actions along the bottom, and development cards on the right.
## Buttons only report intent; main.gd acts on it.

signal action_requested(action: Dictionary)
signal build_requested(kind: String)
signal trade_requested
signal discard_requested
signal offer_requested
signal resource_card_requested(card: int)
signal inspect_requested
signal log_requested
signal guide_requested
signal music_requested
signal settings_requested
signal leave_requested

const PLAYER_CHIP=preload("res://scenes/ui/player_chip.tscn")
const DEV_CARD=preload("res://scenes/ui/dev_card.tscn")
const CLOCK_COLOR=Color("796347")
const CLOCK_URGENT_COLOR=Color("a8322a")
const PIECE_LIMITS={"road":15,"settlement":5,"city":4}

func show_game(net: CatanNetwork,state: Dictionary,mode: String):
	var seat=net.seat
	for i in state.players.size():
		var chip=PLAYER_CHIP.instantiate()
		chip.name="PlayerChip%d" % i
		%PlayersBody.add_child(chip)
		chip.show_player(state,i,seat,net.player_color(i))
	var hand: Array=state.players[seat].hand
	var mine=state.turn==seat and state.winner==-1
	var play=mine and state.phase=="play"
	%RollDice.text=tr("Roll") if state.dice[0]==0 else "%d + %d" % state.dice
	%RollDice.tooltip_text=tr("Roll dice") if state.dice[0]==0 else tr("Last roll: %d") % (state.dice[0]+state.dice[1])
	%RollDice.disabled=not play or state.rolled
	var rules=CatanRules.new();rules.s=state
	for kind in ["road","settlement","city"]:
		var button: Button=get_node("%"+kind.capitalize()+"Action")
		_show_cost(button,CatanRules.COST[kind],hand)
		button.set_pressed_no_signal(mode==kind)
		var sites=rules.build_sites(seat,kind)
		button.disabled=not play or not state.rolled or not rules.can_pay(seat,CatanRules.COST[kind]) or sites.is_empty()
		if rules.pieces(seat,kind)>=PIECE_LIMITS[kind]:
			button.unavailable_reason=tr({"road":"All 15 of your roads are on the board. You have none left to place.","settlement":"All 5 of your settlements are on the board. Upgrade one to a city to free a settlement piece.","city":"All 4 of your cities are on the board. You have none left to place."}[kind])
		elif rules.can_pay(seat,CatanRules.COST[kind]) and sites.is_empty():button.unavailable_reason=tr("No legal space to build a %s.") % tr(kind)
	%TradeAction.disabled=not play or not state.rolled
	%EndTurn.disabled=not play or not state.rolled
	%FinishRoads.visible=state.phase=="free_roads" and mine
	%DiscardAction.visible=state.phase=="discard" and state.discards.has(str(seat))
	if %DiscardAction.visible:%DiscardAction.text=tr("Discard %d") % state.discards[str(seat)]
	if state.phase=="steal" and mine:
		for victim in state.victims:_add_steal_action(victim,state.players[victim].name)
	%ViewOffer.visible=not state.offer.is_empty()
	%HandResources.show_amounts(hand)
	_show_cards(seat,state,play,rules)

func show_turn_clock(seconds_left: float,limit: float,finished: bool):
	%TurnClock.visible=limit>0.0 and not finished
	if not %TurnClock.visible:return
	var left=ceili(seconds_left)
	%TurnClock.text="%d:%02d" % [left/60,left%60]
	%TurnClock.add_theme_color_override("font_color",CLOCK_URGENT_COLOR if left<=10 else CLOCK_COLOR)

func arrange(viewport: Vector2,overlay_bottom: float) -> Rect2:
	var stacked=viewport.x<1100
	%TopBody.vertical=stacked
	%HUDTools.vertical=not stacked
	for chip in %PlayersBody.get_children():chip.arrange(stacked)
	var available=viewport.x-64
	if not stacked:available-=%HUDTools.get_combined_minimum_size().x+8
	var columns=maxi(1,mini(%PlayersBody.get_child_count(),int((available+6)/286)))
	for chip in %PlayersBody.get_children():chip.custom_minimum_size.x=floorf((available-(columns-1)*6)/columns)
	%Bottom.offset_left=16
	%Bottom.offset_right=-16
	var bottom_height=%Bottom.get_combined_minimum_size().y
	%Bottom.offset_top=-12-bottom_height
	%Top.offset_bottom=12+%Top.get_combined_minimum_size().y
	# The tutorial lesson panel, when present, sits below the top bar.
	var top=overlay_bottom+10 if overlay_bottom>0 else %Top.offset_bottom+10
	notifications_top=top
	_arrange_cards(viewport.x,top,viewport.y-bottom_height-26)
	return Rect2(20,top,viewport.x-236,maxf(100,viewport.y-top-bottom_height-30))

func _show_cost(button: Button,cost: Array,hand: Array):
	button.cost=cost.duplicate()
	for resource in 5:button.missing.append(maxi(0,cost[resource]-hand[resource]))

func _add_steal_action(victim: int,victim_name: String):
	var button: Button=%ActionsBody.get_node("StealTemplate").duplicate()
	button.text=tr("Steal from %s") % victim_name
	button.show()
	button.pressed.connect(func():action_requested.emit({"type":"steal","id":victim}))
	%ActionsBody.add_child(button)
	%ActionsBody.move_child(button,%ViewOffer.get_index())

func _show_cards(seat: int,state: Dictionary,play: bool,rules: CatanRules):
	var player: Dictionary=state.players[seat]
	_show_cost(%BuyCard,CatanRules.COST.buy_card,player.hand)
	%BuyCard.disabled=not play or not state.rolled or not rules.can_pay(seat,CatanRules.COST.buy_card) or state.deck_count==0
	%BuyCard.unavailable_reason=tr("No development cards remain.") if state.deck_count==0 else tr("%d cards left in deck.") % state.deck_count
	var owned=0
	for id in 5:
		if player.cards[id]+player.new_cards[id]==0:continue
		var card=DEV_CARD.instantiate()
		card.name="Card%d" % id
		%CardsBody.add_child(card)
		card.show_card(id,player,state.card_played,play)
		card.play_requested.connect(_on_card_play_requested)
		owned+=1
	%EmptyCards.visible=owned==0

func _arrange_cards(width: float,top: float,bottom: float):
	%CardsRail.offset_top=top
	%CardsRail.offset_bottom=bottom
	%CardHeading.visible=width>=1000
	%CardsBody.offset_top=%CardShop.get_combined_minimum_size().y+12
	var cards=%CardsBody.get_children().filter(func(child):return child is Button)
	var available=maxf(100,%CardsRail.size.y-%CardsBody.offset_top)
	var card_height=minf(180,maxf(76,available-32*maxi(0,cards.size()-1)))
	var step=minf(92,maxf(0,(available-card_height)/maxi(1,cards.size()-1)))
	for i in cards.size():cards[i].rest_at(Rect2(Vector2(0,i*step),Vector2(%CardsRail.size.x,card_height)))

func _request(action_type: String):
	action_requested.emit({"type":action_type})

func _on_card_play_requested(card: int):
	if card<2:action_requested.emit({"type":"play_card","id":card})
	elif card<4:resource_card_requested.emit(card)
