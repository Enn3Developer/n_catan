extends VBoxContainer

var cards={}

func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation",8)

func dismiss(key: String):
	if cards.has(key):
		var card=cards[key]
		cards.erase(key)
		remove_child(card)
		card.queue_free()

func show_notice(key: String,message: String,action_text: String="",action: Callable=Callable(),seconds: float=5):
	dismiss(key)
	while cards.size()>=3:dismiss(cards.keys()[0])
	var card=PanelContainer.new()
	var style=StyleBoxFlat.new()
	style.bg_color=Color("f3deb4")
	style.border_color=Color("8c522d")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left=14;style.content_margin_right=14
	style.content_margin_top=12;style.content_margin_bottom=12
	card.add_theme_stylebox_override("panel",style)
	add_child(card);cards[key]=card
	var box=VBoxContainer.new();box.add_theme_constant_override("separation",8);card.add_child(box)
	var label=Label.new();label.text=message
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",16)
	box.add_child(label)
	var buttons=HBoxContainer.new();box.add_child(buttons)
	if action.is_valid():
		var review=Button.new();review.text=action_text;buttons.add_child(review)
		review.pressed.connect(func():dismiss(key);action.call())
	var close=Button.new();close.text="Dismiss";buttons.add_child(close)
	close.pressed.connect(func():dismiss(key))
	if seconds>0:
		var timer=Timer.new();timer.one_shot=true;card.add_child(timer)
		timer.timeout.connect(func():
			if cards.get(key)==card:dismiss(key))
		timer.start(seconds)
