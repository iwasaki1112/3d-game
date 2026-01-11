extends SceneTree

func _init():
	print("\n=== Test Shade Animation Loading ===\n")

	# Load Shade model
	var shade_path = "res://assets/characters/shade/shade.glb"
	var anim_lib_path = "res://assets/animations/actorstore_animation_library.glb"

	print("Loading Shade model...")
	var shade_scene = load(shade_path)
	if not shade_scene:
		print("ERROR: Failed to load Shade model")
		quit()
		return

	var shade_instance = shade_scene.instantiate()
	print("Shade instantiated")

	# Find skeleton and check structure
	var skeleton = _find_skeleton(shade_instance)
	if skeleton:
		print("Skeleton found: %s" % skeleton.name)
		print("Skeleton parent: %s" % skeleton.get_parent().name if skeleton.get_parent() else "None")
		print("Bone count: %d" % skeleton.get_bone_count())
		print("\nFirst 10 bones:")
		for i in range(min(10, skeleton.get_bone_count())):
			print("  %s" % skeleton.get_bone_name(i))
	else:
		print("ERROR: No skeleton found in Shade")
		shade_instance.free()
		quit()
		return

	# Create AnimationPlayer and load animations
	print("\nCreating AnimationPlayer...")
	var anim_player = AnimationPlayer.new()
	shade_instance.add_child(anim_player)

	# Create empty animation library
	var lib = AnimationLibrary.new()
	anim_player.add_animation_library("", lib)

	# Load animation library and copy animations
	print("Loading ActorStore animation library...")
	var anim_lib_scene = load(anim_lib_path)
	if not anim_lib_scene:
		print("ERROR: Failed to load animation library")
		shade_instance.free()
		quit()
		return

	var anim_lib_instance = anim_lib_scene.instantiate()
	var lib_anim_player = _find_anim_player(anim_lib_instance)

	if lib_anim_player:
		print("Source AnimationPlayer found")

		for src_lib_name in lib_anim_player.get_animation_library_list():
			var src_lib = lib_anim_player.get_animation_library(src_lib_name)
			print("Processing library: '%s'" % src_lib_name)

			for anim_name in src_lib.get_animation_list():
				var src_anim = src_lib.get_animation(anim_name)
				var anim_copy = src_anim.duplicate()

				# Check track paths before adjustment
				print("\nAnimation: %s" % anim_name)
				print("  Track 0 before: %s" % anim_copy.track_get_path(0))

				# Adjust paths for Shade model
				_adjust_animation_paths(anim_copy, shade_instance)

				print("  Track 0 after: %s" % anim_copy.track_get_path(0))

				lib.add_animation(anim_name, anim_copy)
				print("  Added to library")
	else:
		print("ERROR: No AnimationPlayer in animation library")

	anim_lib_instance.free()

	# Test playing animation
	print("\n--- Testing animation playback ---")
	var anims = lib.get_animation_list()
	print("Available animations: %s" % anims)

	if anims.size() > 0:
		var test_anim = anims[0]
		print("Playing: %s" % test_anim)
		anim_player.play(test_anim)
		anim_player.seek(0.0, true)  # Force update

		# Check for errors
		print("Animation playing: %s" % anim_player.is_playing())

	shade_instance.free()
	print("\n=== Test Complete ===")
	quit()

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result = _find_skeleton(child)
		if result:
			return result
	return null

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result = _find_anim_player(child)
		if result:
			return result
	return null

func _adjust_animation_paths(anim: Animation, model: Node) -> void:
	var skeleton_path = _find_skeleton_path(model)
	print("  Model skeleton path: '%s'" % skeleton_path)

	for i in range(anim.get_track_count()):
		var track_path = anim.track_get_path(i)
		var path_str = str(track_path)

		var skeleton_idx = path_str.find("Skeleton3D:")
		if skeleton_idx >= 0:
			var bone_part = path_str.substr(skeleton_idx)
			path_str = skeleton_path + "/" + bone_part
			anim.track_set_path(i, NodePath(path_str))

func _find_skeleton_path(node: Node, current_path: String = "") -> String:
	for child in node.get_children():
		if child is Skeleton3D:
			if current_path.is_empty():
				return child.get_parent().name if child.get_parent() else ""
			return current_path

		var child_path = current_path
		if not child_path.is_empty():
			child_path += "/"
		child_path += child.name

		var result = _find_skeleton_path(child, child_path)
		if not result.is_empty():
			return result

	return ""
