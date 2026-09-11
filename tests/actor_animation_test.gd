extends SceneTree
var world=preload("res://scripts/living_world.gd").new()
var art=CatanTileArt.new()
var failures=0
var checks=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func entry(actor: Dictionary,kind: int) -> Dictionary:
	root.add_child(actor.root)
	actor.merge({"origin":Vector2.ZERO,"home":Vector2(.25,-.30),"kind":kind,"phase":0.0})
	return actor
func run():
	var sheep=entry(world.sheep(),2)
	world.animate([sheep],8,art)
	var position=sheep.root.position;var legs=sheep.limbs.map(func(l):return l.rotation)
	world.animate([sheep],10,art)
	check(sheep.root.position==position,"grazing sheep stay at their patch")
	check(sheep.limbs.map(func(l):return l.rotation)==legs,"grazing feet stay still")
	check(sheep.head.rotation.x<-.9,"grazing lowers the muzzle")
	world.animate([sheep],2,art)
	check(sheep.root.position.distance_to(position)>.02,"walking changes position")
	check(sheep.limbs.map(func(l):return l.rotation)!=legs,"walking articulates legs")
	for boundary in [6.0,16.0,22.0,32.0]:
		world.animate([sheep],boundary-.001,art)
		var before=sheep.root.transform
		world.animate([sheep],boundary+.001,art)
		check(before.origin.distance_to(sheep.root.position)<.0001,"no jump between patches")
		check(before.basis.is_equal_approx(sheep.root.basis),"continuous heading at path boundary")
	world.animate([sheep],8,art,0)
	var sleeping=sheep.root.transform
	var sleeping_leg=sheep.limbs[0].transform
	world.animate([sheep],20,art,0)
	check(sheep.root.transform==sleeping and sheep.limbs[0].transform==sleeping_leg,"sleeping sheep do not spin or step")
	check(sheep.root.scale==Vector3.ONE and sheep.body.position.y<.06,"rest lowers body without squashing model")
	sheep.root.free()
	for kind in [0,1,3,4,5]:
		var actor=entry(world.worker(kind,kind==5),kind)
		var worst_grip=0.0
		for frame in 180:
			world.animate([actor],frame/15.0,art)
			for i in 2:
				var hand=actor.elbows[i].global_transform*Vector3(0,-.043,0)
				var grip=actor.tool.global_transform*actor.grips[i]
				worst_grip=maxf(worst_grip,hand.distance_to(grip))
		check(worst_grip<.002,"hands follow handle for kind %d (error %.5f)"%[kind,worst_grip])
		if kind in [0,1,4]:
			world.animate([actor],2.2/.88,art)
			var tip=Vector3(0,.084,-.038) if kind==0 else Vector3(0,.069,-.052)
			var contact=actor.root.global_transform*Vector3(0,.044 if kind==0 else .0345,-.14)
			check((actor.tool.global_transform*tip).distance_to(contact)<.0001,"cutting edge reaches work surface for kind %d"%kind)
			world.animate([actor],1.7/.88,art)
			check((actor.tool.global_transform*tip).y>actor.root.global_position.y+.23,"head clears worker on lift")
			world.animate([actor],2.08/.88,art)
			var before=actor.tool.global_transform*tip
			world.animate([actor],2.11/.88,art)
			check((actor.tool.global_transform*tip).y<before.y,"point descends into contact")
		actor.root.free()
	print("ACTOR_ANIMATION_TEST: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
