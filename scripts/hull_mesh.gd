@tool
class_name HullMesh
extends PrimitiveMesh
## The rounded hull shared by every miniature boat.

func _create_mesh_array() -> Array:
	return CatanMiniature.hull_arrays()
