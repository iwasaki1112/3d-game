extends CharacterBody3D

## TPS Demo準拠の実装 + Mixamoアニメーション対応
## Root motion + AnimationTreeを正確に実装

enum Animations {
	STRAFE,
	WALK,
}

const MOTION_INTERPOLATE_SPEED: float = 10.0
const ROTATION_INTERPOLATE_SPEED: float = 10.0
const MOVE_SPEED: float = 5.0  # Root motion無効時のフォールバック

## アニメーションファイルマッピング
const ANIM_BASE_PATH := "res://assets/characters/animations/"
const ANIMATION_FILES := {
	# 基本
	"idle": "Pro Rifle Pack/idle.fbx",
	"idle_aiming": "Pro Rifle Pack/idle aiming.fbx",

	# Walk（立ち）
	"walk_forward": "Pro Rifle Pack/walk forward.fbx",
	"walk_backward": "Pro Rifle Pack/walk backward.fbx",
	"walk_left": "Pro Rifle Pack/walk left.fbx",
	"walk_right": "Pro Rifle Pack/walk right.fbx",
	"walk_forward_left": "Pro Rifle Pack/walk forward left.fbx",
	"walk_forward_right": "Pro Rifle Pack/walk forward right.fbx",
	"walk_backward_left": "Pro Rifle Pack/walk backward left.fbx",
	"walk_backward_right": "Pro Rifle Pack/walk backward right.fbx",

	# Run（立ち）
	"run_forward": "Pro Rifle Pack/run forward.fbx",
	"run_backward": "Pro Rifle Pack/run backward.fbx",
	"run_left": "Pro Rifle Pack/run left.fbx",
	"run_right": "Pro Rifle Pack/run right.fbx",

	# しゃがみ
	"crouch_idle": "Crouching Idle.fbx",
	"crouch_walk_forward": "Pro Rifle Pack/walk crouching forward.fbx",
	"crouch_walk_backward": "Pro Rifle Pack/walk crouching backward.fbx",
	"crouch_walk_left": "Pro Rifle Pack/walk crouching left.fbx",
	"crouch_walk_right": "Pro Rifle Pack/walk crouching right.fbx",
}

## 状態
var orientation := Transform3D()
var motion := Vector2()
var current_animation := Animations.WALK

## カメラ
var camera_base: Node3D
var camera_rot: Node3D
var camera: Camera3D

## モデル
var player_model: Node3D
var animation_tree: AnimationTree
var anim_player: AnimationPlayer
var skeleton: Skeleton3D
var hips_bone_idx: int = -1
var hips_rest_position: Vector3

## Aiming状態
var aiming: bool = false


func _ready() -> void:
	_setup_camera()
	_setup_model()
	_load_animations()
	_setup_animation_tree()

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("[SimpleTPS] Ready - WASD:Move, Mouse:Look, RightClick:Aim, ESC:Release mouse")


func _input(event: InputEvent) -> void:
	# マウス移動でカメラ回転
	if event is InputEventMouseMotion:
		var sensitivity := 0.003
		if aiming:
			sensitivity *= 0.75
		camera_base.rotate_y(-event.relative.x * sensitivity)
		camera_base.orthonormalize()
		camera_rot.rotation.x = clampf(
			camera_rot.rotation.x - event.relative.y * sensitivity,
			deg_to_rad(-89),
			deg_to_rad(70)
		)

	# ESCでマウス解放
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# 右クリックでエイム切り替え
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			aiming = true
		else:
			aiming = false


func _physics_process(delta: float) -> void:
	_update_input(delta)
	_apply_movement(delta)
	_reset_hips_position()


func _reset_hips_position() -> void:
	# 一時的に無効化 - velocity-based movementのみで移動
	pass


