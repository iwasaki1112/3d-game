extends Node3D

const CharacterSetup = preload("res://scripts/utils/character_setup.gd")

@onready var leet_model = $LeetModel
@onready var gsg9_model = $Gsg9Model
@onready var label_leet = $Label_Leet
@onready var label_gsg9 = $Label_Gsg9

func _ready():
	# CharacterSetupを使用してテクスチャとアニメーションを設定
	CharacterSetup.setup_materials(leet_model, "LEET")
	CharacterSetup.setup_materials(gsg9_model, "GSG9")

	# Yオフセットを適用（足の位置を揃える）
	var leet_offset = CharacterSetup.get_y_offset("LEET")
	var gsg9_offset = CharacterSetup.get_y_offset("GSG9")
	leet_model.position.y += leet_offset
	gsg9_model.position.y += gsg9_offset
	print("[TestPivot] Applied Y offsets - LEET: %.6f, GSG9: %.6f" % [leet_offset, gsg9_offset])

	# アニメーション設定
	var leet_anim = CharacterSetup.find_animation_player(leet_model)
	if leet_anim:
		CharacterSetup.load_animations(leet_anim, leet_model, "LEET")
		if leet_anim.has_animation("idle"):
			leet_anim.play("idle")

	var gsg9_anim = CharacterSetup.find_animation_player(gsg9_model)
	if gsg9_anim:
		CharacterSetup.load_animations(gsg9_anim, gsg9_model, "GSG9")
		if gsg9_anim.has_animation("idle"):
			gsg9_anim.play("idle")

	# モデルの情報を取得
	call_deferred("analyze_models")

func analyze_models():
	print("=== Character Pivot Analysis ===")
	print("")

	# Leetモデルの解析
	print("--- LEET Model ---")
	analyze_model(leet_model, "LEET")

	print("")

	# GSG9モデルの解析
	print("--- GSG9 Model ---")
	analyze_model(gsg9_model, "GSG9")

	# AABBから足の位置を計算
	var leet_aabb = get_model_aabb(leet_model)
	var gsg9_aabb = get_model_aabb(gsg9_model)

	print("")
	print("=== AABB Comparison ===")
	print("LEET AABB: ", leet_aabb)
	print("GSG9 AABB: ", gsg9_aabb)

	# 足の底面の位置（AABBの最小Y）
	var leet_foot_y = leet_aabb.position.y if leet_aabb else 0.0
	var gsg9_foot_y = gsg9_aabb.position.y if gsg9_aabb else 0.0

	print("")
	print("=== Foot Position (AABB min Y) ===")
	print("LEET foot Y: ", leet_foot_y)
	print("GSG9 foot Y: ", gsg9_foot_y)
	print("Difference: ", gsg9_foot_y - leet_foot_y)

	# ラベルを更新
	label_leet.text = "LEET\nFoot Y: %.3f" % leet_foot_y
	label_gsg9.text = "GSG9\nFoot Y: %.3f" % gsg9_foot_y

func analyze_model(model: Node, name: String):
	print("Model position: ", model.global_position)
	print("Model transform: ", model.global_transform)

	# スケルトンを探す
	var skeleton = CharacterSetup.find_skeleton(model)
	if skeleton:
		print("Found Skeleton: ", skeleton.name)
		print("Bone count: ", skeleton.get_bone_count())

		# 足のボーンを探す
		for i in skeleton.get_bone_count():
			var bone_name = skeleton.get_bone_name(i)
			if "foot" in bone_name.to_lower() or "ankle" in bone_name.to_lower() or "toe" in bone_name.to_lower():
				var bone_pose = skeleton.get_bone_global_pose(i)
				var bone_world_pos = skeleton.global_transform * bone_pose.origin
				print("  Bone '%s': local=%s, world=%s" % [bone_name, bone_pose.origin, bone_world_pos])
	else:
		print("No skeleton found")

	# メッシュを探す
	var meshes = CharacterSetup.find_meshes(model)
	print("Mesh count: ", meshes.size())
	for mesh in meshes:
		var aabb = mesh.get_aabb()
		var _global_aabb = mesh.global_transform * aabb
		print("  Mesh '%s' AABB: %s (global min Y: %.3f)" % [mesh.name, aabb, (mesh.global_transform * aabb.position).y])
		# マテリアル情報
		analyze_mesh_materials(mesh)

func analyze_mesh_materials(mesh: MeshInstance3D):
	var mesh_data = mesh.mesh
	if mesh_data == null:
		print("    - No mesh data")
		return

	var surface_count = mesh_data.get_surface_count()
	print("    - Surface count: ", surface_count)

	for i in surface_count:
		var mat = mesh.get_active_material(i)
		if mat:
			print("    - Surface %d material: %s" % [i, mat.resource_path if mat.resource_path else mat.get_class()])
			if mat is StandardMaterial3D:
				var std_mat = mat as StandardMaterial3D
				var albedo_tex = std_mat.albedo_texture
				if albedo_tex:
					print("      Albedo texture: %s" % albedo_tex.resource_path)
				else:
					print("      Albedo texture: NONE (color: %s)" % std_mat.albedo_color)
		else:
			print("    - Surface %d material: NONE" % i)

func get_model_aabb(model: Node) -> AABB:
	var combined_aabb: AABB = AABB()
	var first = true

	var meshes = CharacterSetup.find_meshes(model)
	for mesh in meshes:
		var mesh_aabb = mesh.get_aabb()
		var transformed_aabb = mesh.global_transform * mesh_aabb
		if first:
			combined_aabb = transformed_aabb
			first = false
		else:
			combined_aabb = combined_aabb.merge(transformed_aabb)

	return combined_aabb
