extends Button
## A development card in the hand, shown as a small paper card beside the
## resources. It can be pressed only when the card can be played right now.

signal play_requested(card: int)

const TITLES=["Knight","Roads","Plenty","Monopoly","Victory"]
const TIPS=["Move the robber and steal a resource.","Build two roads for free.","Take two resources from the bank.","Take one resource type from every player.","Already included in your score; never needs to be played."]
const ARTWORK=["knight","road","hand","trade","star"]
const ACCENTS=[Color("97654b"),Color("527e72"),Color("72904e"),Color("54768e"),Color("b28a36")]

var card=-1

func show_card(id: int,player: Dictionary,card_played: bool,play: bool):
	card=id
	var accent: Color=ACCENTS[id]
	# The paper surfaces are local to this card, so each one carries its own accent.
	for surface in ["normal","hover","pressed","hover_pressed","focus"]:get_theme_stylebox(surface).border_color=accent
	get_theme_stylebox("disabled").border_color=Color(accent,.45)
	var count=player.cards[id]+player.new_cards[id]
	text=tr(TITLES[id])+(" ×%d" % count if count>1 else "")
	icon=CatanIcons.get_icon(ARTWORK[id])
	tooltip_text=tr(TIPS[id])+tr("\n%d ready · %d bought this turn") % [player.cards[id],player.new_cards[id]]
	# Victory cards score on their own and are never played.
	disabled=id==4 or not play or player.cards[id]==0 or card_played
	if id<4 and player.new_cards[id]>0:tooltip_text+=tr("\nNew action cards become playable next turn.")
	if id<4 and card_played:tooltip_text+=tr("\nYou have already played an action card this turn.")

func _on_pressed():
	play_requested.emit(card)