func _update_input(delta: float) -> void:
	# 入力取得（WASD）
	var input_motion := Vector2.ZERO
	if Input.is_key_pressed(KEY_D):
		input_motion.x += 1
	if Input.is_key_pressed(KEY_A):
		input_motion.x -= 1
	if Input.is_key_pressed(KEY_S):
		input_motion.y += 1  # 後方
	if Input.is_key_pressed(KEY_W):
		input_motion.y -= 1  # 前方

	# モーション補間（TPS Demo準拠）
	motion = motion.lerp(input_motion, MOTION_INTERPOLATE_SPEED * delta)


func _apply_movement(delta: float) -> void:
	# カメラ方向を取得（TPS Demo準拠）
	var camera_basis: Basis = camera_rot.global_transform.basis
	var camera_z: Vector3 = camera_basis.z
	var camera_x: Vector3 = camera_basis.x

	camera_z.y = 0
	camera_z = camera_z.normalized()
	camera_x.y = 0
	camera_x = camera_x.normalized()

	if aiming:
		# Strafeモード: カメラ方向を向いたまま移動
		var q_from: Quaternion = orientation.basis.get_rotation_quaternion()
		var q_to: Quaternion = camera_base.global_transform.basis.get_rotation_quaternion()
		orientation.basis = Basis(q_from.slerp(q_to, delta * ROTATION_INTERPOLATE_SPEED))

		_animate(Animations.STRAFE, delta)
	else:
		# Walkモード: 移動方向を向く（TPS Demo準拠）
		var target: Vector3 = camera_x * motion.x + camera_z * motion.y
		if target.length() > 0.001:
			var q_from: Quaternion = orientation.basis.get_rotation_quaternion()
			var q_to: Quaternion = Basis.looking_at(target).get_rotation_quaternion()
			orientation.basis = Basis(q_from.slerp(q_to, delta * ROTATION_INTERPOLATE_SPEED))

		_animate(Animations.WALK, delta)

	# 速度ベース移動 - カメラ軸を反転
	var move_dir := -camera_x * motion.x - camera_z * motion.y
	if move_dir.length() > 0.01:
		velocity.x = move_dir.x * MOVE_SPEED
		velocity.z = move_dir.z * MOVE_SPEED
	else:
		velocity.x = 0
		velocity.z = 0

	# 重力
	velocity += get_gravity() * delta

	move_and_slide()

	# orientationを正規化
	orientation = orientation.orthonormalized()

	# プレイヤーモデルの回転を適用
	player_model.global_transform.basis = orientation.basis


func _animate(anim: Animations, _delta: float) -> void:
	current_animation = anim

	if not animation_tree:
		return

	if anim == Animations.STRAFE:
		animation_tree["parameters/state/transition_request"] = "strafe"
		# Y軸は反転（TPS Demo準拠）
		animation_tree["parameters/strafe/blend_position"] = Vector2(motion.x, -motion.y)

	elif anim == Animations.WALK:
		animation_tree["parameters/state/transition_request"] = "walk"
		# Walk: X軸=速度
		animation_tree["parameters/walk/blend_position"] = motion.length()


func _setup_camera() -> void:
	# TPS Demo準拠のカメラセットアップ
	camera_base = Node3D.new()
	camera_base.name = "CameraBase"
	add_child(camera_base)
	camera_base.position.y = 1.6

	camera_rot = Node3D.new()
	camera_rot.name = "CameraRot"
	camera_base.add_child(camera_rot)

	# TPS DemoではSpringArm3Dを使用し、180度回転している
	var spring_arm = Node3D.new()
	spring_arm.name = "SpringArm"
	spring_arm.transform = Transform3D(
		Vector3(-1, 0, 0),
		Vector3(0, 0.94, 0.34),
		Vector3(0, 0.34, -0.94),
		Vector3.ZERO
	)
	camera_rot.add_child(spring_arm)

	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0, 0, 2.4)
	spring_arm.add_child(camera)
	camera.current = true


