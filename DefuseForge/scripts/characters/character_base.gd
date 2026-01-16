class_name CharacterBase
extends CharacterBody3D

## キャラクター基底クラス
## コンポーネントを統合し、シンプルなAPIを提供

## チーム定義
enum Team { NONE = 0, COUNTER_TERRORIST = 1, TERRORIST = 2 }

const CharacterActionState = preload("res://scripts/resources/action_state.gd")
const MovementComponentScript = preload("res://scripts/characters/components/movement_component.gd")
const AnimationComponentScript = preload("res://scripts/characters/components/animation_component.gd")
const WeaponComponentScript = preload("res://scripts/characters/components/weapon_component.gd")
const HealthComponentScript = preload("res://scripts/characters/components/health_component.gd")
const VisionComponentScript = preload("res://scripts/characters/components/vision_component.gd")
const OutlineComponentScript = preload("res://scripts/characters/components/outline_component.gd")
const CharacterAPIScript = preload("res://scripts/api/character_api.gd")

## ユーティリティクラス
const VisionMath = preload("res://scripts/utils/vision_math.gd")
const PositionHelper = preload("res://scripts/utils/position_helper.gd")
const RaycastHelper = preload("res://scripts/utils/raycast_helper.gd")

## シグナル
signal path_completed
signal waypoint_reached(index: int)
signal died(killer: Node3D)
signal damaged(amount: float, attacker: Node3D, is_headshot: bool)
signal weapon_changed(weapon_id: int)
signal locomotion_changed(state: int)
signal action_started(action_type: int)
signal action_completed(action_type: int)
signal crouch_changed(is_crouching: bool)

## エクスポート設定
@export_group("移動設定")
@export var base_walk_speed: float = 1.5  ## アニメーション基準速度に合わせる
@export var base_run_speed: float = 4.0   ## アニメーション基準速度に合わせる

@export_group("HP設定")
@export var max_health: float = 100.0

@export_group("チーム設定")
@export var team: Team = Team.NONE

@export_group("キャラクター設定")
## キャラクターID（"vanguard", "phantom"など）
## 設定するとアニメーションが自動セットアップされる
@export var character_id: String = ""

@export_group("自動照準設定")
@export var auto_aim_enabled: bool = true

## コンポーネント参照
var movement: Node  # MovementComponent
var animation: Node  # AnimationComponent
var weapon: Node     # WeaponComponent
var health: Node     # HealthComponent
var vision: Node     # VisionComponent
var outline: Node    # OutlineComponent

## 内部参照
var skeleton: Skeleton3D
var model: Node3D

## アクション状態
var current_action: int = CharacterActionState.ActionType.NONE
var _action_timer: float = 0.0

## 生存状態
var is_alive: bool = true

## しゃがみ状態
var is_crouching: bool = false

## しゃがみ設定
const STAND_COLLISION_HEIGHT: float = 1.8
const CROUCH_COLLISION_HEIGHT: float = 1.0
const STAND_COLLISION_Y: float = 0.9
const CROUCH_COLLISION_Y: float = 0.5

## 自動照準ターゲット
var _current_target: CharacterBase = null


func _ready() -> void:
	add_to_group("characters")
	_find_model_and_skeleton()
	_setup_components()
	_connect_signals()
	# character_idが設定されている場合、アニメーションを自動セットアップ
	if not character_id.is_empty():
		CharacterAPIScript.setup_animations(self, character_id)


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	# アクションタイマー更新
	_update_action_timer(delta)

	# コンポーネント更新
	if movement:
		velocity = movement.update(delta)
		# アニメーション速度を移動速度に合わせる
		if animation:
			var current_speed = velocity.length()
			animation.set_animation_speed(current_speed, movement.is_running)
	if weapon:
		weapon.update()
		weapon.update_ik()
	if vision:
		vision.update(delta)

	# 視線ポイント回転更新（Slice the Pie）- 自動照準より優先
	if movement and movement.has_vision_points():
		_update_vision_point_rotation()
	else:
		# 自動照準更新
		_update_auto_aim()

	# ストレイフブレンド座標を更新（視線ポイント処理後に実行）
	if movement:
		_update_strafe_blend()

	# アニメーション更新（ストレイフブレンド適用後）
	if animation:
		animation.update(delta)

	# ルートモーションを適用（アニメーションの移動をキャラクターに反映）
	_apply_root_motion()

	# 敵の可視性を更新（プレイヤーの視界内にいるときのみ表示）
	update_enemy_visibility()

	move_and_slide()


