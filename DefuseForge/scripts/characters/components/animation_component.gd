class_name AnimationComponent
extends Node

## アニメーション管理コンポーネント
## AnimationTree、上半身/下半身ブレンド、8方向ストレイフ、しゃがみを担当
## Door Kickers 2 スタイルの戦術移動をサポート

signal animation_finished(anim_name: String)
signal death_animation_finished
signal crouch_changed(is_crouching: bool)

## 移動状態
enum LocomotionState { IDLE, WALK, RUN }

## 姿勢状態
enum PostureState { STANDING, CROUCHING }

## 武器タイプ別アニメーション名マッピング
const WEAPON_TYPE_NAMES := {
	0: "none",   # NONE
	1: "rifle",  # RIFLE
	2: "pistol"  # PISTOL
}

## アニメーション名の優先候補（ユーザー作成 → NeonfireStudio → Godot TPS Demo → DefuseForge旧形式）
const ANIM_CANDIDATES := {
	# 基本移動
	"idle": ["idle", "Idle", "Idlecombat"],
	"walk_forward": ["walk_forward", "Walking", "forward", "strafe_front"],
	"run_forward": ["run_forward", "Running", "sprint", "running_gun", "running_nogun"],

	# 8方向ストレイフ（Godot TPS Demo: strafe_front/back/left/right）
	"strafe_forward": ["strafe_forward", "JogForward", "strafe_front", "walk_forward", "forward"],
	"strafe_backward": ["strafe_backward", "JogBackward", "strafe_back", "walk_backward", "backward"],
	"strafe_left": ["strafe_left", "JogLeft", "left_strafe"],
	"strafe_right": ["strafe_right", "JogRight", "right_strafe"],
	"strafe_forward_left": ["strafe_forward_left", "JogForwardLeft", "forward_left"],
	"strafe_forward_right": ["strafe_forward_right", "JogForwardRight", "forward_right"],
	"strafe_backward_left": ["strafe_backward_left", "JogBackLeft", "backward_left"],
	"strafe_backward_right": ["strafe_backward_right", "JogBackRight", "backward_right"],

	# しゃがみ
	"crouch_idle": ["crouch_idle", "CrouchIdle"],
	"crouch_walk_forward": ["crouch_walk_forward", "CrouchWalking", "crouch_forward"],
	"stand_to_crouch": ["stand_to_crouch"],
	"crouch_to_stand": ["crouch_to_stand"],

	# 武器・戦闘
	"rifle_idle": ["rifle_idle", "idle"],
	"rifle_shoot": ["rifle_shoot"],
	"rifle_reload": ["rifle_reload"],
	"pistol_idle": ["pistol_idle", "idle"],
	"pistol_shoot": ["pistol_shoot"],
	"pistol_reload": ["pistol_reload"],

	# アクション
	"death": ["death", "Death"],
	"roll": ["roll", "Rolling"],
	"slide": ["slide", "Sliding"],
	"hard_land": ["hard_land", "HardLand"],
	"run_to_stop": ["run_to_stop", "RunToStop"],
}

## 上半身エイミング設定
@export var aim_rotation_speed: float = 10.0
@export_range(0, 180, 1) var aim_max_angle_deg: float = 90.0
@export_range(-90, 90, 1) var aim_max_pitch_deg: float = 30.0

## アニメーション速度設定
@export var anim_base_walk_speed: float = 1.5
@export var anim_base_run_speed: float = 4.0
@export var anim_base_crouch_speed: float = 0.75

## 内部参照
var anim_player: AnimationPlayer
var anim_tree: AnimationTree
var _blend_tree: AnimationNodeBlendTree
var skeleton: Skeleton3D

const BoneNameRegistry = preload("res://scripts/utils/bone_name_registry.gd")

## 状態
var locomotion_state: LocomotionState = LocomotionState.IDLE
var posture_state: PostureState = PostureState.STANDING
var weapon_type: int = 2  # WeaponRegistry.WeaponType (default: PISTOL)
var is_shooting: bool = false
var _shooting_blend: float = 0.0

## ストレイフ（8方向移動）
var _strafe_blend_x: float = 0.0  # -1 = 左, 0 = 前後, +1 = 右
var _strafe_blend_y: float = 1.0  # -1 = 後退, 0 = 停止, +1 = 前進
var _strafe_enabled: bool = false

