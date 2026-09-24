extends Button
## A development card in the hand. Resting cards overlap in a stack; hovering or
## focusing one lifts it clear so its whole face is readable.

signal play_requested(card: int)

const TITLES=["Knight","Roads","Plenty","Monopoly","Victory"]
const EFFECTS=["Move the robber", "Build two free roads", "Take two resources", "Claim one resource type", "+1 victory point"]
const TIPS=["Move the robber and steal a resource.","Build two roads for free.","Take two resources from the bank.","Take one resource type from every player.","Already included in your score; never needs to be played."]
const ARTWORK=["knight","road","hand","trade","star"]
const ACCENTS=[Color("97654b"),Color("527e72"),Color("72904e"),Color("54768e"),Color("b28a36")]

var card=-1
var rest_rect=Rect2()

func show_card(id: int,player: Dictionary,card_played: bool,play: bool):
	card=id
	var accent: Color=ACCENTS[id]
	# The paper surfaces are local to this card, so each one carries its own accent.
	for surface in ["normal","hover","pressed","disabled","focus"]:get_theme_stylebox(surface).border_color=accent
	%Title.text=tr(TITLES[id])
	%Count.text="×%d" % (player.cards[id]+player.new_cards[id])
	%Count.add_theme_color_override("font_color",accent)
	%Art.texture=CatanIcons.get_icon(ARTWORK[id])
	%Art.modulate=accent
	%CardEffect.text=tr(EFFECTS[id])
	var ready=player.cards[id]>0 and not card_played and play
	# Victory cards score on their own, so they have no play status to show.
	%CardStatus.text="" if id==4 else (tr("Ready") if ready else (tr("Next turn") if player.cards[id]==0 else tr("Waiting")))
	tooltip_text=tr(TIPS[id])+tr("\n%d ready · %d bought this turn") % [player.cards[id],player.new_cards[id]]
	disabled=id==4 or not play or player.cards[id]==0 or card_played
	if id<4 and player.new_cards[id]>0:tooltip_text+=tr("\nNew action cards become playable next turn.")
	if id<4 and card_played:tooltip_text+=tr("\nYou have already played an action card this turn.")

## Places the card at its resting slot in the stack.
func rest_at(rect: Rect2):
	rest_rect=rect
	preview(false)

func preview(expanded: bool):
	if not rest_rect.has_area():return
	z_index=2 if expanded else 0
	position=rest_rect.position+Vector2(-12 if expanded else 0,0)
	size=Vector2(rest_rect.size.x,180.0 if expanded else rest_rect.size.y)
	if expanded:position.y=minf(position.y,get_parent().size.y-size.y)
	%CardEffect.visible=size.y>=140
	%CardStatus.visible=size.y>=110
	%Art.custom_minimum_size=Vector2.ONE*(48 if size.y>=140 else 32)

func _on_pressed():
	play_requested.emit(card)
