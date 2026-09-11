extends SceneTree
var game
var failures=0
var checks=0
func check(ok,message):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func shot(label):
	for i in 5:await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/catan-ui-"+label+".png")
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await create_timer(.6).timeout
	game._solo();game.net.start_game();game.net.paused=true
	await process_frame
	game.set_process(false)
	var original=load("res://assets/ui_theme.tres").get_color("font_color","Label")
	var theme=game.ui_day_night
	var label=game._label(game.ui,"Palette probe",16,game.INK)
	label.hide()
	theme.advance(1,0)
	var day=label.get_theme_color("font_color")
	check(day.is_equal_approx(game.INK),"daytime palette preserved")
	await shot("day")
	theme.advance(0,.231049)
	check(theme.amount>.49 and theme.amount<.51,"abrupt night change fades progressively")
	check(label.get_theme_color("font_color")!=day,"custom labels fade with theme")
	await shot("dusk")
	game.board.day_seconds=450;game.board.advance_day(0)
	theme.advance(0,5)
	check(theme.amount==1,"night palette settles")
	check(game.screen.theme==null,"authored screens inherit live theme")
	check(label.get_theme_color("font_color").is_equal_approx(Color("eee5d2")),"night labels are light")
	await shot("night")
	game._open_settings()
	theme.advance(0,0)
	await shot("settings-night")
	var fresh=game._label(game.ui,"New label",16,game.INK);fresh.hide()
	var semantic=game._label(game.ui,"Player",16,Color("df6252"));semantic.hide()
	theme.advance(0,0)
	check(fresh.get_theme_color("font_color")==label.get_theme_color("font_color"),"new controls inherit active night palette")
	check(semantic.get_theme_color("font_color").is_equal_approx(Color("df6252")),"semantic colors remain unchanged")
	var toggle=game.modal.controls.day_night_cycle
	toggle.button_pressed=false
	check(not game.preferences.values.day_night_cycle and game.board.daylight==1,"settings toggle immediately applies daylight")
	theme.advance(game.board.daylight,5)
	check(theme.amount==0,"disabled cycle restores daytime interface")
	await shot("cycle-disabled")
	toggle.button_pressed=true
	check(game.board.daylight==0,"enabling cycle returns to current world time")
	theme.advance(game.board.daylight,5)
	game._close_modal()
	theme.advance(1,.231049)
	check(theme.amount>.49 and theme.amount<.51,"dawn also fades progressively")
	theme.advance(1,5)
	check(label.get_theme_color("font_color").is_equal_approx(day),"dawn restores exact day palette")
	check(load("res://assets/ui_theme.tres").get_color("font_color","Label").is_equal_approx(original),"source theme stays immutable")
	game.queue_free();await process_frame
	print("UI_DAY_NIGHT_TEST: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
