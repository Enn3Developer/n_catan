extends VBoxContainer
## Hover card for build actions: what it costs, what is missing and why it is unavailable.

func show_cost(title: String,cost: Array,missing: Array,unavailable_reason: String):
	%Title.text=title
	%Cost.show_amounts(cost)
	for resource in cost.size():
		if cost[resource]>0 and resource<missing.size() and missing[resource]>0:
			var shortage=Label.new()
			shortage.text="(%d)" % missing[resource]
			shortage.add_theme_color_override("font_color",Color("dc4545"))
			%Cost.get_child(resource).add_child(shortage)
	%Reason.text=unavailable_reason
	%Reason.visible=not unavailable_reason.is_empty()
