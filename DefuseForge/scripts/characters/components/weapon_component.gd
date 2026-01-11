class_name WeaponComponent
extends Node

## 武器管理コンポーネント
## 武器装着、左手IK、リコイルを担当

signal weapon_changed(weapon_id: int)

## 内部参照
var skeleton: Skeleton3D
var weapon_attachment: BoneAttachment3D
var current_weapon: Node3D
var weapon_resource: WeaponResource

## 武器状態
var current_weapon_id: int = 0  # WeaponRegistry.WeaponId.NONE

## 左手IK
var left_hand_ik: SkeletonIK3D
var left_hand_ik_target: Marker3D
var _left_hand_grip_source: Node3D
var _left_hand_ik_offset: Vector3 = Vector3.ZERO
var _left_hand_ik_rotation: Vector3 = Vector3.ZERO
var _ik_interpolation_tween: Tween

## リコイル
var _weapon_recoil_offset: Vector3 = Vector3.ZERO
const RECOIL_RECOVERY_SPEED: float = 8.0

## IK補間
const IK_BLEND_DURATION: float = 0.25


func _ready() -> void:
	pass


## 初期化
## @param skel: Skeleton3D
func setup(skel: Skeleton3D) -> void:
	skeleton = skel


## 武器を設定
## @param weapon_id: WeaponRegistry.WeaponId
func set_weapon(weapon_id: int) -> void:
	if current_weapon_id == weapon_id:
		return

	# 既存のIKを削除
	_cleanup_left_hand_ik()

	# 既存の武器を削除
	_cleanup_weapon()

	current_weapon_id = weapon_id

	# 武器なしの場合
	if weapon_id == WeaponRegistry.WeaponId.NONE:
		weapon_resource = null
		weapon_changed.emit(weapon_id)
		return

	# WeaponResourceをロード
	weapon_resource = WeaponRegistry.get_weapon(weapon_id)
	if weapon_resource == null:
		push_error("[WeaponComponent] Failed to load weapon resource for id: %d" % weapon_id)
		return

	# 武器を装着
	_attach_weapon()

	# 左手IKを設定
	_setup_left_hand_ik()

	weapon_changed.emit(weapon_id)


## 現在の武器IDを取得
func get_weapon_id() -> int:
	return current_weapon_id


## 武器リソースを取得
func get_weapon_resource() -> WeaponResource:
	return weapon_resource


## リコイルを適用
## @param intensity: リコイル強度（0.0 - 1.0）
func apply_recoil(intensity: float) -> void:
	# 武器を後ろに跳ねさせる
	_weapon_recoil_offset = Vector3(0, 0.02, 0.05) * intensity


## IKを更新（毎フレーム呼ばれる）
func update_ik() -> void:
	_update_left_hand_ik_target()
	_recover_recoil()


## IKを無効化（リロード時等に呼ぶ）
func disable_ik() -> void:
	if left_hand_ik == null:
		return

	_cancel_ik_tween()
	if left_hand_ik.is_running():
		left_hand_ik.interpolation = 0.0
		left_hand_ik.stop()


## IKを有効化
func enable_ik() -> void:
	if left_hand_ik == null or left_hand_ik.is_running():
		return

	_cancel_ik_tween()
	left_hand_ik.start()

	# Tweenでスムーズに補間
	_ik_interpolation_tween = get_tree().create_tween()
	_ik_interpolation_tween.tween_property(left_hand_ik, "interpolation", 1.0, IK_BLEND_DURATION)


## 武器を装着
func _attach_weapon() -> void:
	if skeleton == null or weapon_resource == null:
		return

	# 右手ボーンを検索
	var right_hand_bones := ["c_hand_ik.r", "hand.r", "c_hand_fk.r"]
	var bone_idx := -1
	for bone_name in right_hand_bones:
		bone_idx = skeleton.find_bone(bone_name)
		if bone_idx >= 0:
			break

	if bone_idx < 0:
		push_warning("[WeaponComponent] Right hand bone not found")
		return

	# BoneAttachment3Dを作成
	weapon_attachment = BoneAttachment3D.new()
	weapon_attachment.name = "WeaponAttachment"
	weapon_attachment.bone_idx = bone_idx
	skeleton.add_child(weapon_attachment)

	# 武器シーンをロード
	if not ResourceLoader.exists(weapon_resource.scene_path):
		push_error("[WeaponComponent] Weapon scene not found: %s" % weapon_resource.scene_path)
		return

	var weapon_scene = load(weapon_resource.scene_path)
	if weapon_scene == null:
		push_error("[WeaponComponent] Failed to load weapon scene: %s" % weapon_resource.scene_path)
		return

	current_weapon = weapon_scene.instantiate()
	weapon_attachment.add_child(current_weapon)

	# スケルトンのスケール補正
	var skeleton_scale = skeleton.global_transform.basis.get_scale()
	if skeleton_scale.x < 0.5:
		var compensation = 1.0 / skeleton_scale.x
		current_weapon.scale = Vector3(compensation, compensation, compensation)

	# 装着位置を適用
	current_weapon.position = weapon_resource.attach_position
	current_weapon.rotation_degrees = weapon_resource.attach_rotation


