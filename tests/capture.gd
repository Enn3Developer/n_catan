extends SceneTree
func _initialize():
	call_deferred("capture")
func capture():
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(2).timeout
	print("CAPTURE_TREE ",game.get_child_count())
	root.get_texture().get_image().save_png("/tmp/catan-home.png")
	var rules=CatanRules.new()
	var data=rules.create(["Avery","Morgan","Rowan"],8426)
	game.net.seat=0
	game.net.roster=[{"name":"Avery","connected":true},{"name":"Morgan","connected":true},{"name":"Rowan","connected":true}]
	game._received(rules.snapshot(0))
	await create_timer(2).timeout
	root.get_texture().get_image().save_png("/tmp/catan-board.png")
	# Capture a developed island and its architecture as a visual regression fixture.
	while rules.s.phase.begins_with("setup"):
		var action={}
		if rules.s.phase=="setup_settlement":
			for v in 54:
				if rules.valid_vertex(rules.s.turn,v,true):
					action={"type":"settlement","id":v}
					break
		else:
			for e in 72:
				if rules.valid_edge(rules.s.turn,e,true):
					action={"type":"road","id":e}
					break
		rules.apply(rules.s.turn,action)
	rules.s.rolled=true
	rules.s.dice=[3,5]
	rules.s.players[0].hand=[4,3,2,5,3]
	for v in rules.s.vertices:
		if v.owner==0: v.level=2
	rules._score()
	game._received(rules.snapshot(0))
	await create_timer(1).timeout
	root.get_texture().get_image().save_png("/tmp/catan-playing.png")
	game._cards()
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png("/tmp/catan-cards.png")
	game._close_modal()
	# A lower-angle close-up illustrates the 3D assets without interface obstruction.
	game.screen.hide()
	game.board.camera.position=Vector3(8,7,11)
	game.board.camera.look_at(Vector3.ZERO)
	game.board.camera.fov=40
	await create_timer(0.5).timeout
	root.get_texture().get_image().save_png("/tmp/catan-world.png")
	print("CAPTURE_DONE")
	quit()
