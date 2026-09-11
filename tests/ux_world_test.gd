extends SceneTree
var game
var checks=0
var failures=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await create_timer(.5).timeout
	game._solo();game.net.start_game();game.net.paused=true
	var r=game.net.rules
	r.s.phase="play";r.s.rolled=true;r.s.turn=0
	r.s.players[0].hand=[10,10,10,10,10]
	r.s.players[0].cards=[1,0,0,0,2];r.s.players[0].new_cards=[0,1,0,0,1]
	r._score();game.net._sync()
	check("3 total" in game._node("PlayerChip0").tooltip_text,"score tooltip includes old and newly bought victory cards")
	check(game._node("Card4").text=="Victory 3","victory cards always visible")
	check(not game._node("Card0").disabled and game._node("Card1").disabled,"ready and new action cards distinguished")
	check(game._node("SettlementAction").disabled,"affordable settlement disabled with no connected location")
	r.s.edges[0].owner=0;game.net._sync()
	check(not game._node("SettlementAction").disabled,"settlement enabled when a legal site opens")
	var before=r.s.players[0].hand.duplicate()
	check(not r.apply(0,{"type":"settlement","id":-1}).is_empty() and r.s.players[0].hand==before,"invalid placement cannot spend resources")
	for v in r.s.vertices:v.owner=1;v.level=1
	game.net._sync();check(game._node("SettlementAction").disabled,"occupied board disables settlement")
	r.s.card_played=true;game.net._sync();check(game._node("Card0").disabled,"one action card per turn")
	r.s.turn=1;game.net._sync();check(game._node("BuyCard").disabled,"cannot buy cards on another player's turn")
	var view=r.snapshot(0);var scoring=CatanRules.new();scoring.s=view
	check(scoring.visible_points(1)==view.players[1].points,"opponents hidden cards do not leak")
	game.board.day_seconds=150;game.board.advance_day(0)
	var day=game.board.get_node("Sun").light_energy
	game.board.advance_day(300);var night=game.board.get_node("Sun").light_energy
	check(night<day and night>.2,"night visibly darker but playable")
	game.board.advance_day(300);check(is_equal_approx(day,game.board.get_node("Sun").light_energy),"full day repeats after exactly 600 seconds")
	var frozen=game.board.day_seconds;game._process(10);check(game.board.day_seconds==frozen,"solo pause freezes day clock")
	game.board.reduce_motion=false
	game.board.throw_dice([2,6]);var thrown=game.board.active_dice
	await create_timer(1.8).timeout
	check(thrown.done,"dice throw completes")
	for i in 2:
		check((thrown.dice[i].node.basis*CatanDiceThrow.NORMALS[thrown.results[i]-1]).dot(Vector3.UP)>.999,"upper face matches server die result")
	game.board.reduce_motion=true;game.board.throw_dice([1,3]);await process_frame;await process_frame
	check(game.board.active_dice.done,"reduced motion shows result immediately")
	game.net.leave();game.queue_free();await create_timer(.2).timeout;await process_frame
	print("UX_WORLD_TEST: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
