extends SceneTree

func _init():
	print("=== Skeleton Bone Comparison ===\n")

	# Load vanguard
	var vanguard = load("res://assets/characters/vanguard/vanguard.glb").instantiate()
	var vanguard_skel = _find_skeleton(vanguard)

	# Load phantom
	var phantom = load("res://assets/characters/phantom/phantom.glb").instantiate()
	var phantom_skel = _find_skeleton(phantom)

	print("VANGUARD bones (%d total):" % vanguard_skel.get_bone_count())
	for i in range(mini(15, vanguard_skel.get_bone_count())):
		print("  %d: %s" % [i, vanguard_skel.get_bone_name(i)])

	print("\nPHANTOM bones (%d total):" % phantom_skel.get_bone_count())
	for i in range(mini(15, phantom_skel.get_bone_count())):
		print("  %d: %s" % [i, phantom_skel.get_bone_name(i)])

	print("\n=== Comparison ===")
	if vanguard_skel.get_bone_count() == phantom_skel.get_bone_count():
		var match_count = 0
		for i in range(vanguard_skel.get_bone_count()):
			if vanguard_skel.get_bone_name(i) == phantom_skel.get_bone_name(i):
				match_count += 1
		print("Bone count: MATCH (%d)" % vanguard_skel.get_bone_count())
		print("Matching bone names: %d / %d" % [match_count, vanguard_skel.get_bone_count()])
		if match_count == vanguard_skel.get_bone_count():
			print("Result: COMPATIBLE - Animations will work!")
		else:
			print("Result: INCOMPATIBLE - Bone names differ!")
	else:
		print("Bone count: MISMATCH (vanguard=%d, phantom=%d)" % [vanguard_skel.get_bone_count(), phantom_skel.get_bone_count()])
		print("Result: INCOMPATIBLE")

	quit()

func _find_skeleton(node: Node) -> Skeleton3D:
	for child in node.get_children():
		if child is Skeleton3D:
			return child
		var found = _find_skeleton(child)
		if found:
			return found
	return null
