extends CatanDialog
## Announces the winner with the map seed and each player's game in numbers.
## The room controller can start another game with the same seats.

signal leave_requested
signal rematch_requested
signal log_requested

const HEADER_COLOR=Color("796347")
const BAR_COLOR=Color("c3aa80")
const PEAK_COLOR=Color("8c522d")

func show_results(state: Dictionary,net: CatanNetwork):
	var winner: int=state.winner
	%Winner.text=tr("%s wins!") % state.players[winner].name
	%Winner.add_theme_color_override("font_color",net.player_color(winner).darkened(.25))
	var island=tr("Random coastline") if state.get("island","random")=="random" else tr("Classic hexagon")
	%Summary.text=tr("Map seed %d · %s · %d points to win") % [int(state.get("seed",0)),island,int(state.get("points_target",10))]
	if state.get("friendly_robber",false):%Summary.text+=" · "+tr("Friendly robber")
	_show_stats(state,net)
	_show_dice(state.get("dice_counts",[]))
	var controller=net.is_controller() and not net.tutorial
	%PlayAgain.visible=controller
	%BackToMenu.theme_type_variation=&"" if controller else &"PrimaryButton"

func _show_stats(state: Dictionary,net: CatanNetwork):
	for child in %Stats.get_children():child.free()
	for heading in [tr("Player"),tr("Points"),tr("Collected"),tr("Rolls"),tr("Trades"),tr("Stole"),tr("Lost")]:
		_cell(heading,HEADER_COLOR,13)
	var rules=CatanRules.new();rules.s=state
	var order=range(state.players.size())
	order.sort_custom(func(a,b):return rules.visible_points(a)>rules.visible_points(b))
	for p in order:
		var player: Dictionary=state.players[p]
		var stats: Dictionary=player.get("stats",{})
		var name_cell=_cell(player.name,net.player_color(p).darkened(.3),16)
		name_cell.auto_translate_mode=Node.AUTO_TRANSLATE_MODE_DISABLED
		name_cell.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		name_cell.custom_minimum_size.x=110
		name_cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var produced: Array=stats.get("produced",[0,0,0,0,0])
		_cell(str(rules.visible_points(p)),Color("493521"),16)
		var collected=_cell(str(rules.total(produced)),Color("493521"),16)
		collected.tooltip_text=", ".join(range(5).map(func(r):return "%d %s" % [produced[r],tr(CatanRules.RES[r])]))
		collected.mouse_filter=Control.MOUSE_FILTER_STOP
		_cell(str(stats.get("rolls",0)),Color("493521"),16)
		var trades=_cell(str(int(stats.get("trades",0))+int(stats.get("bank_trades",0))),Color("493521"),16)
		trades.tooltip_text=tr("%d with players · %d with the bank") % [int(stats.get("trades",0)),int(stats.get("bank_trades",0))]
		trades.mouse_filter=Control.MOUSE_FILTER_STOP
		_cell(str(stats.get("stolen",0)),Color("493521"),16)
		var lost=_cell(str(int(stats.get("lost",0))+int(stats.get("discarded",0))),Color("493521"),16)
		lost.tooltip_text=tr("%d stolen · %d discarded on a seven") % [int(stats.get("lost",0)),int(stats.get("discarded",0))]
		lost.mouse_filter=Control.MOUSE_FILTER_STOP

func _cell(text: String,color: Color,size: int) -> Label:
	var label=Label.new()
	label.text=text
	label.add_theme_color_override("font_color",color)
	label.add_theme_font_size_override("font_size",size)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT if text.is_valid_int() else HORIZONTAL_ALIGNMENT_LEFT
	%Stats.add_child(label)
	return label

## One bar per total from 2 to 12, scaled to the most frequent roll.
func _show_dice(counts: Array):
	for child in %Dice.get_children():child.free()
	%Dice.visible=counts.size()==11
	if not %Dice.visible:return
	var peak=maxi(1,counts.max())
	for i in 11:
		var column=VBoxContainer.new()
		column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		column.alignment=BoxContainer.ALIGNMENT_END
		column.add_theme_constant_override("separation",2)
		column.tooltip_text=tr("%d rolled %d times") % [i+2,counts[i]]
		column.mouse_filter=Control.MOUSE_FILTER_STOP
		var count=Label.new()
		count.text=str(counts[i])
		count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		count.add_theme_font_size_override("font_size",12)
		count.add_theme_color_override("font_color",HEADER_COLOR)
		column.add_child(count)
		var bar=ColorRect.new()
		bar.custom_minimum_size=Vector2(0,maxf(2,70.0*counts[i]/peak))
		bar.color=PEAK_COLOR if counts[i]==peak and counts[i]>0 else BAR_COLOR
		bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
		column.add_child(bar)
		var total=Label.new()
		total.text=str(i+2)
		total.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		total.add_theme_font_size_override("font_size",14)
		total.add_theme_color_override("font_color",Color("913f2d") if i+2 in [6,8] else Color("493521"))
		column.add_child(total)
		%Dice.add_child(column)