## _process()で最終的なボーン調整（レンダリング直前）
func _process(_delta: float) -> void:
	if not is_alive:
		return

	# 上半身回転を最終適用（アニメーション処理後に確実に適用）
	if animation and skeleton:
		animation.apply_final_upper_body_rotation()

	# Hipsボーンオフセット補正（アニメーションのルートモーションを打ち消す）
	_compensate_hips_offset()


## モデルとスケルトンを検索
func _find_model_and_skeleton() -> void:
	# CharacterModelを検索
	model = get_node_or_null("CharacterModel")
	if model == null:
		# 子ノードから検索
		for child in get_children():
			if child is Node3D and child.name.contains("Model"):
				model = child
				break

	if model == null:
		push_warning("[CharacterBase] %s: CharacterModel not found" % name)
		return

	# スケルトンを検索
	skeleton = model.get_node_or_null("Armature/Skeleton3D")
	if skeleton == null:
		skeleton = _find_skeleton_recursive(model)

	if skeleton == null:
		push_warning("[CharacterBase] %s: Skeleton3D not found" % name)


## スケルトンを再帰検索
func _find_skeleton_recursive(node: Node) -> Skeleton3D:
	for child in node.get_children():
		if child is Skeleton3D:
			return child
		var found = _find_skeleton_recursive(child)
		if found:
			return found
	return null


## コンポーネントをセットアップ
func _setup_components() -> void:
	# MovementComponent
	movement = get_node_or_null("MovementComponent")
	if movement == null:
		movement = Node.new()
		movement.set_script(MovementComponentScript)
		movement.name = "MovementComponent"
		add_child(movement)

	movement.walk_speed = base_walk_speed
	movement.run_speed = base_run_speed

	# HealthComponent
	health = get_node_or_null("HealthComponent")
	if health == null:
		health = Node.new()
		health.set_script(HealthComponentScript)
		health.name = "HealthComponent"
		add_child(health)

	health.max_health = max_health

	# AnimationComponent
	animation = get_node_or_null("AnimationComponent")
	if animation == null:
		animation = Node.new()
		animation.set_script(AnimationComponentScript)
		animation.name = "AnimationComponent"
		add_child(animation)

	if skeleton and model:
		animation.setup(model, skeleton)

	# WeaponComponent
	weapon = get_node_or_null("WeaponComponent")
	if weapon == null:
		weapon = Node.new()
		weapon.set_script(WeaponComponentScript)
		weapon.name = "WeaponComponent"
		add_child(weapon)

	if skeleton:
		weapon.setup(skeleton, self)

	# スケルトン更新シグナルを接続
	if skeleton:
		skeleton.skeleton_updated.connect(_on_skeleton_updated)

	# VisionComponent
	vision = get_node_or_null("VisionComponent")
	if vision == null:
		vision = Node.new()
		vision.set_script(VisionComponentScript)
		vision.name = "VisionComponent"
		add_child(vision)

	# OutlineComponent
	outline = get_node_or_null("OutlineComponent")
	if outline == null:
		outline = Node.new()
		outline.set_script(OutlineComponentScript)
		outline.name = "OutlineComponent"
		add_child(outline)
	# Note: outline.setup() is called separately via setup_outline_camera()