## 上半身リコイル
var _upper_body_recoil: float = 0.0
const RECOIL_KICK_ANGLE: float = 0.08  # ~4.5度
const UPPER_BODY_RECOIL_RECOVERY_SPEED: float = 12.0

## 上半身エイミング（ヨー・ピッチ）
var _current_aim_rotation: float = 0.0
var _target_aim_rotation: float = 0.0
var _current_pitch_rotation: float = 0.0
var _target_pitch_rotation: float = 0.0

const SHOOTING_BLEND_SPEED: float = 10.0
const ANIM_BLEND_TIME: float = 0.3
const LOCOMOTION_XFADE_TIME: float = 0.2


func _ready() -> void:
	pass


## 初期化
func setup(model: Node3D, skel: Skeleton3D) -> void:
	skeleton = skel

	anim_player = model.get_node_or_null("AnimationPlayer")
	if anim_player == null:
		push_error("[AnimationComponent] AnimationPlayer not found in model: %s" % model.name)
		return

	if not anim_player.animation_finished.is_connected(_on_animation_finished):
		anim_player.animation_finished.connect(_on_animation_finished)

	_setup_animation_loops()
	_setup_animation_tree(model)


## ========================================
## 移動状態 API
## ========================================

## 移動状態を設定
func set_locomotion(state: int) -> void:
	var new_state := state as LocomotionState
	if locomotion_state == new_state:
		return

	locomotion_state = new_state

	if anim_tree and not anim_tree.active:
		anim_tree.active = true

	_update_locomotion_animation()


## 武器タイプを設定
func set_weapon_type(type: int) -> void:
	if weapon_type == type:
		return

	weapon_type = type
	_rebuild_blend_spaces()
	_update_locomotion_animation()


## ========================================
## しゃがみ API
## ========================================

## しゃがみ状態を設定
func set_crouching(crouching: bool) -> void:
	var new_state = PostureState.CROUCHING if crouching else PostureState.STANDING
	if posture_state == new_state:
		return

	posture_state = new_state
	_update_locomotion_animation()
	crouch_changed.emit(crouching)


## しゃがみ中かどうか
func is_crouching() -> bool:
	return posture_state == PostureState.CROUCHING


## ========================================
## ストレイフ（8方向移動）API
## ========================================

## ストレイフブレンドを設定
func set_strafe_blend(x: float, y: float) -> void:
	_strafe_blend_x = clamp(x, -1.0, 1.0)
	_strafe_blend_y = clamp(y, -1.0, 1.0)
	_strafe_enabled = true


## ストレイフを無効化
func disable_strafe() -> void:
	_strafe_enabled = false
	_strafe_blend_x = 0.0
	_strafe_blend_y = 1.0


## ストレイフが有効かどうか
func is_strafe_enabled() -> bool:
	return _strafe_enabled


## ========================================
## 射撃・リコイル API
## ========================================

## 射撃状態を設定
func set_shooting(shooting: bool) -> void:
	is_shooting = shooting


## 上半身リコイルを適用
func apply_upper_body_recoil(intensity: float) -> void:
	_upper_body_recoil = RECOIL_KICK_ANGLE * intensity


## ========================================
## 上半身エイミング API
## ========================================

## 上半身エイミング角度を設定（ヨー + ピッチ）
func apply_spine_rotation(yaw_degrees: float, pitch_degrees: float = 0.0) -> void:
	_target_aim_rotation = deg_to_rad(clamp(yaw_degrees, -aim_max_angle_deg, aim_max_angle_deg))
	_target_pitch_rotation = deg_to_rad(clamp(pitch_degrees, -aim_max_pitch_deg, aim_max_pitch_deg))


## 現在の上半身回転角度を取得（ラジアン）
func get_current_aim_rotation() -> Vector2:
	return Vector2(_current_aim_rotation, _current_pitch_rotation)


## ========================================
## アニメーション速度 API
## ========================================

