extends SceneTree

func _init():
	print("\n=== Animation Track Paths ===\n")

	var anim_lib_path = "res://assets/animations/actorstore_animation_library.glb"

	var scene = load(anim_lib_path)
	if scene:
		var instance = scene.instantiate()

		# Find AnimationPlayer
		var anim_player = _find_anim_player(instance)
		if anim_player:
			print("Found AnimationPlayer")
			print("Animation libraries: %s" % anim_player.get_animation_library_list())

			for lib_name in anim_player.get_animation_library_list():
				var lib = anim_player.get_animation_library(lib_name)
				print("\nLibrary: '%s'" % lib_name)

				for anim_name in lib.get_animation_list():
					var anim = lib.get_animation(anim_name)
					print("\n  Animation: %s" % anim_name)
					print("  Track count: %d" % anim.get_track_count())

					# Print first 5 track paths
					for i in range(min(5, anim.get_track_count())):
						var track_path = anim.track_get_path(i)
						print("    Track %d: %s" % [i, track_path])
		else:
			print("No AnimationPlayer found")

		instance.free()
	else:
		print("Failed to load: %s" % anim_lib_path)

	quit()

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result = _find_anim_player(child)
		if result:
			return result
	return null
