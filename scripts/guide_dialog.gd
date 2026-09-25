extends CatanDialog
## The rules in short sections, with the building costs drawn from the rules
## themselves so the table never disagrees with the game. Sections that only
## apply to some games (paired turns, the archipelago, house rules) show only
## in those games.

const SETUP="Each player places two settlements, each with a road. The order reverses for the second round, and your second settlement collects 1 resource from each hex around it."
const TURN="Roll the dice. Every settlement next to a hex with that number collects 1 resource, every city 2. Then build, trade with players or the bank, and play at most one development card."
const TRADING="The bank takes 4 of one resource for 1 of another. A settlement or city on a 3:1 harbor lowers that to 3 for any resource, and one on a 2:1 harbor to 2 for the resource it shows. An offer to players goes to everyone at once: each one accepts, declines or sends a counter-offer, and you pick who to trade with."
const CARDS="Knight: move the robber and steal a resource.\nRoad building: place 2 roads for free.\nYear of plenty: take any 2 resources from the bank.\nMonopoly: every other player gives you all their cards of one resource.\nVictory point: worth 1 point, kept hidden until the game ends.\n\nYou can play one card per turn, before or after rolling, but not on the turn you bought it. Victory points count on their own."
const AWARDS="The longest unbroken road, at least 5 long, is worth 2 points. So is the largest army, at least 3 played knights. To take either one you have to beat the player who holds it; a tie leaves it where it is."
const SEVEN="Anyone holding more than seven resources discards half, rounded down. Then the roller moves the robber, which stops that hex producing, and steals a resource from a neighbor."
const PAIRED="The island is bigger, with 30 land hexes, and turns come in pairs. After the main turn, the player three seats ahead builds, plays cards and trades with the bank. Then the next main player rolls."
const ARCHIPELAGO="Smaller islands lie across the sea. Ships go on sea edges and cost 1 timber and 1 wool. A ship has to touch one of your buildings or continue a line of your ships; roads and ships only join at a building. Ships count toward the longest road, and the first settlement on each new island is worth 2 extra points."
const SAVED="Leaving saves the game. Resume saved game in the lobby picks it up. Friends rejoin with the new invite and get their seats back by name, and a bot plays for anyone not back yet."
const CONTROLS="Click glowing markers to build. Drag the board or hold WASD to pan, right-drag or Q/E to orbit and scroll to zoom. F focuses a tile, H hides the interface and Home fits the board."
const COSTS=[["Road","road"],["Settlement","settlement"],["City","city"],["Development card","buy_card"]]

func show_guide(state: Dictionary):
	var target=int(state.get("points_target",10))
	_section("How to win",tr("Reach %d points on your turn. Settlements give 1 point, cities 2, and the longest road and largest army 2 each. Victory point cards count too.") % target)
	_section("Setup",tr(SETUP))
	_section("A turn",tr(TURN))
	_heading("Building costs")
	_add_costs(state.get("island","")=="archipelago")
	_section("Trading",tr(TRADING))
	_section("Development cards",tr(CARDS))
	_section("Longest road and largest army",tr(AWARDS))
	_section("Rolling a seven",tr(SEVEN))
	if state.get("extension",false):_section("Five or six players",tr(PAIRED))
	if state.get("island","")=="archipelago":_section("Archipelago",tr(ARCHIPELAGO))
	var first_rule=true
	for rule in CatanRules.HOUSE_RULES:
		if not state.get(rule,false):continue
		if first_rule:_heading("House rules in this game")
		first_rule=false
		# The section already sits under the archipelago, so its sea rules drop that reminder.
		var text: String=tr(CatanRules.HOUSE_RULE_TEXT[rule][1]).trim_prefix(tr("Archipelago only.")+" ")
		_paragraph("%s: %s" % [tr(CatanRules.HOUSE_RULE_TEXT[rule][0]),text])
	_section("Saved games",tr(SAVED))
	_section("Controls",tr(CONTROLS))

func _heading(text: String):
	var heading=Label.new()
	heading.theme_type_variation=&"SectionLabel"
	heading.text=tr(text)
	heading.uppercase=true
	%Body.add_child(heading)

func _section(title: String,body: String):
	_heading(title)
	_paragraph(body)

func _paragraph(body: String):
	var text=Label.new()
	text.text=body
	text.auto_translate_mode=Node.AUTO_TRANSLATE_MODE_DISABLED
	text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x=200
	%Body.add_child(text)

func _add_costs(ships: bool):
	var table=GridContainer.new()
	table.columns=2
	table.add_theme_constant_override("h_separation",24)
	table.add_theme_constant_override("v_separation",6)
	%Body.add_child(table)
	for item in COSTS+([["Ship","ship"]] if ships else []):
		var name_label=Label.new()
		name_label.text=tr(item[0])
		table.add_child(name_label)
		CatanIcons.resources(table,CatanRules.COST[item[1]],24)