## 移動速度に基づいてアニメーション速度を設定
func set_animation_speed(current_speed: float, is_running: bool) -> void:
	if anim_tree == null or not anim_tree.active:
		return

	var base_speed: float
	if posture_state == PostureState.CROUCHING:
		base_speed = anim_base_crouch_speed
	elif is_running:
		base_speed = anim_base_run_speed
	else:
		base_speed = anim_base_walk_speed

	var time_scale = 1.0
	if base_speed > 0.01 and current_speed > 0.01:
		time_scale = current_speed / base_speed
		time_scale = clampf(time_scale, 0.5, 2.0)

	anim_tree.set("parameters/time_scale/scale", time_scale)


## ========================================
## 再生 API
## ========================================

## アニメーションを直接再生
func play_animation(anim_name: String, blend_time: float = ANIM_BLEND_TIME) -> void:
	if anim_player == null:
		push_warning("[AnimationComponent] anim_player is null!")
		return

	if not anim_player.has_animation(anim_name):
		push_warning("[AnimationComponent] Animation not found: %s" % anim_name)
		return

	if anim_tree and anim_tree.active:
		anim_tree.active = false
		anim_player.play(anim_name, blend_time)
		await anim_player.animation_finished
		if anim_tree:
			anim_tree.active = true
	else:
		anim_player.play(anim_name, blend_time)


## 毎フレーム更新
func update(delta: float) -> void:
	_update_shooting_blend(delta)
	_update_upper_body_aim(delta)
	_recover_upper_body_recoil(delta)
	_update_strafe_blend()


## アニメーションリストを取得
func get_animation_list() -> PackedStringArray:
	if anim_player == null:
		return PackedStringArray()
	return anim_player.get_animation_list()


## スケルトン更新時に呼ばれる
func on_skeleton_updated() -> void:
	pass


## 最終的な上半身回転を適用
func apply_final_upper_body_rotation() -> void:
	if skeleton == null:
		return

	if absf(_current_aim_rotation) < 0.001 and absf(_current_pitch_rotation) < 0.001 and absf(_upper_body_recoil) < 0.001:
		return

	var spine_indices: Array[int] = []
	for i in range(skeleton.get_bone_count()):
		var bone_name = skeleton.get_bone_name(i)
		var lower_name = bone_name.to_lower()
		if ("spine" in lower_name or "chest" in lower_name) and "ik" not in lower_name and "ctrl" not in lower_name:
			spine_indices.append(i)

	if spine_indices.is_empty():
		return

	var bone_count = max(spine_indices.size(), 1)
	var per_bone_yaw = _current_aim_rotation / bone_count
	var per_bone_pitch = _current_pitch_rotation / bone_count
	var per_bone_recoil = _upper_body_recoil / bone_count

	for bone_idx in spine_indices:
		var current_rotation = skeleton.get_bone_pose_rotation(bone_idx)
		var twist = Quaternion(Vector3.UP, per_bone_yaw)
		var pitch = Quaternion(Vector3.RIGHT, per_bone_pitch)
		var kick = Quaternion(Vector3.RIGHT, -per_bone_recoil)
		skeleton.set_bone_pose_rotation(bone_idx, current_rotation * twist * pitch * kick)


## ========================================
## 内部処理: AnimationTree構築
## ========================================

