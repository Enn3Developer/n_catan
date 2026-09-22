extends VBoxContainer
## At most three notification cards. A card shown with an existing key replaces
## the older one.

const CARD=preload("res://scenes/ui/notification_card.tscn")
var cards={}

func dismiss(key: String):
	if cards.has(key):
		var card=cards[key]
		cards.erase(key)
		remove_child(card)
		card.queue_free()

func show_notice(key: String,message: String,action_text: String="",action: Callable=Callable(),seconds: float=5):
	dismiss(key)
	while cards.size()>=3:dismiss(cards.keys()[0])
	var card=CARD.instantiate()
	add_child(card);cards[key]=card
	card.show_notice(message,action_text,action.is_valid(),seconds)
	card.acted.connect(func():dismiss(key);action.call())
	card.dismissed.connect(func():
		if cards.get(key)==card:dismiss(key))
