extends Node3D

func _ready() -> void:
	# Wait a frame for everything to initialize
	await get_tree().process_frame

	var leet = $LeetModel
	var gsg9 = $Gsg9Model

	print("=== Character Position Test ===")

	if leet:
		var leet_aabb = _get_global_aabb(leet)
		print("Leet AABB: min_y=%.3f, max_y=%.3f" % [leet_aabb.position.y, leet_aabb.end.y])
	else:
		print("Leet model not found!")

	if gsg9:
		var gsg9_aabb = _get_global_aabb(gsg9)
		print("Gsg9 AABB: min_y=%.3f, max_y=%.3f" % [gsg9_aabb.position.y, gsg9_aabb.end.y])
	else:
		print("Gsg9 model not found!")

	print("=== End Test ===")

func _get_global_aabb(node: Node3D) -> AABB:
	var aabb := AABB()
	var first := true

	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_inst := child as MeshInstance3D
			if mesh_inst.mesh:
				var child_aabb := mesh_inst.get_aabb()
				child_aabb = mesh_inst.global_transform * child_aabb
				if first:
					aabb = child_aabb
					first = false
				else:
					aabb = aabb.merge(child_aabb)

		if child is Node3D:
			var child_aabb := _get_global_aabb(child)
			if child_aabb.size != Vector3.ZERO:
				if first:
					aabb = child_aabb
					first = false
				else:
					aabb = aabb.merge(child_aabb)

	return aabb
