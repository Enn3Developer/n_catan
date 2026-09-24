extends PanelContainer
## One player's row on the HUD scoreboard: name and points, then public tallies.
## The row whose turn it is sits on a honey band.

# Palette colors, so the night theme swaps them with the rest of the interface.
const TURN_COLOR=Color("e4c18c")
const BONUS_COLOR=Color("b77633")

func show_player(state: Dictionary,index: int,seat: int,color: Color):
	var player: Dictionary=state.players[index]
	var scoring=CatanRules.new();scoring.s=state
	var score=scoring.visible_points(index)
	var current=index==state.turn and state.winner==-1
	get_theme_stylebox("panel").bg_color=TURN_COLOR if current else Color(TURN_COLOR,0)
	tooltip_text=tr("%s%s\n%d points · %d resources · %d development cards\nRoad length %d · %d knights%s%s") % [player.name,tr(" (you)") if index==seat else "",score,player.resource_count,player.card_count,player.road_length,player.knights,tr("\nLongest road +2") if state.longest==index else "",tr("\nLargest army +2") if state.army==index else ""]
	var hidden_points=player.cards[4]+player.new_cards[4] if player.cards.size()==5 else 0
	tooltip_text+=tr("\n%d public points + %d victory-point cards = %d total") % [player.points,hidden_points,score] if player.cards.size()==5 else tr("\nVictory-point cards stay private until game end.")
	%Name.text=player.name
	# Seat colors can be too pale for lettering, so the name stays in ink beside a color bar.
	%Accent.color=color
	for stat in [[%Score,score,tr("Victory points")],[%Resources,player.resource_count,"Resources"],[%Cards,player.card_count,tr("Development cards")],[%RoadLength,player.road_length,tr("Longest road length")],[%Knights,player.knights,tr("Played knights")]]:
		stat[0].tooltip_text=tr(stat[2])+": "+str(stat[1])
		stat[0].get_node("Value").text=str(stat[1])
	# Holders of longest road and largest army see those tallies in brass.
	for bonus in [[%RoadLength,state.longest==index,tr("\nLongest road +2")],[%Knights,state.army==index,tr("\nLargest army +2")]]:
		if not bonus[1]:continue
		bonus[0].get_node("Value").add_theme_color_override("font_color",BONUS_COLOR)
		bonus[0].tooltip_text+=bonus[2]
	%Score.tooltip_text=tooltip_text+tr("\n%d points win the game.") % scoring.target()
