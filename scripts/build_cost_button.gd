extends Button
## Native hover tooltip using the same resource artwork as the player's hand.
const COST_TOOLTIP=preload("res://scenes/ui/cost_tooltip.tscn")
var cost: Array=[]
var missing: Array=[]
var unavailable_reason=""

func _make_custom_tooltip(_text: String) -> Object:
	var tooltip=COST_TOOLTIP.instantiate()
	# Tooltips live in a separate popup; explicitly share the animated UI theme.
	var ancestor: Node=self
	while ancestor!=null:
		if ancestor is Control and ancestor.theme!=null:
			tooltip.theme=ancestor.theme
			break
		ancestor=ancestor.get_parent()
	tooltip.show_cost(text,cost,missing,unavailable_reason)
	return tooltip
