extends SceneTree

func _init():
	var scene = load("res://assets/characters/shade/shade.glb")
	if scene:
		var instance = scene.instantiate()
		var anim_player = _find_anim_player(instance)
		if anim_player:
			print("=== Animations in shade.glb ===")
			for anim_name in anim_player.get_animation_list():
				print("  - " + anim_name)
			print("=== Total: %d animations ===" % anim_player.get_animation_list().size())
		else:
			print("AnimationPlayer not found")
		instance.queue_free()
	else:
		print("Failed to load scene")
	quit()

func _find_anim_player(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		var found = _find_anim_player(child)
		if found:
			return found
	return null
