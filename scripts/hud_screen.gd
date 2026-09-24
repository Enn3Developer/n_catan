extends CatanScreen
## In-game HUD: the scoreboard in the top left corner, tools in the top right, and
## a bar along the bottom that says what the turn needs and holds the hand, the
## development cards and the actions that apply right now.
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
	%RollDice.visible=play and not state.rolled
	%EndTurn.visible=play and state.rolled
	var rules=CatanRules.new();rules.s=state
	for kind in ["road","settlement","city"]:
		var button: Button=get_node("%"+kind.capitalize()+"Action")
		button.visible=play
		_show_cost(button,CatanRules.COST[kind],hand)
		button.set_pressed_no_signal(mode==kind)
		var sites=rules.build_sites(seat,kind)
		button.disabled=not state.rolled or not rules.can_pay(seat,CatanRules.COST[kind]) or sites.is_empty()
		if rules.pieces(seat,kind)>=PIECE_LIMITS[kind]:
			button.unavailable_reason=tr({"road":"All 15 of your roads are on the board. You have none left to place.","settlement":"All 5 of your settlements are on the board. Upgrade one to a city to free a settlement piece.","city":"All 4 of your cities are on the board. You have none left to place."}[kind])
		elif rules.can_pay(seat,CatanRules.COST[kind]) and sites.is_empty():button.unavailable_reason=tr("No legal space to build a %s.") % tr(kind)
	%TradeAction.visible=play
	%TradeAction.disabled=not state.rolled
	%FinishRoads.visible=state.phase=="free_roads" and mine
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
		"free_roads":return tr("Place a free road (%d left)") % state.free_roads
	match mode:
		"road":return tr("Choose a glowing edge for your road")
		"settlement":return tr("Choose a glowing corner for your settlement")
		"city":return tr("Choose a settlement to upgrade")
	return tr("Build, trade or end your turn") if state.rolled else tr("Roll dice")

func show_turn_clock(seconds_left: float,limit: float,finished: bool):
	%TurnClock.visible=limit>0.0 and not finished
	if not %TurnClock.visible:return
	var left=ceili(seconds_left)
	%TurnClock.text="%d:%02d" % [left/60,left%60]
	%TurnClock.add_theme_color_override("font_color",CLOCK_URGENT_COLOR if left<=10 else CLOCK_COLOR)

func arrange(viewport: Vector2,overlay_bottom: float) -> Rect2:
	# The bottom bar is as wide as its content; the hand stacks over the actions
	# when one row would not fit.
	var room=viewport.x-2*MARGIN
	var padding=%Bottom.get_theme_stylebox("panel").get_minimum_size()
	for vertical in [false,true]:
		%BottomRow.vertical=vertical
		%BottomRow.add_theme_constant_override("separation",10 if vertical else 24)
		if %BottomBody.get_combined_minimum_size().x+padding.x<=room:break
	var bar_width=minf(room,%BottomBody.get_combined_minimum_size().x+padding.x)
	var bar_height=%Bottom.get_combined_minimum_size().y
	%Bottom.offset_left=-bar_width/2
	%Bottom.offset_right=bar_width/2
	%Bottom.offset_top=-MARGIN-bar_height
	%Bottom.offset_bottom=-MARGIN
	var bar_top=viewport.y-MARGIN-bar_height
	# The island keeps its place from turn to turn: the camera frames it above the
	# bar as tall as it gets on this player's own turn, when every action shows.
	var actions=-8.0
	for button in [%RoadAction,%SettlementAction,%CityAction,%BuyCard,%TradeAction,%EndTurn]:actions+=button.get_combined_minimum_size().x+8
	var hand=%Hand.get_combined_minimum_size()
	var row=maxf(hand.y,%EndTurn.get_combined_minimum_size().y)
	if hand.x+24+actions+padding.x>room:row=hand.y+10+%EndTurn.get_combined_minimum_size().y
	var tallest=padding.y+%PromptRow.get_combined_minimum_size().y+10+row
	var island_bottom=viewport.y-MARGIN-maxf(bar_height,tallest)
	%Scoreboard.position=Vector2(MARGIN,MARGIN)
	%Scoreboard.size=%Scoreboard.get_combined_minimum_size()
	var tools=%HUDTools.get_combined_minimum_size()
	%HUDTools.offset_left=-MARGIN-tools.x
	%HUDTools.offset_bottom=MARGIN+tools.y
	notifications_top=MARGIN+tools.y+GAP
	toast_bottom=viewport.y-bar_top+GAP
	# The scoreboard and tools float over open sea in the top corners, which the
	# island's frame leaves clear, so the island is framed across the full width.
	var top=overlay_bottom+10 if overlay_bottom>0 else MARGIN
	return Rect2(MARGIN,top,room,maxf(100,island_bottom-GAP-top))

## Where overlays such as the tutorial lesson may sit: right of the scoreboard, below the tools.
func overlay_area(viewport: Vector2) -> Rect2:
	var left=MARGIN+%Scoreboard.get_combined_minimum_size().x+GAP
	var top=MARGIN+%HUDTools.get_combined_minimum_size().y+GAP
	return Rect2(left,top,viewport.x-MARGIN-left,0)

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
	%BuyCard.visible=play
	_show_cost(%BuyCard,CatanRules.COST.buy_card,player.hand)
	%BuyCard.disabled=not state.rolled or not rules.can_pay(seat,CatanRules.COST.buy_card) or state.deck_count==0
	%BuyCard.unavailable_reason=tr("No development cards remain.") if state.deck_count==0 else tr("%d cards left in deck.") % state.deck_count
	for id in 5:
		if player.cards[id]+player.new_cards[id]==0:continue
		var card=DEV_CARD.instantiate()
		card.name="Card%d" % id
		%CardsBody.add_child(card)
		card.show_card(id,player,state.card_played,play)
		card.play_requested.connect(_on_card_play_requested)
	%CardsBody.visible=%CardsBody.get_child_count()>0

func _request(action_type: String):
	action_requested.emit({"type":action_type})

func _on_card_play_requested(card: int):
	if card<2:action_requested.emit({"type":"play_card","id":card})
	elif card<4:resource_card_requested.emit(card)
