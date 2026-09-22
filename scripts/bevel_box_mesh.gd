@tool
class_name BevelBoxMesh
extends PrimitiveMesh
## A box with softened edges, matching the miniature style of the pieces.

@export var size:=Vector3.ONE:
	set(value):
		size=value
		request_update()

func _create_mesh_array() -> Array:
	return CatanMiniature.bevel_box_arrays(size)
