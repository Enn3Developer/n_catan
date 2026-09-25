class_name CatanPointsChart
extends Control
## Victory points after every turn, one line per player in their seat color.
## Each line ends in a dot with the player's name and score beside it, so a
## line is never told apart by color alone. Hovering shows every score at
## that turn under a crosshair.

const INK=Color("493521")
const MUTED=Color("796347")
const GRID=Color(.47,.39,.28,.18)
const TARGET=Color("913f2d")
const LEFT=26.0
const RIGHT=112.0
const TOP=10.0
const BOTTOM=22.0

var history: Array=[]
var names: Array=[]
var colors: Array=[]
var target=10
var hover=-1

func show_history(points: Array,player_names: Array,player_colors: Array,goal: int):
	history=points
	names=player_names
	colors=player_colors
	target=goal
	custom_minimum_size.y=170
	mouse_filter=Control.MOUSE_FILTER_STOP
	# Any text turns tooltips on; _get_tooltip writes the real one.
	tooltip_text=" "
	queue_redraw()

func _plot() -> Rect2:
	return Rect2(LEFT,TOP,maxf(10,size.x-LEFT-RIGHT),maxf(10,size.y-TOP-BOTTOM))

func _top_value() -> int:
	var peak=target
	for row in history:
		for value in row:peak=maxi(peak,int(value))
	return peak

func _point(turn: int,value: float) -> Vector2:
	var area=_plot()
	var x=area.position.x+area.size.x*(float(turn)/maxf(1,history.size()-1))
	return Vector2(x,area.end.y-area.size.y*value/_top_value())

func _draw():
	if history.size()<2:return
	var area=_plot()
	var font=get_theme_default_font()
	var top=_top_value()
	# A faint line every two points, with the scale on the left.
	for value in range(0,top+1,2):
		var y=_point(0,value).y
		draw_line(Vector2(area.position.x,y),Vector2(area.end.x,y),GRID,1.0)
		draw_string(font,Vector2(0,y+4),str(value),HORIZONTAL_ALIGNMENT_RIGHT,LEFT-6,11,MUTED)
	var goal_y=_point(0,target).y
	draw_dashed_line(Vector2(area.position.x,goal_y),Vector2(area.end.x,goal_y),Color(TARGET,.6),1.0,5.0)
	draw_string(font,Vector2(area.position.x+4,goal_y-4),tr("Goal"),HORIZONTAL_ALIGNMENT_LEFT,-1,11,TARGET)
	# The first row is the start of play, after the settlements are placed.
	draw_string(font,Vector2(area.position.x,size.y-4),tr("Start"),HORIZONTAL_ALIGNMENT_LEFT,-1,11,MUTED)
	draw_string(font,Vector2(area.end.x-80,size.y-4),tr("Turn %d") % (history.size()-1),HORIZONTAL_ALIGNMENT_RIGHT,80,11,MUTED)
	if hover>=0:
		var x=_point(hover,0).x
		draw_line(Vector2(x,area.position.y),Vector2(x,area.end.y),Color(MUTED,.5),1.0)
	var ends=[]
	for p in names.size():
		var line=PackedVector2Array()
		for turn in history.size():
			if p<history[turn].size():line.append(_point(turn,history[turn][p]))
		if line.size()<2:continue
		var color: Color=colors[p]
		draw_polyline(line,color,2.0,true)
		ends.append({"at":line[-1],"player":p})
		if hover>=0 and hover<line.size():draw_circle(line[hover],4.0,color)
	# Labels at the end of each line, nudged apart where scores tie.
	ends.sort_custom(func(a,b):return a.at.y<b.at.y)
	var last_y=-INF
	for end in ends:
		var p: int=end.player
		draw_circle(end.at,5.0,Color("f4ead6"))
		draw_circle(end.at,4.0,colors[p])
		var y=maxf(end.at.y+4,last_y+13)
		last_y=y
		draw_string(font,Vector2(area.end.x+10,y),"%s %d" % [names[p],int(history[-1][p])],HORIZONTAL_ALIGNMENT_LEFT,RIGHT-12,12,INK)

func _gui_input(event):
	if event is InputEventMouseMotion and history.size()>=2:
		var area=_plot()
		var turn=clampi(roundi((event.position.x-area.position.x)/area.size.x*(history.size()-1)),0,history.size()-1)
		if turn!=hover:
			hover=turn
			queue_redraw()

func _notification(what):
	if what==NOTIFICATION_MOUSE_EXIT and hover>=0:
		hover=-1
		queue_redraw()

func _get_tooltip(_at: Vector2) -> String:
	if hover<0 or hover>=history.size():return ""
	var lines=[tr("Start") if hover==0 else tr("Turn %d") % hover]
	for p in names.size():
		if p<history[hover].size():lines.append("%s: %d" % [names[p],int(history[hover][p])])
	return "\n".join(lines)
