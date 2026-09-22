extends OptionButton
## A resource dropdown showing each resource's illustration.

func _ready():
	for resource in 5:
		add_icon_item(CatanIcons.resource_icon(resource),tr(CatanRules.RES[resource]))
		get_popup().set_item_icon_max_width(resource,26)
