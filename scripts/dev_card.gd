extends Button
## A development card in the hand: a small portrait card with its type on a
## coloured band and its artwork below. Cards of one type share a card with a
## count in the corner the next card leaves uncovered. The fan tilts each card;
## pointing at one lifts it upright.

signal play_requested(card: int)

const TITLES=["Knight","Roads","Plenty","Monopoly","Victory"]
const TIPS=["Move the robber and steal a resource.","Build two roads for free.","Take two resources from the bank.","Take one resource type from every player.","Already included in your score; never needs to be played."]
const ARTWORK=["knight","road","hand","trade","star"]
const ACCENTS=[Color("97654b"),Color("527e72"),Color("72904e"),Color("54768e"),Color("b28a36")]
const LIFT=14.0
const TITLE_SIZE=12
const SMALLEST_TITLE=10
## The title's inset from the card's left edge.
const TITLE_INSET=5.0
## A little air between the title and the next card's edge.
const TITLE_GAP=2.0

var card=-1
var rest_position=Vector2.ZERO
var rest_rotation=0.0
var motion: Tween

func show_card(id: int,player: Dictionary,card_played: bool,play: bool):
	card=id
	var accent: Color=ACCENTS[id]
	# The paper surfaces are local to this card, so each one carries its own accent.
	for surface in ["normal","hover","pressed","hover_pressed","focus"]:get_theme_stylebox(surface).border_color=accent
	get_theme_stylebox("disabled").border_color=accent.lerp(Color("eedab0"),.35)
	var count=player.cards[id]+player.new_cards[id]
	%Title.text=tr(TITLES[id])
	_fit_title()
	%Art.texture=CatanIcons.get_icon(ARTWORK[id])
	%Count.text="×%d" % count
	%Count.visible=count>1
	tooltip_text=tr(TIPS[id])+tr("\n%d ready · %d bought this turn") % [player.cards[id],player.new_cards[id]]
	# Victory cards score on their own and are never played.
	disabled=id==4 or not play or player.cards[id]==0 or card_played
	mouse_default_cursor_shape=CURSOR_ARROW if disabled else CURSOR_POINTING_HAND
	if id<4 and player.new_cards[id]>0:tooltip_text+=tr("\nNew action cards become playable next turn.")
	if id<4 and card_played:tooltip_text+=tr("\nYou have already played an action card this turn.")

## Width the title may use: the strip the next card leaves in view, or the
## whole band when no card lies on top.
var title_room=0.0

## The next card in the fan covers this one's right edge. The title shrinks to
## fit the strip that stays in view, down to 10 px; past that it ends in an
## ellipsis there instead of being cut off mid-letter. A lifted card shows it whole.
func _fit_title():
	var font: Font=%Title.get_theme_font("font")
	var room=_title_room(false)
	var size=TITLE_SIZE
	while size>SMALLEST_TITLE and font.get_string_size(%Title.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>room:size-=1
	%Title.add_theme_font_size_override("font_size",size)
	_show_title_room(false)

func _title_room(lifted: bool) -> float:
	var whole=custom_minimum_size.x-TITLE_INSET-1
	return whole if lifted or title_room<=0.0 else minf(whole,title_room)

func _show_title_room(lifted: bool):
	%Title.offset_right=_title_room(lifted)-(custom_minimum_size.x-TITLE_INSET)

## Places the card at its slot in the fan.
## A card with another on top of it keeps its title to the strip still in view.
func rest_at(slot: Vector2,tilt: float,uncovered: float=0.0):
	title_room=maxf(0.0,uncovered-TITLE_INSET-TITLE_GAP) if uncovered>0.0 else 0.0
	_fit_title()
	rest_position=slot
	rest_rotation=tilt
	pivot_offset=Vector2(size.x/2,size.y)
	position=slot
	rotation=tilt

## Raises the card upright above the fan, or lets it fall back into place.
func lift(up: bool):
	if motion:motion.kill()
	z_index=1 if up else 0
	_show_title_room(up)
	motion=create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	motion.tween_property(self,"position",rest_position-Vector2(0,LIFT if up else 0.0),.12)
	motion.tween_property(self,"rotation",0.0 if up else rest_rotation,.12)

func _on_pressed():
	play_requested.emit(card)
