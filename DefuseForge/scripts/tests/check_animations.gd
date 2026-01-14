extends SceneTree

func _init():
	print("=== Animation Check ===\n")

	var vanguard = load("res://assets/characters/vanguard/vanguard.glb").instantiate()
	var anim_player = _find_animation_player(vanguard)

	if anim_player:
		var anims = anim_player.get_animation_list()
		print("VANGUARD animations (%d total):" % anims.size())
		for anim in anims:
			if anim != "RESET":
				print("  - %s" % anim)

		if anims.size() <= 1:
			print("\nWARNING: No animations found in vanguard.glb!")
	else:
		print("ERROR: No AnimationPlayer found in vanguard.glb!")

	quit()

func _find_animation_player(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		var found = _find_animation_player(child)
		if found:
			return found
	return null
