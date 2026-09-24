extends CatanDialog
## The whole game log, newest at the bottom, with a player filter and search.

var entries: Array=[]
var plain_line: StyleBox
var names: Array=[]
var seat=-1

func show_log(lines: Array,player: int,state: Dictionary):
	var players: Array=state.get("players",[])
	if lines==entries and names.size()==players.size() and not entries.is_empty():return
	var follow=entries.is_empty() or _at_bottom()
	entries=lines
	seat=player
	if names.size()!=players.size():
		names=[]
		for p in players:names.append(str(p.name))
		var selected=%PlayerFilter.selected
		%PlayerFilter.clear()
		%PlayerFilter.add_item(tr("Everyone"))
		for i in names.size():%PlayerFilter.add_item(names[i]+(tr(" (you)") if i==seat else ""))
		%PlayerFilter.select(maxi(0,mini(selected,names.size())))
	_render(follow)

func _render(follow: bool):
	var template: PanelContainer=%Lines.get_node("LineTemplate")
	for child in %Lines.get_children():
		if child!=template:child.free()
	var needle: String=%Search.text.strip_edges().to_lower()
	var who=%PlayerFilter.selected-1
	var shown=0
	for i in entries.size():
		var text=CatanI18n.render(entries[i])
		if who>=0 and who<names.size() and not names[who] in text:continue
		if not needle.is_empty() and not needle in text.to_lower():continue
		var row: PanelContainer=template.duplicate()
		row.get_node("Row/Number").text=str(i+1)
		row.get_node("Row/Text").text=text
		# Alternate the shading so long runs stay easy to follow.
		if shown%2==1:row.add_theme_stylebox_override("panel",_plain(template))
		row.show()
		%Lines.add_child(row)
		shown+=1
	%Empty.visible=shown==0
	%Count.text=tr("%d entries") % entries.size() if shown==entries.size() else tr("%d of %d entries") % [shown,entries.size()]
	if follow:_scroll_to_end.call_deferred()

## The shaded line style without its fill, so both kinds of row keep the same margins.
func _plain(template: PanelContainer) -> StyleBox:
	if plain_line==null:
		plain_line=template.get_theme_stylebox("panel").duplicate()
		plain_line.bg_color=Color.TRANSPARENT
	return plain_line

func _at_bottom() -> bool:
	var bar: VScrollBar=%DialogScroll.get_v_scroll_bar()
	return bar.value+bar.page>=bar.max_value-8

func _scroll_to_end():
	await get_tree().process_frame
	if is_instance_valid(self):%DialogScroll.scroll_vertical=int(%DialogScroll.get_v_scroll_bar().max_value)

func _on_filter_changed(_value):
	_render(true)
