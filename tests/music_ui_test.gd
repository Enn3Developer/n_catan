extends SceneTree
var game
var checks=0
var failures=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func settle():await create_timer(.25).timeout
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await settle()
	check(game._node("OpenMusic")!=null,"music accessible from main menu")
	game._open_music();await settle()
	check(game.music_dialog_widgets.tracks.size()==5,"library lists all five tracks")
	game.music_dialog_widgets.tracks[2].pressed.emit();await settle()
	check(game.net.music_state().track==2 and "Trade Winds" in game.music_dialog_widgets.title.text,"playlist selection changes track and label")
	game.music_dialog_widgets.toggle.pressed.emit();await settle()
	check(game.net.music_state().paused and game.audio.music.stream_paused,"pause control pauses soundtrack")
	game._toggle_music_mute();await settle()
	check(game.preferences.values.music==0 and game.net.music_state().paused,"mute is independent of shared transport")
	game._toggle_music_mute();game._close_modal();game._solo();game.net.start_game();game.net.paused=true;await settle()
	check(game._node("OpenMusic")!=null and game._node("TopBody").is_ancestor_of(game._node("OpenMusic")),"music opens from the top navigation")
	check(game._node("MusicBody")==null,"playback controls do not occupy the game HUD")
	game._node("OpenMusic").pressed.emit();game.net._sync();await settle()
	check(is_instance_valid(game.modal) and game.modal.name=="MusicLibrary","library stays open across game updates")
	game.net.music_control("select",1);await settle()
	check("Sunlit Fields" in game.music_dialog_widgets.title.text,"music screen refreshes across track changes")
	game._set_music_volume(.23);await settle()
	check(is_equal_approx(game.music_dialog_widgets.volume.value,.23),"music screen reflects personal volume")
	for dimensions in [Vector2i(800,600),Vector2i(1440,900)]:
		root.size=dimensions;game._queue_layout();await settle()
		var bounds=Rect2(Vector2.ZERO,Vector2(dimensions))
		check(bounds.encloses(game._node("OpenMusic").get_global_rect()),"top music button fits "+str(dimensions))
		check(bounds.encloses(game.modal.find_child("DialogScroll",true,false).get_global_rect()),"music library fits "+str(dimensions))
	game._close_modal();game.net.leave();game.queue_free();await create_timer(.2).timeout;await process_frame;await process_frame
	print("MUSIC_UI_TEST: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