## AnimationTreeを設定
func _setup_animation_tree(model: Node3D) -> void:
	if anim_player == null or skeleton == null:
		return

	var existing = model.get_node_or_null("AnimationTree")
	if existing:
		existing.queue_free()

	anim_tree = AnimationTree.new()
	anim_tree.name = "AnimationTree"
	model.add_child(anim_tree)
	anim_tree.anim_player = anim_tree.get_path_to(anim_player)

	_blend_tree = AnimationNodeBlendTree.new()
	anim_tree.tree_root = _blend_tree

	# === 下半身: Locomotion系ノード ===

	# Idle
	var locomotion_idle = AnimationNodeAnimation.new()
	_blend_tree.add_node("locomotion_idle", locomotion_idle, Vector2(-500, -150))

	# Run
	var locomotion_run = AnimationNodeAnimation.new()
	_blend_tree.add_node("locomotion_run", locomotion_run, Vector2(-500, 150))

	# Walk BlendSpace2D（8方向ストレイフ）
	var walk_blend_space = AnimationNodeBlendSpace2D.new()
	walk_blend_space.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED
	walk_blend_space.set_min_space(Vector2(-1, -1))
	walk_blend_space.set_max_space(Vector2(1, 1))
	_blend_tree.add_node("locomotion_walk", walk_blend_space, Vector2(-500, 0))
	_setup_walk_blend_space(walk_blend_space)

	# Crouch Idle
	var crouch_idle = AnimationNodeAnimation.new()
	_blend_tree.add_node("crouch_idle", crouch_idle, Vector2(-500, 300))

	# Crouch Walk BlendSpace2D
	var crouch_blend_space = AnimationNodeBlendSpace2D.new()
	crouch_blend_space.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED
	crouch_blend_space.set_min_space(Vector2(-1, -1))
	crouch_blend_space.set_max_space(Vector2(1, 1))
	_blend_tree.add_node("crouch_walk", crouch_blend_space, Vector2(-500, 450))
	_setup_crouch_blend_space(crouch_blend_space)

	# Standing Locomotion Transition (idle/walk/run)
	var stand_transition = AnimationNodeTransition.new()
	stand_transition.xfade_time = LOCOMOTION_XFADE_TIME
	stand_transition.add_input("idle")    # 0
	stand_transition.add_input("walk")    # 1
	stand_transition.add_input("run")     # 2
	_blend_tree.add_node("stand_transition", stand_transition, Vector2(-250, 0))
	_blend_tree.connect_node("stand_transition", 0, "locomotion_idle")
	_blend_tree.connect_node("stand_transition", 1, "locomotion_walk")
	_blend_tree.connect_node("stand_transition", 2, "locomotion_run")

	# Crouch Locomotion Transition (idle/walk)
	var crouch_transition = AnimationNodeTransition.new()
	crouch_transition.xfade_time = LOCOMOTION_XFADE_TIME
	crouch_transition.add_input("idle")   # 0
	crouch_transition.add_input("walk")   # 1
	_blend_tree.add_node("crouch_transition", crouch_transition, Vector2(-250, 350))
	_blend_tree.connect_node("crouch_transition", 0, "crouch_idle")
	_blend_tree.connect_node("crouch_transition", 1, "crouch_walk")

	# Posture Transition (standing/crouching)
	var posture_transition = AnimationNodeTransition.new()
	posture_transition.xfade_time = 0.3
	posture_transition.add_input("standing")   # 0
	posture_transition.add_input("crouching")  # 1
	_blend_tree.add_node("posture_transition", posture_transition, Vector2(-50, 100))
	_blend_tree.connect_node("posture_transition", 0, "stand_transition")
	_blend_tree.connect_node("posture_transition", 1, "crouch_transition")

	# === 上半身: Idle（Aimポーズとして使用）===
	var upper_idle = AnimationNodeAnimation.new()
	upper_idle.animation = _find_animation_by_key("idle")
	_blend_tree.add_node("upper_idle", upper_idle, Vector2(-50, 250))

	# === 上半身/下半身分離: Blend2ノード ===
	var body_split = AnimationNodeBlend2.new()
	_blend_tree.add_node("body_split", body_split, Vector2(100, 100))
	_blend_tree.connect_node("body_split", 0, "posture_transition")
	_blend_tree.connect_node("body_split", 1, "upper_idle")

	_setup_upper_body_filter(body_split)

	# TimeScaleノード
	var time_scale = AnimationNodeTimeScale.new()
	_blend_tree.add_node("time_scale", time_scale, Vector2(250, 100))
	_blend_tree.connect_node("time_scale", 0, "body_split")
	_blend_tree.connect_node("output", 0, "time_scale")

	# ルートモーション設定（Hips/Pelvisボーンから抽出）
	_setup_root_motion()

	# 初期設定
	_update_locomotion_animation()
	anim_tree.set("parameters/body_split/blend_amount", 1.0)
	anim_tree.process_callback = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	anim_tree.active = true


