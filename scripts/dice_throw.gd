class_name CatanDiceThrow
extends Node3D
signal settled(total: int)
var dice=[]
var results=[]
var age=0.0
var duration=1.65
var landing=Vector3.ZERO
var reduced=false
var done=false
const NORMALS=[Vector3.UP,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.DOWN]
const PIPS=[[[0,0]],[[-1,-1],[1,1]],[[-1,-1],[0,0],[1,1]],[[-1,-1],[1,-1],[-1,1],[1,1]],[[-1,-1],[1,-1],[0,0],[-1,1],[1,1]],[[-1,-1],[-1,0],[-1,1],[1,-1],[1,0],[1,1]]]

func setup(values: Array,target: Vector3,reduce: bool):
	results=values.duplicate();landing=target;reduced=reduce
	for i in 2:
		var die=Node3D.new();add_child(die)
		var body=MeshInstance3D.new();body.mesh=CatanMiniature.bevel_box(Vector3.ONE*.56)
		var ivory=StandardMaterial3D.new();ivory.albedo_color=Color("f4e8ce") if i==0 else Color("d98760");ivory.roughness=.32
		body.material_override=ivory;die.add_child(body)
		for face in 6:
			var normal=NORMALS[face]
			var u=normal.cross(Vector3.UP if absf(normal.y)<.9 else Vector3.FORWARD).normalized()
			var v=normal.cross(u)
			for xy in PIPS[face]:
				var dot=MeshInstance3D.new();var sphere=SphereMesh.new();sphere.radius=.043;sphere.height=.086;sphere.radial_segments=12;sphere.rings=6;dot.mesh=sphere
				dot.position=normal*.265+u*xy[0]*.135+v*xy[1]*.135
				var ink=StandardMaterial3D.new();ink.albedo_color=Color("172c36");ink.roughness=.8;dot.material_override=ink;die.add_child(dot)
		var finish=Basis(Vector3.UP,.22 if i==0 else -.28)*Basis(Quaternion(NORMALS[int(values[i])-1],Vector3.UP))
		dice.append({"node":die,"end":target+Vector3((i-.5)*.8,0,0),"basis":finish})
	_update_pose(1.0 if reduced else 0.0)

func _update_pose(t: float):
	for i in dice.size():
		var entry=dice[i]
		var travel=1.0-pow(1.0-t,2)
		entry.node.position=entry.end+Vector3(-3.8*(1-travel),0,1.8*(1-travel))
		# A throw followed by two smaller rebounds, ending exactly on the map.
		var height=0.0
		if t<.6:height=3.8*sin(PI*t/.6)+2.0*(1.0-t/.6)
		elif t<.83:height=.65*sin(PI*(t-.6)/.23)
		else:height=.18*sin(PI*(t-.83)/.17)
		entry.node.position.y+=maxf(0,height)
		var spin=Basis.from_euler(Vector3(1.0,.6,.4)*(1-t)*TAU*2)
		entry.node.basis=spin*entry.basis

func _process(delta):
	age+=delta
	if not done:
		_update_pose(1.0 if reduced else minf(1,age/duration))
		if reduced or age>=duration:
			done=true;settled.emit(int(results[0])+int(results[1]))
	if age>duration+3.5:queue_free()