## シグナルを接続
func _connect_signals() -> void:
	if movement:
		movement.path_completed.connect(func(): path_completed.emit())
		movement.waypoint_reached.connect(func(idx): waypoint_reached.emit(idx))
		movement.locomotion_changed.connect(_on_locomotion_changed)

	if health:
		health.died.connect(_on_died)
		health.damaged.connect(_on_damaged)

	if weapon:
		weapon.weapon_changed.connect(func(id): weapon_changed.emit(id))


## ========================================
## モデル管理 API
## ========================================

## モデルをリロードし、全コンポーネントを再初期化
## CharacterModelノードを入れ替えた後に呼び出す
func reload_model(new_model: Node3D = null) -> void:
	# 既存のシグナル接続を切断
	if skeleton and skeleton.skeleton_updated.is_connected(_on_skeleton_updated):
		skeleton.skeleton_updated.disconnect(_on_skeleton_updated)

	# モデル参照を更新
	if new_model:
		model = new_model

	# 再初期化
	_find_model_and_skeleton()
	_setup_components()
	_connect_signals()


## ========================================
## 移動 API
## ========================================

## パスを設定して移動開始
func set_path(points: Array[Vector3], run: bool = false) -> void:
	if movement:
		movement.set_path(points, run)


## 視線ポイント付きでパスを設定（Slice the Pie）
## @param vision_pts: 視線ポイント配列 [{ path_ratio, anchor, direction }, ...]
func set_path_with_vision_points(movement_points: Array[Vector3], vision_pts: Array, run: bool = false) -> void:
	if movement:
		movement.set_path_with_vision_points(movement_points, vision_pts, run)


## 単一の目標地点に移動
func move_to(target: Vector3, run: bool = false) -> void:
	if movement:
		movement.move_to(target, run)


## 移動を停止
func stop() -> void:
	if movement:
		movement.stop()


## 走る/歩くを切り替え
func set_running(running: bool) -> void:
	if movement:
		movement.set_running(running)


## 移動中かどうか
func is_moving() -> bool:
	return movement.is_moving if movement else false


## ========================================
## 武器 API
## ========================================

## 武器を設定
func set_weapon(weapon_id: int) -> void:
	if weapon:
		weapon.set_weapon(weapon_id)

	# アニメーションコンポーネントにも通知
	if animation and weapon and weapon.weapon_resource:
		animation.set_weapon_type(weapon.weapon_resource.weapon_type)


## 現在の武器IDを取得
func get_weapon_id() -> int:
	return weapon.get_weapon_id() if weapon else 0


## 現在の武器IDを取得（エイリアス）
func get_current_weapon_id() -> int:
	return get_weapon_id()


## 武器リソースを取得
func get_weapon_resource() -> WeaponResource:
	return weapon.get_weapon_resource() if weapon else null


## リコイルを適用
func apply_recoil(intensity: float = 1.0) -> void:
	if weapon:
		weapon.apply_recoil(intensity)
	if animation:
		animation.apply_upper_body_recoil(intensity)


## ========================================
## アニメーション API
## ========================================

## アニメーションを再生
func play_animation(anim_name: String, blend_time: float = 0.3) -> void:
	if animation:
		animation.play_animation(anim_name, blend_time)
	else:
		push_warning("[CharacterBase] animation component is null!")


## 射撃状態を設定
func set_shooting(shooting: bool) -> void:
	if animation:
		animation.set_shooting(shooting)


## 上半身回転を設定
func set_upper_body_rotation(yaw_degrees: float, pitch_degrees: float = 0.0) -> void:
	if animation:
		animation.apply_spine_rotation(yaw_degrees, pitch_degrees)


## アニメーションリストを取得
func get_animation_list() -> PackedStringArray:
	return animation.get_animation_list() if animation else PackedStringArray()


## ========================================
## HP API
## ========================================

## ダメージを受ける
func take_damage(amount: float, attacker: Node3D = null, is_headshot: bool = false) -> void:
	if health:
		health.take_damage(amount, attacker, is_headshot)


## 回復
func heal(amount: float) -> void:
	if health:
		health.heal(amount)


