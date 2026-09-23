class_name CatanMeshKit
extends RefCounted
## Collects vertex-colored triangles for procedural pieces. Faces orient themselves
## from an outward hint, so callers never reason about winding order.

var vertices=PackedVector3Array()
var normals=PackedVector3Array()
var colors=PackedColorArray()
var xform=Transform3D.IDENTITY
var stack: Array[Transform3D]=[]
var rng=RandomNumberGenerator.new()

func push(local: Transform3D):
	stack.append(xform)
	xform=xform*local

func pop():
	xform=stack.pop_back()

func is_empty() -> bool:
	return vertices.is_empty()

## A random tint of a base color, for stones, tiles and planks that should not match.
func vary(color: Color,amount: float) -> Color:
	var shade=rng.randf_range(-amount,amount)
	var tinted=color.lightened(shade) if shade>0 else color.darkened(-shade)
	tinted.h=fposmod(tinted.h+rng.randf_range(-amount,amount)*.08,1.0)
	return tinted

func _emit(a: Vector3,b: Vector3,c: Vector3,na: Vector3,nb: Vector3,nc: Vector3,color: Color):
	# Godot treats clockwise triangles as front faces.
	vertices.append(a);vertices.append(c);vertices.append(b)
	normals.append(na);normals.append(nc);normals.append(nb)
	colors.append(color);colors.append(color);colors.append(color)

## A flat convex polygon in local space, facing away from `inside`.
func polygon(points: Array,color: Color,inside: Vector3):
	var world=[]
	for p in points:world.append(xform*p)
	var center=xform*inside
	var normal=Vector3.ZERO
	for i in world.size():
		var current: Vector3=world[i]
		var following: Vector3=world[(i+1)%world.size()]
		normal+=Vector3((current.y-following.y)*(current.z+following.z),(current.z-following.z)*(current.x+following.x),(current.x-following.x)*(current.y+following.y))
	if normal.length_squared()<1e-16:return
	normal=normal.normalized()
	var centroid=Vector3.ZERO
	for p in world:centroid+=p
	centroid/=world.size()
	if normal.dot(centroid-center)<0:
		world.reverse();normal=-normal
	for i in range(1,world.size()-1):
		_emit(world[0],world[i],world[i+1],normal,normal,normal,color)

const HEXA_FACES=[[0,1,2,3],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]]

## Eight corners: bottom ring 0-3, top ring 4-7 directly above. `hidden` lists faces
## (0 bottom, 1 top, then the four sides) that sit against something and are skipped.
func hexa(p: Array,color: Color,hidden: Array=[]):
	var center=Vector3.ZERO
	for point in p:center+=point
	center/=8.0
	for i in 6:
		if i in hidden:continue
		var face=HEXA_FACES[i]
		polygon([p[face[0]],p[face[1]],p[face[2]],p[face[3]]],color,center)

## A block set into a surface: its back and bottom faces are never drawn.
func stone(center: Vector3,size: Vector3,color: Color,outward: Vector3):
	var back=2 if outward.z>.5 else 4 if outward.z<-.5 else 5 if outward.x>.5 else 3
	box(center,size,color,0.0,[0,back])

func box(center: Vector3,size: Vector3,color: Color,yaw: float=0.0,hidden: Array=[]):
	var h=size*.5
	var basis=Basis(Vector3.UP,yaw)
	var p=[]
	for y in [-h.y,h.y]:
		for corner in [Vector2(-h.x,-h.z),Vector2(h.x,-h.z),Vector2(h.x,h.z),Vector2(-h.x,h.z)]:
			p.append(center+basis*Vector3(corner.x,y,corner.y))
	hexa(p,color,hidden)

## A square-section timber or stone run between two points.
func beam(a: Vector3,b: Vector3,width: float,height: float,color: Color,up: Vector3=Vector3.UP):
	var along=b-a
	if along.length_squared()<1e-12:return
	var side=along.cross(up)
	if side.length_squared()<1e-10:side=along.cross(Vector3.RIGHT)
	side=side.normalized()*width*.5
	var lift=side.cross(along).normalized()*height*.5
	hexa([a-side-lift,a+side-lift,b+side-lift,b-side-lift,a-side+lift,a+side+lift,b+side+lift,b-side+lift],color)

## A tile laid on a surface: four corners plus an outward thickness.
## Corners run eave-left, eave-right, top-right, top-left. A shingle keeps only its
## top and eave faces; the rest hide under its neighbours.
func slab(corners: Array,normal: Vector3,thickness: float,color: Color,shingle: bool=false):
	var up=normal.normalized()*thickness
	hexa([corners[0],corners[1],corners[2],corners[3],corners[0]+up,corners[1]+up,corners[2]+up,corners[3]+up],color,[0,3,4,5] if shingle else [])