func _setup_model() -> void:
	var player_scene = load("res://assets/characters/animations/character_t_pose.fbx")
	if player_scene == null:
		push_error("[SimpleTPS] Failed to load character")
		return

	player_model = player_scene.instantiate()
	player_model.name = "PlayerModel"
	add_child(player_model)

	# orientationを初期化（TPS Demo準拠）
	orientation = player_model.global_transform
	orientation.origin = Vector3()

	# AnimationPlayerを取得
	anim_player = player_model.get_node_or_null("AnimationPlayer")
	if anim_player:
		print("[SimpleTPS] AnimationPlayer found")
	else:
		push_error("[SimpleTPS] AnimationPlayer not found!")

	# Skeletonを取得してHipsボーンの初期位置を保存
	skeleton = player_model.get_node_or_null("Skeleton3D")
	if not skeleton:
		# 子ノードから再帰的に探す
		skeleton = _find_skeleton(player_model)

	if skeleton:
		print("[SimpleTPS] Skeleton found: %s" % skeleton.name)
		# Mixamoキャラクターは "mixamorig_Hips" プレフィックス付き
		hips_bone_idx = skeleton.find_bone("mixamorig_Hips")
		if hips_bone_idx < 0:
			hips_bone_idx = skeleton.find_bone("Hips")  # フォールバック
		if hips_bone_idx >= 0:
			hips_rest_position = skeleton.get_bone_pose_position(hips_bone_idx)
			print("[SimpleTPS] Hips bone found at index %d, rest position: %s" % [hips_bone_idx, hips_rest_position])
		else:
			# ボーン名一覧を出力
			print("[SimpleTPS] Hips not found. Available bones: %s" % str(_get_bone_names(skeleton)))
	else:
		push_warning("[SimpleTPS] Skeleton3D not found in model")


func _load_animations() -> void:
	if not anim_player:
		return

	print("[SimpleTPS] Loading animations from FBX files...")
	var loaded_count := 0

	for anim_name in ANIMATION_FILES:
		var file_path: String = ANIM_BASE_PATH + ANIMATION_FILES[anim_name]
		var anim = _load_animation_from_fbx(file_path, anim_name)
		if anim:
			anim.loop_mode = Animation.LOOP_LINEAR
			anim_player.get_animation_library("").add_animation(anim_name, anim)
			loaded_count += 1

	print("[SimpleTPS] Loaded %d animations" % loaded_count)
	print("[SimpleTPS] Available animations: %s" % str(anim_player.get_animation_list()))


func _load_animation_from_fbx(fbx_path: String, target_name: String) -> Animation:
	var scene = load(fbx_path)
	if scene == null:
		push_warning("[SimpleTPS] Failed to load: %s" % fbx_path)
		return null

	var instance = scene.instantiate()
	var fbx_anim_player: AnimationPlayer = null

	# AnimationPlayerを探す
	fbx_anim_player = instance.get_node_or_null("AnimationPlayer")
	if not fbx_anim_player:
		for child in instance.get_children():
			if child is AnimationPlayer:
				fbx_anim_player = child
				break

	if not fbx_anim_player:
		instance.queue_free()
		push_warning("[SimpleTPS] No AnimationPlayer in: %s" % fbx_path)
		return null

	# アニメーションを取得（最初のアニメーションを使用）
	var anim_list = fbx_anim_player.get_animation_list()
	if anim_list.is_empty():
		instance.queue_free()
		push_warning("[SimpleTPS] No animations in: %s" % fbx_path)
		return null

	# "mixamo_com" または最初のアニメーションを取得
	var source_anim_name = anim_list[0]
	for name in anim_list:
		if name != "RESET" and name != "Take 001":
			source_anim_name = name
			break

	var anim = fbx_anim_player.get_animation(source_anim_name)
	if anim:
		anim = anim.duplicate()

	instance.queue_free()
	return anim