## HP割合を取得
func get_health_ratio() -> float:
	return health.get_health_ratio() if health else 0.0


## HPを取得
func get_health() -> float:
	return health.health if health else 0.0


## ========================================
## チーム API
## ========================================

## 対象が敵チームかどうか判定
## @param other: 判定対象のキャラクター
## @return: 敵チームならtrue
func is_enemy_of(other: CharacterBase) -> bool:
	if other == null:
		return false
	if team == Team.NONE or other.team == Team.NONE:
		return false
	return team != other.team


## ========================================
## アクション API
## ========================================

## アクションを開始
func start_action(action_type: int, duration: float) -> void:
	if current_action != CharacterActionState.ActionType.NONE:
		return

	current_action = action_type
	_action_timer = duration
	action_started.emit(action_type)


## アクションをキャンセル
func cancel_action() -> void:
	if current_action == CharacterActionState.ActionType.NONE:
		return

	current_action = CharacterActionState.ActionType.NONE
	_action_timer = 0.0


## アクション中かどうか
func is_in_action() -> bool:
	return current_action != CharacterActionState.ActionType.NONE


## アクションタイマーを更新
func _update_action_timer(delta: float) -> void:
	if current_action == CharacterActionState.ActionType.NONE:
		return

	_action_timer -= delta
	if _action_timer <= 0:
		var completed_action = current_action
		current_action = CharacterActionState.ActionType.NONE
		action_completed.emit(completed_action)


## ========================================
## ストレイフ（8方向移動）
## ========================================

## ストレイフブレンド座標を更新
func _update_strafe_blend() -> void:
	if not movement or not animation:
		return

	# ストレイフモード時のみブレンド座標を更新
	if movement.strafe_mode and movement.is_moving:
		var blend = movement.get_strafe_blend()
		animation.set_strafe_blend(blend.x, blend.y)
	else:
		animation.disable_strafe()


## ストレイフモードを有効化
## @param facing_direction: 視線方向（ワールド座標）
func enable_strafe(facing_direction: Vector3 = Vector3.ZERO) -> void:
	if movement:
		if facing_direction == Vector3.ZERO:
			# デフォルトは現在の向き
			facing_direction = -global_transform.basis.z
		movement.enable_strafe_mode(facing_direction)


## ストレイフモードを無効化
func disable_strafe() -> void:
	if movement:
		movement.disable_strafe_mode()
	if animation:
		animation.disable_strafe()


## ========================================
## ルートモーション / Hipsボーン補正
## ========================================

## アニメーションのルートモーションをキャラクターに適用（無効化）
## 注: player.glbのアニメーションはrootボーントラックがないため、
##     代わりに_compensate_hips_offset()でHipsボーンオフセットを補正
func _apply_root_motion() -> void:
	pass  # ルートモーション抽出は無効化（代わりにHips補正を使用）


## Hipsボーンのオフセットを補正
## アニメーションでHipsボーンが移動してもモデルがCharacterBody3Dに固定されるようにする
func _compensate_hips_offset() -> void:
	if skeleton == null or model == null:
		return

	# Hipsボーンを検索
	var hips_idx := -1
	for i in range(skeleton.get_bone_count()):
		var bone_name = skeleton.get_bone_name(i)
		var lower_name = bone_name.to_lower()
		if "hip" in lower_name or "pelvis" in lower_name:
			hips_idx = i
			break

	if hips_idx < 0:
		return

	# Hipsボーンのローカル位置を取得
	var hips_pose_pos = skeleton.get_bone_pose_position(hips_idx)

	# XZ平面でのオフセットを取得（Y軸は高さなので無視）
	var offset_xz = Vector3(hips_pose_pos.x, 0, hips_pose_pos.z)

	# オフセットが小さければ補正不要
	if offset_xz.length_squared() < 0.001:
		return

	# Armatureノードを取得
	var armature = skeleton.get_parent()
	if armature == null:
		return

	# Armatureの位置を逆オフセットで調整（モデルをCharacterBody3Dに固定）
	armature.position.x = -offset_xz.x
	armature.position.z = -offset_xz.z


