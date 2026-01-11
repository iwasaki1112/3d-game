extends SceneTree

func _init():
	print("\n=== Shade Model Bone Names ===\n")

	var shade_path = "res://assets/characters/shade/shade.glb"
	var anim_lib_path = "res://assets/animations/actorstore_animation_library.glb"

	# Load Shade model
	print("--- Shade Model Bones ---")
	var shade_scene = load(shade_path)
	if shade_scene:
		var shade_instance = shade_scene.instantiate()
		var skeleton = _find_skeleton(shade_instance)
		if skeleton:
			print("Found Skeleton3D: %s" % skeleton.name)
			print("Parent: %s" % skeleton.get_parent().name if skeleton.get_parent() else "None")
			print("Bone count: %d" % skeleton.get_bone_count())
			print("\nBone names:")
			for i in range(skeleton.get_bone_count()):
				print("  %d: %s" % [i, skeleton.get_bone_name(i)])
		else:
			print("No Skeleton3D found!")
		shade_instance.free()
	else:
		print("Failed to load Shade model")

	# Load animation library for comparison
	print("\n--- Animation Library Bones ---")
	var anim_scene = load(anim_lib_path)
	if anim_scene:
		var anim_instance = anim_scene.instantiate()
		var anim_skeleton = _find_skeleton(anim_instance)
		if anim_skeleton:
			print("Found Skeleton3D: %s" % anim_skeleton.name)
			print("Parent: %s" % anim_skeleton.get_parent().name if anim_skeleton.get_parent() else "None")
			print("Bone count: %d" % anim_skeleton.get_bone_count())
			print("\nBone names (first 30):")
			for i in range(min(30, anim_skeleton.get_bone_count())):
				print("  %d: %s" % [i, anim_skeleton.get_bone_name(i)])
		else:
			print("No Skeleton3D found!")
		anim_instance.free()
	else:
		print("Failed to load animation library")

	quit()

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result = _find_skeleton(child)
		if result:
			return result
	return null
