extends Control
## The development cards in the player's hand, held as a fan. Cards overlap and
## tilt outwards from the middle; the outer ones sit a little lower. A compact
## fan holds smaller cards and fits inside the bottom bar on small windows.

const CARD_SIZE=Vector2(64,90)
const STEP=56.0
const TILT=5.0
const MOST_CARDS=5
## Room kept around the cards for their tilt, shadow and lift.
const PADDING=Vector2(10,18)
const COMPACT_SCALE=.7

var compact=false

## The space the full-size fan needs when it holds every kind of card.
static func full_size() -> Vector2:
	return Vector2(CARD_SIZE.x+STEP*(MOST_CARDS-1),CARD_SIZE.y)+2*PADDING

func add_card(card: Control):
	add_child(card)
	card.size=CARD_SIZE
	_place_cards()

## Switches between the full fan beside the bar and the compact one inside it.
func set_compact(value: bool,holder: Node):
	if get_parent()!=holder:
		reparent(holder,false)
		if holder is Container:holder.move_child(self,-1)
	if compact==value:return
	compact=value
	_place_cards()

func _place_cards():
	var count=get_child_count()
	var scale_by=COMPACT_SCALE if compact else 1.0
	var padding=Vector2(4,4) if compact else PADDING
	custom_minimum_size=Vector2.ZERO if count==0 else Vector2(CARD_SIZE.x+STEP*(count-1),CARD_SIZE.y)*scale_by+2*padding
	for i in count:
		var card=get_child(i)
		var offset=i-(count-1)/2.0
		card.scale=Vector2.ONE*scale_by
		# Cards scale about their bottom centre, so a small card is drawn that far in from its slot.
		var shift=Vector2(CARD_SIZE.x/2,CARD_SIZE.y)*(1-scale_by)
		card.rest_at(padding+Vector2(i*STEP,absf(offset)*absf(offset)*2.5)*scale_by-shift,deg_to_rad(offset*TILT))