## ルートモーションをセットアップ（TPS Demo方式）
func _setup_root_motion() -> void:
	if anim_tree == null or skeleton == null:
		return

	# ルートモーション用ボーンを検索（優先順: root > hips > pelvis）
	var root_bone_name := ""
	var bone_priority := ["root", "hips", "pelvis"]

	# まず完全一致で検索
	for priority_name in bone_priority:
		for i in range(skeleton.get_bone_count()):
			var bone_name = skeleton.get_bone_name(i)
			if bone_name.to_lower() == priority_name:
				root_bone_name = bone_name
				break
		if not root_bone_name.is_empty():
			break

	# 完全一致がなければ部分一致で検索
	if root_bone_name.is_empty():
		for i in range(skeleton.get_bone_count()):
			var bone_name = skeleton.get_bone_name(i)
			var lower_name = bone_name.to_lower()
			if "hip" in lower_name or "pelvis" in lower_name:
				root_bone_name = bone_name
				break

	if root_bone_name.is_empty():
		push_warning("[AnimationComponent] No root motion bone found (root/hips/pelvis)")
		return

	# AnimationTreeの親（モデル）からスケルトンへのパスを取得
	# TPS Demo: Robot_Skeleton/Skeleton3D:root
	var armature = skeleton.get_parent()
	var armature_name = armature.name if armature else "Armature"
	var skeleton_path = "%s/Skeleton3D" % armature_name

	# ルートモーショントラックを設定
	var root_motion_path = "%s:%s" % [skeleton_path, root_bone_name]
	anim_tree.root_motion_track = NodePath(root_motion_path)


## ルートモーションの位置デルタを取得
func get_root_motion_position() -> Vector3:
	if anim_tree == null:
		return Vector3.ZERO
	return anim_tree.get_root_motion_position()


## ルートモーションの回転デルタを取得
func get_root_motion_rotation() -> Quaternion:
	if anim_tree == null:
		return Quaternion.IDENTITY
	return anim_tree.get_root_motion_rotation()


## Walk BlendSpace2D（8方向）をセットアップ
## TPS Demo方式: strafe_left = (1, 0), strafe_right = (-1, 0)
func _setup_walk_blend_space(blend_space: AnimationNodeBlendSpace2D) -> void:
	if anim_player == null:
		return

	# 8方向のブレンドポイントを追加
	# TPS Demo座標系（逆転）: +X=左, -X=右, +Y=前進, -Y=後退
	# ※ TPS Demoでは blend_position = Vector2(motion.x, -motion.y) で設定
	var directions := {
		"strafe_forward": Vector2(0, 1),
		"strafe_backward": Vector2(0, -1),
		"strafe_left": Vector2(1, 0),      # TPS Demo: +X = 左移動
		"strafe_right": Vector2(-1, 0),    # TPS Demo: -X = 右移動
		"strafe_forward_left": Vector2(0.7, 0.7),
		"strafe_forward_right": Vector2(-0.7, 0.7),
		"strafe_backward_left": Vector2(0.7, -0.7),
		"strafe_backward_right": Vector2(-0.7, -0.7),
	}

	for key in directions:
		var anim_name = _find_animation_by_key(key)
		if not anim_name.is_empty():
			var anim_node = AnimationNodeAnimation.new()
			anim_node.animation = anim_name
			blend_space.add_blend_point(anim_node, directions[key])
		else:
			# フォールバック: 前方向または後方向のアニメーションを使用
			var fallback_key = "strafe_forward" if "forward" in key else "strafe_backward"
			var fallback_name = _find_animation_by_key(fallback_key)
			if not fallback_name.is_empty():
				var anim_node = AnimationNodeAnimation.new()
				anim_node.animation = fallback_name
				blend_space.add_blend_point(anim_node, directions[key])


