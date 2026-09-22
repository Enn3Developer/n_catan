@tool
class_name CatanMiniature
extends RefCounted
# Procedural miniature geometry. Scenes use it through the BevelBoxMesh, HullMesh
# and SailMesh primitives; code that builds models uses the cached ArrayMeshes.
static var boxes={}
static func bevel_box(size: Vector3) -> ArrayMesh:
	var key=str(size)
	if not boxes.has(key):boxes[key]=_array_mesh(bevel_box_arrays(size))
	return boxes[key]

static func _array_mesh(arrays: Array) -> ArrayMesh:
	var mesh=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

static func bevel_box_arrays(size: Vector3) -> Array:
	var half=size*.5
	var radius=minf(.014,minf(half.x,minf(half.y,half.z))*.28)
	var core=half-Vector3.ONE*radius
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		var u=(axis+1)%3;var v=(axis+2)%3
		for side in [-1,1]:
			var points=[]
			for pair in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				var p=Vector3.ZERO;p[axis]=side*half[axis];p[u]=pair.x*core[u];p[v]=pair.y*core[v];points.append(p)
			_face(st,points)
	for axis in 3:
		var u=(axis+1)%3;var v=(axis+2)%3
		for a in [-1,1]:
			for b in [-1,1]:
				var points=[]
				for pair in [Vector2(-1,u),Vector2(1,u),Vector2(1,v),Vector2(-1,v)]:
					var p=Vector3.ZERO;p[axis]=pair.x*core[axis];p[u]=a*(half[u] if pair.y==u else core[u]);p[v]=b*(half[v] if pair.y==v else core[v]);points.append(p)
				_face(st,points)
	for x in [-1,1]:
		for y in [-1,1]:
			for z in [-1,1]:
				var signs=Vector3(x,y,z);var points=[]
				for axis in 3:
					var p=signs*core;p[axis]=signs[axis]*half[axis];points.append(p)
				_face(st,points)
	st.generate_normals()
	return st.commit_to_arrays()

static func _face(st: SurfaceTool,points: Array):
	var center=Vector3.ZERO
	for p in points:center+=p/points.size()
	if (points[1]-points[0]).cross(points[2]-points[0]).dot(center)>0:points.reverse()
	for i in range(1,points.size()-1):
		for p in [points[0],points[i],points[i+1]]:st.add_vertex(p)

static func hull() -> ArrayMesh:
	return _array_mesh(hull_arrays())

static func hull_arrays() -> Array:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings=[]
	for j in 5:
		var t=float(j)/4
		var ring=[]
		for i in 40:
			var a=TAU*i/40
			var beam=.15*pow(t,.6)
			ring.append(Vector3(cos(a)*beam,-.10+t*.20,sin(a)*(.29+.15*t)))
		rings.append(ring)
	for j in 4:
		for i in 40:
			var next=(i+1)%40
			_face(st,[rings[j][i],rings[j+1][i],rings[j+1][next],rings[j][next]])
	_face(st,rings[4])
	st.generate_normals();return st.commit_to_arrays()

static func sail() -> ArrayMesh:
	return _array_mesh(sail_arrays())

static func sail_arrays() -> Array:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 12:
		for col in range(12-row):
			var points=[]
			for ij in [Vector2(row,col),Vector2(row+1,col),Vector2(row,col+1)]:points.append(_sail_vertex(ij/12.0))
			for p in points:st.add_vertex(p)
			if row+col<11:
				for ij in [Vector2(row+1,col),Vector2(row+1,col+1),Vector2(row,col+1)]:st.add_vertex(_sail_vertex(ij/12.0))
	st.generate_normals();return st.commit_to_arrays()
static func _sail_vertex(uv: Vector2) -> Vector3:
	return Vector3(sin(uv.x*PI)*sin(uv.y*PI)*.085,.24+uv.x*.56,.02+uv.y*.37)