## ========================================
## しゃがみ API
## ========================================

## しゃがみ状態をトグル
func toggle_crouch() -> void:
	set_crouching(not is_crouching)


## しゃがみ状態を設定
func set_crouching(crouch: bool) -> void:
	if is_crouching == crouch:
		return

	is_crouching = crouch
	_update_collision_for_crouch()

	if animation:
		animation.set_crouching(is_crouching)

	crouch_changed.emit(is_crouching)


## しゃがみ時のコリジョン形状を更新
func _update_collision_for_crouch() -> void:
	var collision_shape = get_node_or_null("CollisionShape3D")
	if collision_shape == null:
		return

	if collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		if is_crouching:
			capsule.height = CROUCH_COLLISION_HEIGHT
			collision_shape.position.y = CROUCH_COLLISION_Y
		else:
			capsule.height = STAND_COLLISION_HEIGHT
			collision_shape.position.y = STAND_COLLISION_Y


## ========================================
## 自動照準（内部処理）
## ========================================

## 銃口のグローバル位置を取得
func _get_muzzle_position() -> Vector3:
	if weapon and weapon.current_weapon:
		var muzzle = weapon.current_weapon.find_child("MuzzlePoint", true, false)
		if muzzle:
			return muzzle.global_position
	# フォールバック: キャラクター位置 + 目の高さ + 前方オフセット
	return global_position + Vector3(0, 1.5, 0) + global_transform.basis.z * 0.3


## 自動照準の更新処理
func _update_auto_aim() -> void:
	if not auto_aim_enabled or not is_alive:
		return

	var enemy = _find_enemy_in_vision()
	_current_target = enemy

	if enemy:
		# 銃口位置から敵の腹部への方向ベクトル
		var muzzle_pos = _get_muzzle_position()
		var target_pos = enemy.global_position + Vector3(0, 0.7, 0)  # 腹部
		var to_enemy_3d = target_pos - muzzle_pos

		# ヨー角度（水平）- XZ平面で計算
		var to_enemy_xz = Vector3(to_enemy_3d.x, 0, to_enemy_3d.z)
		var forward = global_transform.basis.z
		forward.y = 0
		var yaw_angle = rad_to_deg(forward.signed_angle_to(to_enemy_xz, Vector3.UP))
		var clamped_yaw = clamp(yaw_angle, -45.0, 45.0)

		# ピッチ角度（垂直）- 水平距離と高低差から計算
		# 符号を逆にしてボーン座標系に合わせる
		var horizontal_dist = to_enemy_xz.length()
		var vertical_diff = to_enemy_3d.y
		var pitch_angle = -rad_to_deg(atan2(vertical_diff, horizontal_dist))
		var clamped_pitch = clamp(pitch_angle, -30.0, 30.0)

		# 上半身回転の範囲内にクランプして適用（ヨー + ピッチ）
		set_upper_body_rotation(clamped_yaw, clamped_pitch)
	else:
		# 敵がいない場合は上半身回転をリセット
		set_upper_body_rotation(0.0, 0.0)


## 視線ポイントに基づく回転の更新（Slice the Pie + 上半身優先）
## 上半身回転限界（度）
const UPPER_BODY_ROTATION_LIMIT: float = 45.0

## 現在の移動方向を取得（次のウェイポイントへの方向）
func _get_current_move_direction() -> Vector3:
	if not movement or not movement.is_moving:
		return Vector3.ZERO

	if movement.waypoints.is_empty() or movement.current_waypoint_index >= movement.waypoints.size():
		return Vector3.ZERO

	var current_pos = global_position
	current_pos.y = 0
	var target = movement.waypoints[movement.current_waypoint_index]
	var target_xz = Vector3(target.x, 0, target.z)

	var direction = (target_xz - current_pos).normalized()
	return direction

