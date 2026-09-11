extends SceneTree
var failures=0
var actions=0
func _initialize(): call_deferred("run")
func run():
	for game in 6:
		var rules=CatanRules.new()
		var names=["One","Two","Three","Four","Five","Six"]
		if game%2==0: names.pop_back()
		rules.create(names,711+game*191)
		var brains=[]
		for p in rules.s.players.size(): brains.append(CatanBot.new(game*121+p+1))
		var steps=0
		var turns=0
		while rules.s.winner==-1 and steps<6000:
			steps+=1
			var p=rules.s.turn
			if rules.s.phase=="discard": p=int(rules.s.discards.keys()[0])
			var difficulty=game/2
			var snapshot=rules.snapshot(p)
			var action=brains[p].choose(snapshot,p,int(difficulty))
			if action.get("type","")=="end": turns+=1
			var err=rules.apply(p,action)
			if not err.is_empty():
				printerr("BOT_ILLEGAL game=",game," step=",steps," phase=",rules.s.phase," action=",action," error=",err)
				failures+=1
				break
			for res in 5:
				var total=rules.s.bank[res]
				for player in rules.s.players: total+=player.hand[res]
				if total!=24: failures+=1; printerr("Resource imbalance")
		if rules.s.winner<0:
			failures+=1
			printerr("BOT_GAME_STALLED ",game," steps=",steps," points=",rules.s.players.map(func(p):return p.points))
		else: print("BOT_GAME_PASS ",game," winner=",rules.s.winner," turns=",turns," actions=",steps)
		actions+=steps
	print("BOT_TEST: 6 extension games, ",actions," actions, ",failures," failures")
	quit(1 if failures else 0)
