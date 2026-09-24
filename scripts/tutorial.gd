class_name CatanTutorial
extends RefCounted
const LESSONS=[
	{"title":"Welcome to your first island","body":"Reach 10 victory points by building settlements and cities. Resources come from the land around them. This guided expedition lets you try each core action, with a fresh practice board for later lessons.","action":""},
	{"title":"Find a home","body":"Click a glowing corner to place a settlement. Adjacent numbered hexes supply your resources. 6 and 8 produce often; varied terrain gives you more options. Keep at least two edges between settlements.","action":"settlement"},
	{"title":"Connect your settlement","body":"Click a glowing edge beside your settlement to place a road. Roads connect your future buildings. Opening placements are free; later roads cost 1 timber + 1 brick. Everyone places twice, reversing order for the second round.","action":"road"},
	{"title":"Let the island provide","body":"Click Roll dice. This practice roll will produce resources beside one of your settlements. A settlement collects 1 resource, a city 2. Everyone collects on every player's roll, not just their own turn.","action":"roll"},
	{"title":"Grow a city","body":"Practice resources are provided. Click City, then one of your settlements. An upgrade costs 2 grain + 3 ore, is worth 2 points in total, and doubles its production. New settlements cost timber, brick, wool and grain, and must connect to your road.","action":"city"},
	{"title":"Trade for what you need","body":"Open Trade resources and exchange with the bank. Usually 4 of one resource buys 1 of another. A 3:1 harbor improves every trade; a 2:1 harbor improves its pictured resource. In a real game you can also offer a trade to other players.","action":"bank_trade"},
	{"title":"Meet the robber","body":"Click a different hex to move the robber. Its hex stops producing. You may then steal one random resource from a neighboring opponent. Rolling 7 also makes everyone holding more than 7 cards choose half to discard.","action":"robber"},
	{"title":"Play a development card","body":"Open Development cards and play the supplied Knight. Knights move the robber and build your army. Other cards grant roads, resources, a monopoly or hidden points. Newly bought action cards wait a turn; play only one per turn.","action":"play_card"},
	{"title":"Turn your plans into victory","body":"Settlements give 1 point; cities give 2. The longest continuous road (at least 5) and largest army (at least 3 knights) give 2 each. Hidden point cards also count. Reach 10 on your turn to win. End turn when you finish building and trading.","action":""},
	{"title":"You're ready to set sail","body":"Choose Easy bots for a gentle first game, Normal for purposeful builders, or Hard for opponents that plan resource diversity and expansion. You can mix difficulty levels in the lobby. The reference guide remains available during every game.","action":""}
]
var step=0
var completed=false
func current() -> Dictionary: return LESSONS[step]
func load_lesson(net: CatanNetwork,pname: String):
	completed=current().action==""
	net.tutorial=true
	net.tutorial_expected=current().action if not completed else "completed"
	net.started=true
	if step==2 and net.rules.s.get("phase","")=="setup_road":
		net._sync()
		return
	net.rules.create([pname,"Guide"],8426)
	var brain=CatanBot.new(71)
	if step==2:
		net.rules.apply(0,brain.choose(net.rules.snapshot(0),0,1))
	elif step>=3:
		while str(net.rules.s.phase).begins_with("setup"):
			var p=net.rules.s.turn
			net.rules.apply(p,brain.choose(net.rules.snapshot(p),p,1))
		if step==3:
			var roll=5
			for v in net.rules.s.vertices:
				if v.owner==0:
					for tile in v.tiles:
						if net.rules.s.tiles[tile].kind<5: roll=net.rules.s.tiles[tile].number
			net.rules.force_roll(roll)
		else:
			net.rules.s.rolled=true
			# Tutorial-only grants come from the bank and are clearly described in the lesson.
			for res in 5:
				var amount=mini(6-net.rules.s.players[0].hand[res],net.rules.s.bank[res])
				net.rules.s.players[0].hand[res]+=amount
				net.rules.s.bank[res]-=amount
			if step==6: net.rules.s.phase="robber"
			if step==7: net.rules.s.players[0].cards[0]=1
	net.rules._log(CatanI18n.message("Practice lesson: %s",[CatanI18n.term(current().title)]))
	net._sync()
func observe(action: Dictionary,net: CatanNetwork):
	if str(action.get("type",""))==current().action:
		completed=true
		net.tutorial_expected="completed"