## Crouch BlendSpace2D（しゃがみ移動）をセットアップ
## TPS Demo方式: +X=左, -X=右
func _setup_crouch_blend_space(blend_space: AnimationNodeBlendSpace2D) -> void:
	if anim_player == null:
		return

	# しゃがみは簡易的に前後左右のみ
	var crouch_idle_name = _find_animation_by_key("crouch_idle")
	var crouch_walk_name = _find_animation_by_key("crouch_walk_forward")

	# 中央（停止）
	if not crouch_idle_name.is_empty():
		var idle_node = AnimationNodeAnimation.new()
		idle_node.animation = crouch_idle_name
		blend_space.add_blend_point(idle_node, Vector2(0, 0))

	# 4方向（しゃがみ歩き）- TPS Demo座標系
	if not crouch_walk_name.is_empty():
		var forward_node = AnimationNodeAnimation.new()
		forward_node.animation = crouch_walk_name
		blend_space.add_blend_point(forward_node, Vector2(0, 1))

		var backward_node = AnimationNodeAnimation.new()
		backward_node.animation = crouch_walk_name
		blend_space.add_blend_point(backward_node, Vector2(0, -1))

		var left_node = AnimationNodeAnimation.new()
		left_node.animation = crouch_walk_name
		blend_space.add_blend_point(left_node, Vector2(1, 0))   # TPS Demo: +X = 左移動

		var right_node = AnimationNodeAnimation.new()
		right_node.animation = crouch_walk_name
		blend_space.add_blend_point(right_node, Vector2(-1, 0))  # TPS Demo: -X = 右移動


## BlendSpaceを再構築
func _rebuild_blend_spaces() -> void:
	if _blend_tree == null:
		return

	var walk_node = _blend_tree.get_node("locomotion_walk") as AnimationNodeBlendSpace2D
	if walk_node:
		while walk_node.get_blend_point_count() > 0:
			walk_node.remove_blend_point(0)
		_setup_walk_blend_space(walk_node)

	var crouch_node = _blend_tree.get_node("crouch_walk") as AnimationNodeBlendSpace2D
	if crouch_node:
		while crouch_node.get_blend_point_count() > 0:
			crouch_node.remove_blend_point(0)
		_setup_crouch_blend_space(crouch_node)


## ========================================
## 内部処理: アニメーション検索
## ========================================

## アニメーション名キーから実際のアニメーション名を検索
func _find_animation_by_key(key: String) -> String:
	if anim_player == null:
		return ""

	var candidates = ANIM_CANDIDATES.get(key, [key])
	for candidate in candidates:
		if anim_player.has_animation(candidate):
			return candidate

	# 武器タイプ付きで検索
	var weapon_name = WEAPON_TYPE_NAMES.get(weapon_type, "rifle")
	var weapon_candidates = [
		"%s_%s" % [weapon_name, key],
		"%s_%s" % [key, weapon_name],
	]
	for candidate in weapon_candidates:
		if anim_player.has_animation(candidate):
			return candidate

	return ""


## アニメーション名リストから最初に見つかったものを返す
func _find_animation(candidates: Array) -> String:
	for anim_name in candidates:
		if anim_player.has_animation(anim_name):
			return anim_name
	return ""


## 上半身ボーンフィルターを設定
func _setup_upper_body_filter(blend_node: AnimationNodeBlend2) -> void:
	blend_node.filter_enabled = true

	var upper_body_bones := BoneNameRegistry.get_upper_body_bones(skeleton)

	var armature_path = ""
	var armature = skeleton.get_parent()
	if armature and armature.name == "Armature":
		armature_path = "Armature/"

	var filter_count := 0
	for bone_name in upper_body_bones:
		var bone_idx = skeleton.find_bone(bone_name)
		if bone_idx >= 0:
			var bone_path = "%sSkeleton3D:%s" % [armature_path, bone_name]
			blend_node.set_filter_path(NodePath(bone_path), true)
			filter_count += 1


## ========================================
## 内部処理: アニメーション更新
## ========================================

## 移動アニメーションを更新
func _update_locomotion_animation() -> void:
	if _blend_tree == null or anim_tree == null:
		return

	# Idle/Run アニメーションを設定
	var idle_name = _find_animation_by_key("idle")
	var run_name = _find_animation_by_key("run_forward")

	var idle_node = _blend_tree.get_node("locomotion_idle") as AnimationNodeAnimation
	var run_node = _blend_tree.get_node("locomotion_run") as AnimationNodeAnimation
	if idle_node and not idle_name.is_empty():
		idle_node.animation = idle_name
	if run_node and not run_name.is_empty():
		run_node.animation = run_name

	# Crouch Idle アニメーションを設定
	var crouch_idle_name = _find_animation_by_key("crouch_idle")
	var crouch_idle_node = _blend_tree.get_node("crouch_idle") as AnimationNodeAnimation
	if crouch_idle_node:
		crouch_idle_node.animation = crouch_idle_name if not crouch_idle_name.is_empty() else idle_name

	# 姿勢遷移（standing/crouching）
	var posture_request = "standing" if posture_state == PostureState.STANDING else "crouching"
	anim_tree.set("parameters/posture_transition/transition_request", posture_request)

	# 移動状態遷移
	if posture_state == PostureState.STANDING:
		var stand_request: String
		match locomotion_state:
			LocomotionState.IDLE:
				stand_request = "idle"
			LocomotionState.WALK:
				stand_request = "walk"
			LocomotionState.RUN:
				stand_request = "run"
		anim_tree.set("parameters/stand_transition/transition_request", stand_request)
	else:
		# しゃがみ時
		var crouch_request = "idle" if locomotion_state == LocomotionState.IDLE else "walk"
		anim_tree.set("parameters/crouch_transition/transition_request", crouch_request)


