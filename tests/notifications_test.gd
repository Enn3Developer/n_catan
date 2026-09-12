extends SceneTree
var failures=0
var checks=0
var game
func check(ok,message):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func text(key):
	return game.notifications.cards[key].find_children("*","Label",true,false)[0].text
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await create_timer(.3).timeout
	game.updater.status={"state":"available","version":"v1.2.3"};game._updates_changed()
	check(game.notifications.cards.has("update"),"available update notifies without opening dialog")
	var card=game.notifications.cards.update
	game._updates_changed();check(game.notifications.cards.update==card,"repeated update status does not recreate alert")
	game.notifications.dismiss("update");game._updates_changed()
	check(not game.notifications.cards.has("update"),"dismissed update stays dismissed")
	game.updater.status={"state":"ready","version":"v1.2.3"};game._updates_changed()
	check(game.notifications.cards.has("update"),"download completion has its own notification")
	game.notifications.dismiss("update")
	game._solo();game.net.start_game();game.net.paused=true
	var r=game.net.rules
	r.s.phase="play";r.s.rolled=true;r.s.turn=1
	r.s.players[1].hand=[4,0,0,0,0];r.s.players[0].hand=[0,4,0,0,0]
	game.net._sync()
	check(r.apply(1,{"type":"offer_trade","give":[2,0,0,0,0],"receive":[0,1,0,0,0]})=="","offer accepted by rules")
	game.net._sync()
	check(game.notifications.cards.has("trade") and "offers" in text("trade"),"incoming offer notifies from snapshot")
	card=game.notifications.cards.trade;game.net._sync()
	check(game.notifications.cards.trade==card,"duplicate snapshots do not recreate offer")
	var review=card.find_children("*","Button",true,false)[0];review.pressed.emit()
	check(is_instance_valid(game.modal) and not game.notifications.cards.has("trade"),"review opens offer and dismisses notification")
	game._close_modal();game.net._sync()
	check(not game.notifications.cards.has("trade"),"viewed offer stays dismissed on sync")
	check(r.apply(0,{"type":"accept_trade"})=="","trade accepted")
	game.net._sync()
	check(game.notifications.cards.has("trade_result") and "completed" in text("trade_result"),"recipient sees completed trade")
	game.notifications.dismiss("trade_result");game.net._sync()
	check(not game.notifications.cards.has("trade_result"),"completion not repeated")
	r.apply(1,{"type":"offer_trade","give":[1,0,0,0,0],"receive":[0,1,0,0,0]});game.net._sync()
	r.apply(1,{"type":"cancel_trade"});game.net._sync()
	check(not game.notifications.cards.has("trade") and "withdrew" in text("trade_result"),"withdrawal removes offer and notifies")
	game._home()
	check(not game.notifications.cards.has("trade_result"),"leaving game clears trade alerts")
	game.notifications.show_notice("expiry","Expires automatically")
	check(is_equal_approx(game.notifications.cards.expiry.get_child(1).wait_time,5),"default notification lifetime is five seconds")
	game.notifications.show_notice("replace","Old", "",Callable(),.1)
	await create_timer(.06).timeout
	game.notifications.show_notice("replace","New", "",Callable(),.2)
	await create_timer(.08).timeout
	check(game.notifications.cards.has("replace"),"old timeout does not remove replacement")
	await create_timer(.2).timeout
	check(not game.notifications.cards.has("replace"),"replacement expires on its own timer")
	await create_timer(4.8).timeout
	check(not game.notifications.cards.has("expiry"),"default notification disappears automatically")
	game.net.leave();game.queue_free();await create_timer(.2).timeout;await process_frame;await process_frame
	print("NOTIFICATIONS_TEST: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