func _update_vision_point_rotation() -> void:
	if not movement or not animation:
		return

	var vision_direction = movement.get_current_vision_direction()
	if vision_direction == Vector3.ZERO:
		# 視線ポイントがない場合は通常歩行
		if movement.strafe_mode:
			disable_strafe()
		set_upper_body_rotation(0.0, 0.0)
		return

	# 視線方向を正規化
	vision_direction.y = 0
	vision_direction = vision_direction.normalized()

	# キャラクターの進行方向（下半身の向き）を取得
	var forward = global_transform.basis.z  # +Zが前方
	forward.y = 0
	forward = forward.normalized()

	# vision方向の絶対角度を計算
	var vision_angle = atan2(vision_direction.x, vision_direction.z)

	# 進行方向（次のウェイポイントへの方向）を取得
	var move_direction = _get_current_move_direction()
	if move_direction.length_squared() < 0.001:
		move_direction = forward

	# 進行方向の絶対角度
	var move_angle = atan2(move_direction.x, move_direction.z)

	# 進行方向とvision方向の角度差
	var angle_diff = rad_to_deg(wrapf(vision_angle - move_angle, -PI, PI))

	if absf(angle_diff) <= UPPER_BODY_ROTATION_LIMIT:
		# 上半身だけで対応可能 - 通常歩行 + 上半身回転
		if movement.strafe_mode:
			disable_strafe()
		# 下半身は進行方向を向く（MovementComponent._rotate_toward()に任せる）
		# 上半身をvision方向に回転
		set_upper_body_rotation(-angle_diff, 0.0)
	else:
		# 上半身回転限界を超えた - 下半身も追従
		# 下半身の目標角度 = vision角度 - sign(差分) * 45度
		var body_target_angle = vision_angle - deg_to_rad(sign(angle_diff) * UPPER_BODY_ROTATION_LIMIT)
		rotation.y = body_target_angle

		# ストレイフモードを有効化（8方向移動）
		if not movement.strafe_mode:
			movement.enable_strafe_mode(vision_direction)
		movement._facing_direction = vision_direction

		# 上半身を限界角度まで回転
		set_upper_body_rotation(-sign(angle_diff) * UPPER_BODY_ROTATION_LIMIT, 0.0)


## 視界内の敵を検出（FOV + 距離 + レイキャスト方式）
func _find_enemy_in_vision() -> CharacterBase:
	if not vision:
		return null

	# "characters"グループから全キャラクターを取得
	var all_characters = get_tree().get_nodes_in_group("characters")
	var closest_enemy: CharacterBase = null
	var closest_distance: float = INF

	for node in all_characters:
		var character = node as CharacterBase
		if character == null or character == self:
			continue

		var is_enemy = is_enemy_of(character)
		if not is_enemy:
			continue
		if not character.is_alive:
			continue

		# 視界内かチェック
		var in_fov = _is_in_field_of_view(character)
		if in_fov:
			var dist = global_position.distance_to(character.global_position)
			if dist < closest_distance:
				closest_distance = dist
				closest_enemy = character

	return closest_enemy


## 対象が視界内にいるかチェック（FOV + 距離 + 遮蔽物）
func _is_in_field_of_view(target: CharacterBase) -> bool:
	if not vision:
		return false

	var view_distance = vision.view_distance
	var fov_degrees = vision.fov_degrees

	# 距離チェック
	var to_target = target.global_position - global_position
	var distance = to_target.length()
	if distance > view_distance:
		return false

	# FOVチェック（VisionMath使用）
	var forward = global_transform.basis.z  # +Zが前方
	if not VisionMath.is_in_fov(forward, to_target, fov_degrees):
		return false

	# レイキャストで遮蔽物チェック（RaycastHelper + PositionHelper使用）
	var space_state = get_world_3d().direct_space_state
	var eye_pos = PositionHelper.get_eye_position(global_position, vision.eye_height)
	var target_pos = PositionHelper.get_body_position(target.global_position)

	var exclude_rids: Array[RID] = [get_rid(), target.get_rid()]
	var is_blocked = RaycastHelper.is_line_of_sight_blocked(
		space_state, eye_pos, target_pos, vision.wall_collision_mask, exclude_rids
	)

	# 壁に当たらなければ視界内
	return not is_blocked