## ストレイフブレンド座標を更新
## TPS Demo方式: Vector2(motion.x, -motion.y) - 両軸を反転
## 理由: get_strafe_blend()は右=+X、前=+Yを返すが
##       BlendSpace2Dは左=+X、前=+Yを期待する
func _update_strafe_blend() -> void:
	if anim_tree == null or not anim_tree.active:
		return

	# WALK状態でストレイフが有効な場合
	if locomotion_state == LocomotionState.WALK and _strafe_enabled:
		# X軸: 左右反転（get_strafe_blendは右=+X、BlendSpace2Dは左=+X）
		# Y軸: 前後反転（TPS Demo方式）
		var blend_pos = Vector2(-_strafe_blend_x, -_strafe_blend_y)

		if posture_state == PostureState.STANDING:
			anim_tree.set("parameters/locomotion_walk/blend_position", blend_pos)
		else:
			anim_tree.set("parameters/crouch_walk/blend_position", blend_pos)


## 射撃ブレンド値を更新
func _update_shooting_blend(delta: float) -> void:
	if anim_tree == null or not anim_tree.active:
		return

	var target = 1.0 if is_shooting else 0.0
	_shooting_blend = lerp(_shooting_blend, target, SHOOTING_BLEND_SPEED * delta)


## 上半身エイミング角度を更新
func _update_upper_body_aim(delta: float) -> void:
	_current_aim_rotation = lerp(_current_aim_rotation, _target_aim_rotation, aim_rotation_speed * delta)
	_current_pitch_rotation = lerp(_current_pitch_rotation, _target_pitch_rotation, aim_rotation_speed * delta)


## 上半身リコイルを回復
func _recover_upper_body_recoil(delta: float) -> void:
	if _upper_body_recoil > 0.001:
		_upper_body_recoil = lerpf(_upper_body_recoil, 0.0, UPPER_BODY_RECOIL_RECOVERY_SPEED * delta)
	else:
		_upper_body_recoil = 0.0


## アニメーション終了時
func _on_animation_finished(anim_name: StringName) -> void:
	animation_finished.emit(String(anim_name))


## 移動系アニメーションのループ設定
func _setup_animation_loops() -> void:
	if anim_player == null:
		return

	var loop_patterns = [
		"walk", "run", "idle", "sprint", "retreat", "strafe",
		"forward", "backward", "jog", "crouch"
	]

	for anim_name in anim_player.get_animation_list():
		var anim = anim_player.get_animation(anim_name)
		if anim == null:
			continue

		var lower_name = anim_name.to_lower()
		for pattern in loop_patterns:
			if pattern in lower_name:
				anim.loop_mode = Animation.LOOP_LINEAR
				break


## ========================================
## 死亡アニメーション
## ========================================

## 死亡アニメーションを再生
func play_death_animation(_weapon_type_param: int = 1) -> void:
	if anim_player == null:
		death_animation_finished.emit()
		return

	var death_name = _find_animation_by_key("death")

	if death_name.is_empty():
		push_warning("[AnimationComponent] No death animation found")
		death_animation_finished.emit()
		return

	if anim_tree and anim_tree.active:
		anim_tree.active = false

	var anim = anim_player.get_animation(death_name)
	if anim:
		anim.loop_mode = Animation.LOOP_NONE

	anim_player.play(death_name, 0.1)

	await anim_player.animation_finished
	death_animation_finished.emit()
