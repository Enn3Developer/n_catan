extends CatanScreen
## In-game HUD: the scoreboard in the top left corner, tools in the top right, a
## bar along the bottom that says what the turn needs and holds the hand and the
## actions, and the development cards fanned out beside the bar. The bar keeps
## every action in place all game and greys out the ones that don't apply.
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
const CARD_FAN=preload("res://scripts/card_fan.gd")
const MARGIN=16.0
const GAP=12.0

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
	%Prompt.text=_prompt(state,seat,mode)
	%Dice.visible=state.rolled and state.winner==-1
	%Total.text=str(state.dice[0]+state.dice[1])
	%Dice.tooltip_text=tr("Last roll: %d") % (state.dice[0]+state.dice[1])
	# Roll and End share one spot: the turn only ever needs one of them.
	%EndTurn.visible=mine and state.rolled
	%RollDice.visible=not %EndTurn.visible
	%RollDice.disabled=not play or state.rolled
	%EndTurn.disabled=not play
	var rules=CatanRules.new();rules.s=state
	var seafaring=state.get("island","")=="archipelago"
	%ShipAction.visible=seafaring
	for kind in ["road","ship","settlement","city"] if seafaring else ["road","settlement","city"]:
		var button: Button=get_node("%"+kind.capitalize()+"Action")
		_show_cost(button,CatanRules.COST[kind],hand)
		button.set_pressed_no_signal(mode==kind)
		var sites=rules.build_sites(seat,kind)
		button.disabled=not play or not state.rolled or not rules.can_pay(seat,CatanRules.COST[kind]) or sites.is_empty()
		if not mine:button.unavailable_reason=tr("Wait for your turn.")
		elif rules.pieces(seat,kind)>=CatanRules.PIECE_LIMITS[kind]:
			button.unavailable_reason=tr({"ship":"All 15 of your ships are at sea. You have none left to place.","road":"All 15 of your roads are on the board. You have none left to place.","settlement":"All 5 of your settlements are on the board. Upgrade one to a city to free a settlement piece.","city":"All 4 of your cities are on the board. You have none left to place."}[kind])
		elif rules.can_pay(seat,CatanRules.COST[kind]) and sites.is_empty():button.unavailable_reason=tr("No legal space to build a %s.") % tr(kind)
	%TradeAction.disabled=not play or not state.rolled
	%FinishRoads.visible=state.phase=="free_roads" and mine
	%MoveShip.visible=play and state.rolled and state.get("move_ships",false)
	%MoveShip.set_pressed_no_signal(mode in ["move_ship","move_to"])
	%MoveShip.disabled=rules.movable_ships(seat).is_empty()
	%MoveShip.tooltip_text=tr("You have moved a ship this turn.") if state.get("ship_moved",false) else tr("Once per turn, move a ship from the open end of a line") if not %MoveShip.disabled else tr("No ship can move: only ships at the open end of a line, not built this turn.")
	%DiscardAction.visible=state.phase=="discard" and state.discards.has(str(seat))
	if state.phase=="steal" and mine:
		for victim in state.victims:_add_steal_action(victim,state.players[victim].name)
	%ViewOffer.visible=not state.offer.is_empty()
	%HandResources.show_amounts(hand)
	_show_cards(seat,state,play,rules)

## One line on what the game is waiting for, worded for this seat.
func _prompt(state: Dictionary,seat: int,mode: String) -> String:
	if state.winner!=-1:return tr("%s wins!") % state.players[state.winner].name
	if state.phase=="discard":
		if state.discards.has(str(seat)):return tr("Discard %d resources") % state.discards[str(seat)]
		var names=[]
		for key in state.discards:names.append(state.players[int(key)].name)
		return tr("Waiting for %s to discard") % ", ".join(names)
	var player_name: String=state.players[state.turn].name
	if state.turn!=seat:
		if state.phase in ["robber","steal"]:return tr("%s is moving the robber") % player_name
		return tr("%s's turn") % player_name
	match state.phase:
		"setup_settlement":return tr("Place a settlement on a glowing corner")
		"setup_road":return tr("Place a road beside your settlement")
		"robber":return tr("Move the robber to a glowing hex")
		"steal":return tr("Choose who to rob")
		"free_roads":return (tr("Place a free road or ship (%d left)") if state.get("island","")=="archipelago" else tr("Place a free road (%d left)")) % state.free_roads
	match mode:
		"road":return tr("Choose a glowing edge for your road")
		"ship":return tr("Choose a glowing sea edge for your ship")
		"settlement":return tr("Choose a glowing corner for your settlement")
		"city":return tr("Choose a settlement to upgrade")
		"move_ship":return tr("Choose a glowing ship to move")
		"move_to":return tr("Choose a glowing sea edge for the ship")
	return tr("Build, trade or end your turn") if state.rolled else tr("Roll dice")

func show_turn_clock(seconds_left: float,limit: float,finished: bool):
	%TurnClock.visible=limit>0.0 and not finished
	if not %TurnClock.visible:return
	var left=ceili(seconds_left)
	%TurnClock.text="%d:%02d" % [left/60,left%60]
	# Theme variations, not a color override, so the clock follows the night palette.
	%TurnClock.theme_type_variation="ErrorLabel" if left<=10 else "MutedLabel"

