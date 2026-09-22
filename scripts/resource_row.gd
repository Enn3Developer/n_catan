extends HBoxContainer
## One badge per resource: its illustration and the amount. The icon size and
## whether empty resources stay visible are configured per instance.

@export var icon_size:=24
@export var show_zero:=false

func _ready():
	add_theme_constant_override("separation",4 if icon_size<=18 else 10)
	for badge: HBoxContainer in get_children():
		badge.size_flags_horizontal=Control.SIZE_EXPAND_FILL if show_zero else Control.SIZE_SHRINK_CENTER
		badge.get_node("Icon").custom_minimum_size=Vector2.ONE*icon_size
		badge.get_node("Count").add_theme_font_size_override("font_size",24 if icon_size>=32 else 14)

func show_amounts(amounts: Array):
	for i in 5:
		var badge: HBoxContainer=get_child(i)
		badge.visible=show_zero or amounts[i]>0
		badge.tooltip_text="%s: %d" % [TranslationServer.translate(CatanRules.RES[i]),amounts[i]]
		var count: Label=badge.get_node("Count")
		count.text=str(amounts[i])
		# Small rows show single resources as the bare icon.
		count.visible=not (icon_size<=18 and amounts[i]==1)