## A convex 2D outline extruded along `depth`, drawn in the plane given by `u` and `v`.
func plate(outline: Array,origin: Vector3,u: Vector3,v: Vector3,depth: Vector3,color: Color):
	var front=[];var back=[]
	for point in outline:
		var at=origin+u*point.x+v*point.y
		front.append(at+depth*.5);back.append(at-depth*.5)
	var center=origin+u*_mean(outline).x+v*_mean(outline).y
	polygon(front,color,center);polygon(back,color,center)
	for i in outline.size():
		var j=(i+1)%outline.size()
		polygon([front[i],front[j],back[j],back[i]],color,center)

func _mean(points: Array) -> Vector2:
	var sum=Vector2.ZERO
	for p in points:sum+=p
	return sum/maxf(1,points.size())

## A smooth-sided frustum; zero top radius makes a cone.
func cylinder(base: Vector3,bottom_radius: float,top_radius: float,height: float,sides: int,color: Color,caps: bool=true,top_color: Variant=null):
	var normal_basis=xform.basis.inverse().transposed()
	var slope=(bottom_radius-top_radius)/maxf(height,.0001)
	var top=base+Vector3.UP*height
	for i in sides:
		var a0=TAU*i/sides;var a1=TAU*(i+1)/sides
		var d0=Vector3(cos(a0),0,sin(a0));var d1=Vector3(cos(a1),0,sin(a1))
		var n0=(normal_basis*(d0+Vector3.UP*slope)).normalized()
		var n1=(normal_basis*(d1+Vector3.UP*slope)).normalized()
		var b0=xform*(base+d0*bottom_radius);var b1=xform*(base+d1*bottom_radius)
		var t0=xform*(top+d0*top_radius);var t1=xform*(top+d1*top_radius)
		var outward=(n0+n1).normalized()
		var face=(b1-b0).cross(t0-b0)
		if face.dot(outward)>=0:
			_emit(b0,b1,t0,n0,n1,n0,color)
			if top_radius>=.0001:_emit(b1,t1,t0,n1,n1,n0,color)
		else:
			_emit(b0,t0,b1,n0,n0,n1,color)
			if top_radius>=.0001:_emit(b1,t0,t1,n1,n0,n1,color)
	if not caps:return
	var inside=base+Vector3.UP*height*.5
	if top_radius>=.0001:polygon(_ring(top,top_radius,sides),top_color if top_color!=null else color,inside)
	if bottom_radius>=.0001:polygon(_ring(base,bottom_radius,sides),color,inside)

func _ring(center: Vector3,radius: float,sides: int) -> Array:
	var points=[]
	for i in sides:points.append(center+Vector3(cos(TAU*i/sides),0,sin(TAU*i/sides))*radius)
	return points

## A cylinder lying between two points, used for logs, rope and sails' spars.
func rod(a: Vector3,b: Vector3,radius: float,sides: int,color: Color):
	var along=b-a
	if along.length_squared()<1e-12:return
	var y=along.normalized()
	var x=y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD))<.9 else Vector3.RIGHT).normalized()
	push(Transform3D(Basis(x,y,x.cross(y)),a))
	cylinder(Vector3.ZERO,radius,radius,along.length(),sides,color)
	pop()

## A squashed low-poly sphere for foliage, thatch lumps and flowers.
func blob(center: Vector3,radius: Vector3,color: Color,segments: int=6,rings: int=4):
	var normal_basis=xform.basis.inverse().transposed()
	var point=func(ring: int,segment: int) -> Array:
		var theta=PI*ring/rings;var phi=TAU*segment/segments
		var unit=Vector3(sin(theta)*cos(phi),cos(theta),sin(theta)*sin(phi))
		return [xform*(center+unit*radius),(normal_basis*(unit/radius)).normalized()]
	for r in rings:
		for s in segments:
			var a=point.call(r,s);var b=point.call(r,s+1);var c=point.call(r+1,s+1);var d=point.call(r+1,s)
			var outward=(a[1]+c[1]).normalized()
			for tri in [[a,b,c],[a,c,d]]:
				var face=(tri[1][0]-tri[0][0]).cross(tri[2][0]-tri[0][0])
				if face.length_squared()<1e-16:continue
				if face.dot(outward)>=0:_emit(tri[0][0],tri[1][0],tri[2][0],tri[0][1],tri[1][1],tri[2][1],color)
				else:_emit(tri[0][0],tri[2][0],tri[1][0],tri[0][1],tri[2][1],tri[1][1],color)

func arrays() -> Array:
	var arrays=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_COLOR]=colors
	return arrays

func mesh(material: Material) -> ArrayMesh:
	if is_empty():return null
	var result=ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays())
	result.surface_set_material(0,material)
	return result