func _setup_animation_tree() -> void:
	if not anim_player:
		push_error("[SimpleTPS] AnimationPlayer not found, cannot setup AnimationTree")
		return

	animation_tree = AnimationTree.new()
	animation_tree.name = "AnimationTree"
	add_child(animation_tree)

	# AnimationTree設定（TPS Demo準拠）
	animation_tree.anim_player = anim_player.get_path()
	animation_tree.root_node = player_model.get_path()
	animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS

	# Root motion trackを設定（Mixamoキャラクター用）
	if skeleton and hips_bone_idx >= 0:
		var skel_path := player_model.get_path_to(skeleton)
		var hips_name := skeleton.get_bone_name(hips_bone_idx)
		animation_tree.root_motion_track = NodePath(str(skel_path) + ":" + hips_name)
		print("[SimpleTPS] Root motion track set: %s:%s" % [skel_path, hips_name])
	else:
		push_warning("[SimpleTPS] Skeleton/Hips not found, root motion may not work")

	# BlendTreeを構築
	var blend_tree := AnimationNodeBlendTree.new()
	animation_tree.tree_root = blend_tree

	# State Transition
	var state_machine := AnimationNodeTransition.new()
	state_machine.xfade_time = 0.2
	state_machine.add_input("strafe")
	state_machine.add_input("walk")
	blend_tree.add_node("state", state_machine, Vector2(400, 200))

	# Strafe BlendSpace2D（8方向）- 座標修正済み
	var strafe_blend := AnimationNodeBlendSpace2D.new()
	_add_blend_animation(strafe_blend, "walk_left", Vector2(-1, 0))
	_add_blend_animation(strafe_blend, "walk_right", Vector2(1, 0))
	_add_blend_animation(strafe_blend, "walk_backward", Vector2(0, -1))
	_add_blend_animation(strafe_blend, "walk_forward", Vector2(0, 1))
	_add_blend_animation(strafe_blend, "idle_aiming", Vector2(0, 0))
	# 斜め方向
	_add_blend_animation(strafe_blend, "walk_forward_left", Vector2(-0.7, 0.7))
	_add_blend_animation(strafe_blend, "walk_forward_right", Vector2(0.7, 0.7))
	_add_blend_animation(strafe_blend, "walk_backward_left", Vector2(-0.7, -0.7))
	_add_blend_animation(strafe_blend, "walk_backward_right", Vector2(0.7, -0.7))
	blend_tree.add_node("strafe", strafe_blend, Vector2(100, 100))

	# Walk BlendSpace1D（速度ベース）
	var walk_blend := AnimationNodeBlendSpace1D.new()
	_add_blend1d_animation(walk_blend, "idle", 0.0)
	_add_blend1d_animation(walk_blend, "walk_forward", 1.0)
	blend_tree.add_node("walk", walk_blend, Vector2(100, 300))

	# 接続
	blend_tree.connect_node("state", 0, "strafe")
	blend_tree.connect_node("state", 1, "walk")
	blend_tree.connect_node("output", 0, "state")

	# 有効化
	animation_tree.active = true

	# 初期状態
	animation_tree["parameters/state/transition_request"] = "walk"
	animation_tree["parameters/walk/blend_position"] = 0.0
	animation_tree["parameters/strafe/blend_position"] = Vector2(0, 0)

	print("[SimpleTPS] AnimationTree setup complete")


func _add_blend_animation(blend_space: AnimationNodeBlendSpace2D, anim_name: String, pos: Vector2) -> void:
	if not anim_player.has_animation(anim_name):
		push_warning("[SimpleTPS] Animation not found: %s" % anim_name)
		return
	var anim_node := AnimationNodeAnimation.new()
	anim_node.animation = anim_name
	blend_space.add_blend_point(anim_node, pos)


func _add_blend1d_animation(blend_space: AnimationNodeBlendSpace1D, anim_name: String, pos: float) -> void:
	if not anim_player.has_animation(anim_name):
		push_warning("[SimpleTPS] Animation not found: %s" % anim_name)
		return
	var anim_node := AnimationNodeAnimation.new()
	anim_node.animation = anim_name
	blend_space.add_blend_point(anim_node, pos)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result = _find_skeleton(child)
		if result:
			return result
	return null


func _get_bone_names(skel: Skeleton3D) -> Array:
	var names := []
	for i in skel.get_bone_count():
		names.append(skel.get_bone_name(i))
	return names
