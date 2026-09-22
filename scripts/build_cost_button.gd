extends Button
## Native hover tooltip using the same resource artwork as the player's hand.
var cost: Array=[]
var missing: Array=[]
var unavailable_reason=""

func _make_custom_tooltip(_text: String) -> Object:
	var box=VBoxContainer.new()
	# Tooltips live in a separate popup; explicitly share the animated UI theme.
	var ancestor: Node=self
	while ancestor!=null:
		if ancestor is Control and ancestor.theme!=null:
			box.theme=ancestor.theme
			break
		ancestor=ancestor.get_parent()
	var title=Label.new()
	title.text=text
	box.add_child(title)
	var resources=CatanIcons.resources(box,cost,28)
	for resource in cost.size():
		if cost[resource]>0 and resource<missing.size() and missing[resource]>0:
			var shortage=Label.new()
			shortage.text="(%d)" % missing[resource]
			shortage.add_theme_color_override("font_color",Color("dc4545"))
			resources.get_child(resource).add_child(shortage)
	if not unavailable_reason.is_empty():
		var reason=Label.new()
		reason.text=unavailable_reason
		reason.custom_minimum_size.x=280
		reason.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		box.add_child(reason)
	return box
