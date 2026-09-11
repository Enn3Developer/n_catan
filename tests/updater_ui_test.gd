extends SceneTree
var failures=0
func check(ok,message):
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await create_timer(.3).timeout
	check(CatanNetwork.PROTOCOL==CatanBuildInfo.PROTOCOL,"network uses build protocol")
	check(not game.updater.supported,"source editor is never replaced")
	game._open_updates()
	check(game.modal.name=="Updates","updates panel opens")
	check(game.modal.find_child("UpdateCheck",true,false).disabled,"source checkout disables update helper")
	game.updater.status={"state":"available","version":"v1.2.3","protocol":CatanBuildInfo.PROTOCOL+1,"kind":"delta","total":1048576}
	game._updates_changed()
	check(game.modal.find_child("UpdateDownload",true,false).visible,"available release offers download")
	check("changes multiplayer" in game.modal.find_child("UpdateDetails",true,false).text,"protocol change warning")
	game.updater.status={"state":"ready"};game.net.online=true;game._updates_changed()
	check(game.modal.find_child("UpdateInstall",true,false).disabled,"online room blocks install")
	check(not game.updater.install_update(true),"client independently blocks install during room")
	game.net.online=false;game.queue_free();await process_frame;await process_frame
	print("UPDATER_UI_TEST: ",failures," failures");quit(1 if failures else 0)
