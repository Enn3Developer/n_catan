extends CatanDialog
## The rules in short sections, with the building costs drawn from the rules
## themselves so the table never disagrees with the game.

const SECTIONS=[
	["How to win","Reach the room's points target on your turn, 10 unless the host changes it. Settlements give 1 point, cities 2, and longest road and largest army 2 each."],
	["Setup","Each player places two settlements, each with a road. The order reverses for the second round."],
	["A turn","Roll the dice. Every settlement next to a hex with that number collects 1 resource, every city 2. Then build, trade with players or the bank, and play at most one development card. Ports give better bank rates."],
	["Building costs",""],
	["Rolling a seven","Anyone holding more than seven resources discards half, rounded down. Then the roller moves the robber, which stops that hex producing, and steals a resource from a neighbor."],
	["Controls","Click glowing markers to build. Drag the board or hold WASD to pan, right-drag or Q/E to orbit and scroll to zoom. F focuses a tile, H hides the interface and Home fits the board."],
	["Five or six players","The island has 30 hexes and turns come in pairs. After the main turn, the player three seats ahead builds, plays cards and trades with the bank. Then the next main player rolls."],
	["Hosting online","The host's UDP port 24567 must be reachable from the internet. Use router mapping, port forwarding or a dedicated server."],
]
const COSTS=[["Road","road"],["Settlement","settlement"],["City","city"],["Development card","buy_card"]]

func _ready():
	for section in SECTIONS:
		var heading=Label.new()
		heading.theme_type_variation=&"SectionLabel"
		heading.text=tr(section[0])
		heading.uppercase=true
		%Body.add_child(heading)
		if section[1].is_empty():
			_add_costs()
			continue
		var text=Label.new()
		text.text=tr(section[1])
		text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x=200
		%Body.add_child(text)

func _add_costs():
	var table=GridContainer.new()
	table.columns=2
	table.add_theme_constant_override("h_separation",24)
	table.add_theme_constant_override("v_separation",6)
	%Body.add_child(table)
	for item in COSTS:
		var name_label=Label.new()
		name_label.text=tr(item[0])
		table.add_child(name_label)
		CatanIcons.resources(table,CatanRules.COST[item[1]],24)
