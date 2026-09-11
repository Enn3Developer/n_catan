class_name CatanWorldLayout
extends RefCounted
# Shared with the Blender generator so moving a worker also clears its scenery.
static var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/layout.json"))

static func biome(kind: int) -> Dictionary:return data.biomes[clampi(kind,0,5)]
static func point(value: Array) -> Vector2:return Vector2(value[0],value[1])

static func travel_path(kind: int,index: int) -> Array:
	var paths=biome(kind).paths
	return paths[index] if index<paths.size() else []

static func along_path(path: Array,amount: float) -> Vector2:
	if path.is_empty():return Vector2.ZERO
	var lengths=[];var total=0.0
	for i in range(1,path.size()):
		var length=point(path[i-1]).distance_to(point(path[i]))
		lengths.append(length);total+=length
	var distance=clampf(amount,0,1)*total
	for i in lengths.size():
		if distance<=lengths[i]:return point(path[i]).lerp(point(path[i+1]),distance/maxf(.0001,lengths[i]))
		distance-=lengths[i]
	return point(path[-1])