## 左手IKを設定
func _setup_left_hand_ik() -> void:
	if skeleton == null or weapon_attachment == null or current_weapon == null:
		return

	# WeaponResourceからIK設定を読み込み
	if weapon_resource:
		_left_hand_ik_offset = weapon_resource.left_hand_ik_position
		_left_hand_ik_rotation = weapon_resource.left_hand_ik_rotation

		if not weapon_resource.left_hand_ik_enabled:
			return

	# 左手ボーンを検索
	var left_hand_bones := ["c_hand_ik.l", "c_hand_fk.l", "hand.l", "LeftHand"]
	var left_hand_bone_idx := -1
	for bone_name in left_hand_bones:
		var idx = skeleton.find_bone(bone_name)
		if idx >= 0:
			left_hand_bone_idx = idx
			break

	if left_hand_bone_idx < 0:
		return

	# 武器内のLeftHandGripを検索
	var grip = _find_left_hand_grip()
	if grip == null:
		return

	# IKターゲット用Marker3Dを作成
	left_hand_ik_target = Marker3D.new()
	left_hand_ik_target.name = "LeftHandIKTarget"
	skeleton.add_child(left_hand_ik_target)

	# SkeletonIK3Dを作成
	left_hand_ik = SkeletonIK3D.new()
	left_hand_ik.name = "LeftHandIK"

	# チップボーン設定
	var tip_bone_name = skeleton.get_bone_name(left_hand_bone_idx)
	left_hand_ik.set_tip_bone(tip_bone_name)

	# ルートボーンを検索
	var root_bone_names := ["c_arm_fk.l", "c_arm_ik.l", "arm.l", "c_shoulder.l", "shoulder.l"]
	var root_bone_name := ""
	for bone_name in root_bone_names:
		if skeleton.find_bone(bone_name) >= 0:
			root_bone_name = bone_name
			break

	if root_bone_name.is_empty():
		left_hand_ik_target.queue_free()
		left_hand_ik_target = null
		left_hand_ik.queue_free()
		left_hand_ik = null
		return

	# ボーン階層を検証（root_bone が tip_bone の祖先か確認）
	var root_idx = skeleton.find_bone(root_bone_name)
	var is_valid_chain = false
	var check_idx = left_hand_bone_idx
	while check_idx >= 0:
		if check_idx == root_idx:
			is_valid_chain = true
			break
		check_idx = skeleton.get_bone_parent(check_idx)

	if not is_valid_chain:
		push_warning("[WeaponComponent] IK chain invalid: %s is not ancestor of %s. Skeleton may have flat hierarchy (ARP deform-only export). IK disabled." % [root_bone_name, tip_bone_name])
		left_hand_ik_target.queue_free()
		left_hand_ik_target = null
		left_hand_ik.queue_free()
		left_hand_ik = null
		return

	left_hand_ik.set_root_bone(root_bone_name)
	left_hand_ik.set_target_node(left_hand_ik_target.get_path())

	# IK設定
	left_hand_ik.interpolation = 1.0
	left_hand_ik.override_tip_basis = true

	skeleton.add_child(left_hand_ik)
	left_hand_ik.start()

	_left_hand_grip_source = grip
	print("[WeaponComponent] Left hand IK enabled - root: %s, tip: %s" % [root_bone_name, tip_bone_name])


## 左手グリップを検索
func _find_left_hand_grip() -> Node3D:
	if current_weapon == null:
		return null

	var model_node = current_weapon.get_node_or_null("Model")
	if model_node == null:
		model_node = current_weapon

	# 汎用名で検索
	var grip = _find_node_recursive(model_node, "LeftHandGrip")
	if grip:
		return grip

	# 武器ID別名で検索（例: LeftHandGrip_AK47）
	if weapon_resource:
		var weapon_name = weapon_resource.weapon_id.to_upper()
		var specific_grip_name = "LeftHandGrip_%s" % weapon_name
		grip = _find_node_recursive(model_node, specific_grip_name)

	return grip


## IKターゲット位置を更新
func _update_left_hand_ik_target() -> void:
	if left_hand_ik_target == null or _left_hand_grip_source == null:
		return

	var grip_transform = _left_hand_grip_source.global_transform

	# 位置オフセットを適用
	var offset_global = grip_transform.basis * _left_hand_ik_offset
	grip_transform.origin += offset_global

	# 回転オフセットを適用
	var rot_x = Basis(Vector3.RIGHT, deg_to_rad(_left_hand_ik_rotation.x))
	var rot_y = Basis(Vector3.UP, deg_to_rad(_left_hand_ik_rotation.y))
	var rot_z = Basis(Vector3.FORWARD, deg_to_rad(_left_hand_ik_rotation.z))
	var rotation_offset = rot_x * rot_y * rot_z
	grip_transform.basis = grip_transform.basis * rotation_offset

	left_hand_ik_target.global_transform = grip_transform


## リコイルを回復
func _recover_recoil() -> void:
	if _weapon_recoil_offset.length_squared() > 0.0001:
		_weapon_recoil_offset = _weapon_recoil_offset.lerp(Vector3.ZERO, RECOIL_RECOVERY_SPEED * get_process_delta_time())

		# 武器に反映
		if current_weapon:
			current_weapon.position = weapon_resource.attach_position + _weapon_recoil_offset


## 左手IKをクリーンアップ
func _cleanup_left_hand_ik() -> void:
	_cancel_ik_tween()

	if left_hand_ik:
		left_hand_ik.stop()
		left_hand_ik.queue_free()
		left_hand_ik = null

	if left_hand_ik_target:
		left_hand_ik_target.queue_free()
		left_hand_ik_target = null

	_left_hand_grip_source = null


## 武器をクリーンアップ
func _cleanup_weapon() -> void:
	if weapon_attachment:
		weapon_attachment.queue_free()
		weapon_attachment = null

	current_weapon = null


## IK Tweenをキャンセル
func _cancel_ik_tween() -> void:
	if _ik_interpolation_tween and _ik_interpolation_tween.is_running():
		_ik_interpolation_tween.kill()
		_ik_interpolation_tween = null


## ノードを再帰的に検索
func _find_node_recursive(parent: Node, target_name: String) -> Node:
	for child in parent.get_children():
		if child.name == target_name:
			return child
		var found = _find_node_recursive(child, target_name)
		if found:
			return found
	return null