func arrange(viewport: Vector2,overlay_bottom: float) -> Rect2:
	# The bottom bar is as wide as its content and the card fan sits beside it,
	# with room kept for every kind of card so nothing shifts when one is bought.
	# When they don't fit side by side the hand stacks over the actions, and
	# after that the fan moves above the bar.
	var room=viewport.x-2*MARGIN
	var padding=%Bottom.get_theme_stylebox("panel").get_minimum_size()
	# Roll and End turn swap in one spot, so both take the wider one's width.
	var spot=maxf(%RollDice.get_minimum_size().x,%EndTurn.get_minimum_size().x)
	%RollDice.custom_minimum_size.x=spot
	%EndTurn.custom_minimum_size.x=spot
	var fan=CARD_FAN.full_size()
	var beside=true
	for layout in [[false,true],[true,true],[false,false],[true,false]]:
		%BottomRow.vertical=layout[0]
		%BottomRow.add_theme_constant_override("separation",10 if layout[0] else 24)
		beside=layout[1]
		# Without room beside the bar the fan shrinks into the bar, next to the hand.
		%CardFan.set_compact(not beside,%Hand if not beside else self)
		var needed=%BottomBody.get_combined_minimum_size().x+padding.x+(GAP+fan.x if beside else 0.0)
		if needed<=room:break
	var bar_width=minf(room-(GAP+fan.x if beside else 0.0),%BottomBody.get_combined_minimum_size().x+padding.x)
	var bar_height=%Bottom.get_combined_minimum_size().y
	var bar_left=(viewport.x-bar_width-(GAP+fan.x if beside else 0.0))/2
	%Bottom.offset_left=bar_left-viewport.x/2
	%Bottom.offset_right=bar_left+bar_width-viewport.x/2
	%Bottom.offset_top=-MARGIN-bar_height
	%Bottom.offset_bottom=-MARGIN
	var bar_top=viewport.y-MARGIN-bar_height
	if beside:%CardFan.position=Vector2(bar_left+bar_width+GAP,viewport.y-MARGIN-fan.y)
	# Every action shows all game, so the bar keeps its height and the island its place.
	var island_bottom=minf(bar_top,%CardFan.position.y) if beside else bar_top
	%Scoreboard.position=Vector2(MARGIN,MARGIN)
	%Scoreboard.size=%Scoreboard.get_combined_minimum_size()
	var tools=%HUDTools.get_combined_minimum_size()
	%HUDTools.offset_left=-MARGIN-tools.x
	%HUDTools.offset_bottom=MARGIN+tools.y
	notifications_top=MARGIN+tools.y+GAP
	toast_bottom=viewport.y-bar_top+GAP
	# The scoreboard and tools float over open sea in the top corners, which the
	# island's frame leaves clear, so the island is framed across the full width.
	# The island fills at most the middle half of that width; on small windows the
	# scoreboard reaches into it, so the island is framed beside the scoreboard.
	var left=MARGIN
	if %Scoreboard.get_rect().end.x>MARGIN+room/4:left=%Scoreboard.get_rect().end.x+GAP
	var top=overlay_bottom+10 if overlay_bottom>0 else MARGIN
	return Rect2(left,top,viewport.x-MARGIN-left,maxf(100,island_bottom-GAP-top))

## Where overlays such as the tutorial lesson may sit: right of the scoreboard, below the tools.
func overlay_area(viewport: Vector2) -> Rect2:
	var left=MARGIN+%Scoreboard.get_combined_minimum_size().x+GAP
	var top=MARGIN+%HUDTools.get_combined_minimum_size().y+GAP
	return Rect2(left,top,viewport.x-MARGIN-left,0)

func _show_cost(button: Button,cost: Array,hand: Array):
	button.cost=cost.duplicate()
	for resource in 5:button.missing.append(maxi(0,cost[resource]-hand[resource]))

func _add_steal_action(victim: int,victim_name: String):
	var button: Button=%PromptActions.get_node("StealTemplate").duplicate()
	button.text=tr("Steal from %s") % victim_name
	button.show()
	button.pressed.connect(func():action_requested.emit({"type":"steal","id":victim}))
	%PromptActions.add_child(button)
	%PromptActions.move_child(button,%ViewOffer.get_index())

func _show_cards(seat: int,state: Dictionary,play: bool,rules: CatanRules):
	var player: Dictionary=state.players[seat]
	_show_cost(%BuyCard,CatanRules.COST.buy_card,player.hand)
	%BuyCard.disabled=not play or not state.rolled or not rules.can_pay(seat,CatanRules.COST.buy_card) or state.deck_count==0
	%BuyCard.unavailable_reason=tr("No development cards remain.") if state.deck_count==0 else tr("%d cards left in deck.") % state.deck_count
	for id in 5:
		if player.cards[id]+player.new_cards[id]==0:continue
		var card=DEV_CARD.instantiate()
		card.name="Card%d" % id
		%CardFan.add_card(card)
		card.show_card(id,player,state.card_played,play)
		card.play_requested.connect(_on_card_play_requested)

func _request(action_type: String):
	action_requested.emit({"type":action_type})

func _on_card_play_requested(card: int):
	if card<2:action_requested.emit({"type":"play_card","id":card})
	elif card<4:resource_card_requested.emit(card)