## ========================================
## コールバック
## ========================================

func _on_locomotion_changed(state: int) -> void:
	locomotion_changed.emit(state)

	# アニメーションを更新
	if animation:
		animation.set_locomotion(state)


func _on_died(killer: Node3D) -> void:
	is_alive = false
	died.emit(killer)

	# 移動停止
	if movement:
		movement.stop()

	# IKを無効化
	if weapon:
		weapon.disable_ik()

	# 視界（FoW）を無効化
	if vision:
		vision.disable()

	# コライダーを無効化
	_disable_collision()

	# 死亡アニメーション再生
	_play_death_animation()


## コライダーを無効化（死亡時）
func _disable_collision() -> void:
	var collision_shape = get_node_or_null("CollisionShape3D")
	if collision_shape:
		collision_shape.disabled = true


## 死亡アニメーションを再生
func _play_death_animation() -> void:
	if animation == null:
		return

	var current_weapon_type = 1  # デフォルト: RIFLE
	if weapon and weapon.weapon_resource:
		current_weapon_type = weapon.weapon_resource.weapon_type

	animation.play_death_animation(current_weapon_type)


func _on_damaged(amount: float, attacker: Node3D, is_headshot: bool) -> void:
	damaged.emit(amount, attacker, is_headshot)


func _on_skeleton_updated() -> void:
	if animation:
		animation.on_skeleton_updated()
	# Apply IK after animation is processed
	if weapon:
		weapon.apply_ik_after_animation()


## ========================================
## 視界 API
## ========================================

## 視野角を設定
func set_vision_fov(degrees: float) -> void:
	if vision:
		vision.set_fov(degrees)


## 視界距離を設定
func set_vision_distance(distance: float) -> void:
	if vision:
		vision.set_view_distance(distance)


## 視界ポリゴンを取得
func get_vision_polygon() -> PackedVector3Array:
	return vision.get_visible_polygon() if vision else PackedVector3Array()


## 壁ヒットポイントを取得
func get_wall_hit_points() -> PackedVector3Array:
	return vision.get_wall_hit_points() if vision else PackedVector3Array()


## ========================================
## 敵視認性 API
## ========================================

## 対象が操作チーム（TERRORIST）の誰かの視界内にいるかチェック
## @param target: チェック対象のキャラクター
## @return: 誰かの視界内ならtrue
static func is_visible_to_player_team(target: CharacterBase) -> bool:
	if target == null or not target.is_alive:
		return false

	var all_characters = target.get_tree().get_nodes_in_group("characters")
	for node in all_characters:
		var character = node as CharacterBase
		if character == null or character == target:
			continue
		if not PlayerManager.is_player_team(character.team) or not character.is_alive:
			continue
		if character._is_in_field_of_view(target):
			return true
	return false


## 敵キャラクターの可視性を更新
func update_enemy_visibility() -> void:
	if not PlayerManager.is_enemy_team(team):
		return
	if model:
		model.visible = CharacterBase.is_visible_to_player_team(self)


## ========================================
## 選択 API
## ========================================

## アウトラインにカメラを設定（SubViewport方式に必要）
func setup_outline_camera(camera: Camera3D) -> void:
	if outline:
		outline.setup(self, camera)


## 選択状態を設定
func set_selected(selected: bool) -> void:
	if outline:
		outline.set_selected(selected)


## 選択状態を取得
func is_selected() -> bool:
	return outline.is_selected() if outline else false


## アウトライン色を設定
func set_outline_color(color: Color) -> void:
	if outline:
		outline.set_outline_color(color)


## アウトライン幅を設定
func set_outline_width(width: float) -> void:
	if outline:
		outline.set_outline_width(width)
