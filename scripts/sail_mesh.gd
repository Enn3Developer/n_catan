@tool
class_name SailMesh
extends PrimitiveMesh
## A wind-filled triangular sail.

func _create_mesh_array() -> Array:
	return CatanMiniature.sail_arrays()
