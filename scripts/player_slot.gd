extends PanelContainer
## One seat in the lobby: who sits there and whether they are ready, plus the
## bot controls available to the room controller.

signal difficulty_selected(seat: int,level: int)
signal remove_requested(seat: int)

const READY_COLOR=Color("8c522d")
const WAITING_COLOR=Color("796347")
var seat=-1

func show_seat(net: CatanNetwork,index: int,controller: bool):
	seat=index
	var occupied=index<net.roster.size()
	var row: Dictionary=net.roster[index] if occupied else {}
	var bot=occupied and row.get("bot",false)
	# Open seats shrink to a faint placeholder so the filled ones stand out.
	%Accent.visible=occupied
	%Accent.color=net.player_color(index) if occupied else Color.TRANSPARENT
	%PlayerInfo.visible=occupied
	custom_minimum_size.y=66 if occupied else 44
	modulate.a=1.0 if occupied else 0.55
	%PlayerName.text=row.name if occupied else tr("Open seat")
	var info=""
	var waiting=occupied and row.get("saved_seat",false) and not row.connected
	if occupied: info=tr("Bot") if bot else tr("Saved seat, waiting to rejoin") if waiting else tr("You") if index==net.seat else tr("Player")
	if occupied:
		var preset=CatanAppearance.preset_of(row.get("look",PackedByteArray()))
		info+=" · "+(tr(CatanAppearance.PRESETS[preset].name) if preset>=0 else tr("Custom pieces"))
	%PlayerInfo.text=info
	%Status.text=tr("Ready") if occupied and row.ready else tr("Waiting") if occupied else ""
	%Status.visible=occupied and not bot and not net.solo
	%Status.add_theme_color_override("font_color",READY_COLOR if occupied and row.ready else WAITING_COLOR)
	%Difficulty.visible=bot
	if bot:
		for level in CatanBot.LEVELS: %Difficulty.add_item(level)
		%Difficulty.select(row.difficulty)
		%Difficulty.disabled=not controller
	%Remove.visible=bot and controller and not net.room_settings.get("resuming",false)
	if waiting:modulate.a=.7

func _on_difficulty_item_selected(level: int):
	difficulty_selected.emit(seat,level)

func _on_remove_pressed():
	remove_requested.emit(seat)
