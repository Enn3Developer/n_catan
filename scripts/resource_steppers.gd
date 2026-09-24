extends HBoxContainer
## One tile per resource with an amount and − / + buttons, for choosing how
## many of each resource to hand over. Each tile shows how many the player has.

signal changed

var values=[0,0,0,0,0]
var limits=[0,0,0,0,0]
var amount_labels=[]
var minus_buttons=[]
var plus_buttons=[]
var have_labels=[]

func _ready():
	for resource in 5:
		var tile=PanelContainer.new()
		tile.theme_type_variation=&"Card"
		tile.size_flags_horizontal=SIZE_EXPAND_FILL
		tile.tooltip_text=tr(CatanRules.RES[resource])
		add_child(tile)
		var body=VBoxContainer.new()
		body.alignment=BoxContainer.ALIGNMENT_CENTER
		body.add_theme_constant_override("separation",4)
		body.mouse_filter=MOUSE_FILTER_IGNORE
		tile.add_child(body)
		var art=CatanIcons.icon(body,CatanIcons.RESOURCES[resource],36)
		art.size_flags_horizontal=SIZE_SHRINK_CENTER
		var amount=Label.new()
		amount.theme_type_variation=&"HeadingLabel"
		amount.add_theme_font_size_override("font_size",24)
		amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(amount)
		amount_labels.append(amount)
		var have=Label.new()
		have.theme_type_variation=&"MutedLabel"
		have.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(have)
		have_labels.append(have)
		var steps=HBoxContainer.new()
		steps.alignment=BoxContainer.ALIGNMENT_CENTER
		steps.add_theme_constant_override("separation",6)
		body.add_child(steps)
		for delta in [-1,1]:
			var button=Button.new()
			button.text="−" if delta<0 else "+"
			button.custom_minimum_size=Vector2(34,32)
			button.mouse_default_cursor_shape=CURSOR_POINTING_HAND
			button.add_to_group("ui_click")
			button.pressed.connect(step.bind(resource,delta))
			steps.add_child(button)
			(minus_buttons if delta<0 else plus_buttons).append(button)
	_refresh()

## Sets how many of each resource can be chosen, and clears the choice.
func set_limits(amounts: Array,have_text: String="of %d"):
	limits=amounts.duplicate()
	values=[0,0,0,0,0]
	for resource in 5:have_labels[resource].text=tr(have_text) % limits[resource]
	_refresh()

func step(resource: int,delta: int):
	values[resource]=clampi(values[resource]+delta,0,limits[resource])
	_refresh()
	changed.emit()

func total() -> int:
	var sum=0
	for value in values:sum+=value
	return sum

func _refresh():
	if amount_labels.is_empty():return
	for resource in 5:
		amount_labels[resource].text=str(values[resource])
		minus_buttons[resource].disabled=values[resource]<=0
		plus_buttons[resource].disabled=values[resource]>=limits[resource]
