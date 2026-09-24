extends PanelContainer
## A player's summary in the HUD's top bar: name, turn marker and public tallies.

func show_player(state: Dictionary,index: int,seat: int,color: Color):
	var player: Dictionary=state.players[index]
	var scoring=CatanRules.new();scoring.s=state
	var score=scoring.visible_points(index)
	var current=index==state.turn
	var style: StyleBoxFlat=get_theme_stylebox("panel")
	style.bg_color=Color("8c522d",0.07) if current else Color.TRANSPARENT
	style.border_width_bottom=2 if current else 0
	style.border_width_right=1 if not current and index<state.players.size()-1 else 0
	style.border_color=color if current else Color("ac8654",0.35)
	tooltip_text=tr("%s%s\n%d points · %d resources · %d development cards\nRoad length %d · %d knights%s%s") % [player.name,tr(" (you)") if index==seat else "",score,player.resource_count,player.card_count,player.road_length,player.knights,tr("\nLongest road +2") if state.longest==index else "",tr("\nLargest army +2") if state.army==index else ""]
	var hidden_points=player.cards[4]+player.new_cards[4] if player.cards.size()==5 else 0
	tooltip_text+=tr("\n%d public points + %d victory-point cards = %d total") % [player.points,hidden_points,score] if player.cards.size()==5 else tr("\nVictory-point cards stay private until game end.")
	%Name.text=player.name
	# Seat colors can be too pale for lettering, so the name stays in ink beside a color bar.
	%Accent.color=color
	%TurnState.visible=current
	%TurnState.text=tr("Your turn") if index==seat else tr("Playing")
	for stat in [[%Score,score,tr("Victory points")],[%Resources,player.resource_count,"Resources"],[%Cards,player.card_count,tr("Development cards")],[%RoadLength,player.road_length,tr("Longest road length")],[%Knights,player.knights,tr("Played knights")]]:
		stat[0].tooltip_text=tr(stat[2])+": "+str(stat[1])
		stat[0].get_node("Value").text=str(stat[1])
	%Score.tooltip_text=tooltip_text+tr("\n%d points win the game.") % scoring.target()

## Narrow windows stack the chips, so each one lays out name above tallies.
func arrange(stacked: bool):
	%PlayerContent.vertical=not stacked
	%PlayerName.vertical=stacked
	%PlayerName.custom_minimum_size.x=80 if stacked else 0
	%PlayerName.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	%PlayerStats.add_theme_constant_override("separation",6 if stacked else 10)
