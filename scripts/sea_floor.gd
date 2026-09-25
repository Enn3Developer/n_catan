class_name CatanSeaFloor
extends RefCounted
## The GDScript side of shaders/sea_floor.gdshaderinc: distance to the island
## shore and the bed depth at that distance, in metres. Keep the two in step.

var centers=PackedVector2Array()
var radius=25.0

func _init(tile_centers: PackedVector2Array=PackedVector2Array(),tile_radius: float=25.0):
	centers=tile_centers
	radius=tile_radius

## Metres from the nearest hex edge; negative inside a tile.
func shore_distance(p: Vector2) -> float:
	var d=10000.0
	for c in centers:
		var q=p-c
		var e=maxf(absf(q.x),maxf(absf(q.x*.5+q.y*.8660254),absf(-q.x*.5+q.y*.8660254)))-radius*.8660254
		d=minf(d,e)
	return d

## Points away from the nearest shore, for steering fish off the coast.
func away_from_shore(p: Vector2) -> Vector2:
	var e=1.5
	var g=Vector2(shore_distance(p+Vector2(e,0))-shore_distance(p-Vector2(e,0)),shore_distance(p+Vector2(0,e))-shore_distance(p-Vector2(0,e)))
	return g.normalized() if g.length()>.0001 else Vector2.ZERO

## Metres below the waterline, without the shader's small-scale roughness.
static func seabed_depth(shore: float) -> float:
	var s=maxf(shore,0.0)
	var depth=lerpf(2.6,6.0,smoothstep(0.0,18.0,s))
	depth+=8.0*smoothstep(17.0,27.0,s)
	depth+=12.0*smoothstep(27.0,60.0,s)
	depth+=20.0*smoothstep(60.0,140.0,s)
	return depth
