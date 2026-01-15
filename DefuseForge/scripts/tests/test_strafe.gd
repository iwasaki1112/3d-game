extends Node3D

## ストレイフ（8方向移動）テストシーン
## WASD移動 + マウスで視線方向を制御
## Shiftで走る（走り中はストレイフ無効）
## FoW（視界）システム統合

const FogOfWarSystemScript = preload("res://scripts/systems/fog_of_war_system.gd")

@onready var camera: Camera3D = $Camera3D
@onready var character: CharacterBase = $CharacterBody

var _strafe_enabled: bool = true
var _twist_disabled: bool = false  # 限界超えでリセット中かどうか
var fog_of_war_system: Node3D = null

# UI
var _info_label: Label
var _blend_label: Label


func _ready() -> void:
	# UI作成
	_setup_ui()

	# キャラクター初期化を待つ
	await get_tree().process_frame

	# ストレイフモードを有効化（+Zが前方）
	if character:
		var facing = character.global_transform.basis.z
		character.enable_strafe(facing)

	# FoWシステムをセットアップ
	_setup_fog_of_war()

	print("[TestStrafe] Ready")
	print("[TestStrafe] WASD: Move, Mouse: Look direction, Shift: Run")


func _setup_fog_of_war() -> void:
	# FogOfWarSystemを作成
	fog_of_war_system = Node3D.new()
	fog_of_war_system.set_script(FogOfWarSystemScript)
	fog_of_war_system.name = "FogOfWarSystem"
	add_child(fog_of_war_system)

	# 1フレーム待ってからビジョンを登録
	await get_tree().process_frame

	if character and character.vision:
		fog_of_war_system.register_vision(character.vision)
		print("[TestStrafe] Vision registered with FogOfWarSystem")


func _setup_ui() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "CanvasLayer"
	add_child(canvas)

	var panel = PanelContainer.new()
	panel.position = Vector2(10, 10)
	canvas.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "Strafe Test"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var controls = Label.new()
	controls.text = "WASD: Move\nMouse: Look\nShift: Run"
	vbox.add_child(controls)

	vbox.add_child(HSeparator.new())

	_info_label = Label.new()
	_info_label.text = "State: Idle"
	vbox.add_child(_info_label)

	_blend_label = Label.new()
	_blend_label.text = "Blend: (0.0, 0.0)"
	vbox.add_child(_blend_label)


func _physics_process(_delta: float) -> void:
	if not character or not character.movement:
		return

	# WASD移動入力
	var input_dir = Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.z -= 1
	if Input.is_key_pressed(KEY_S):
		input_dir.z += 1
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1

	if input_dir.length_squared() > 0:
		input_dir = input_dir.normalized()

	# Shiftで走る
	var is_running = Input.is_key_pressed(KEY_SHIFT)

	# マウス位置で視線方向を更新
	_update_facing_direction()

	# 走り中はストレイフを一時無効
	if is_running and character.movement.strafe_mode:
		character.movement.strafe_mode = false
	elif not is_running and _strafe_enabled and not character.movement.strafe_mode:
		# このプロジェクトでは+Zが前方
		var facing = character.global_transform.basis.z
		character.movement.enable_strafe_mode(facing)

	# 移動
	character.movement.set_input_direction(input_dir, is_running)

	# UI更新
	_update_ui(input_dir, is_running)


## 上半身回転の限界角度（度）
const UPPER_BODY_MAX_ANGLE: float = 90.0


func _update_facing_direction() -> void:
	# キャラクターのスクリーン座標からのマウスオフセットを計算
	var char_screen_pos = camera.unproject_position(character.global_position)
	var mouse_pos = get_viewport().get_mouse_position()
	var screen_offset = mouse_pos - char_screen_pos

	# カメラの右方向と前方向（XZ平面上）を取得
	var cam_right = camera.global_transform.basis.x
	cam_right.y = 0
	cam_right = cam_right.normalized() if cam_right.length_squared() > 0.001 else Vector3.RIGHT

	var cam_forward = -camera.global_transform.basis.z
	cam_forward.y = 0
	cam_forward = cam_forward.normalized() if cam_forward.length_squared() > 0.001 else Vector3.FORWARD

	# スクリーンオフセットをワールド方向に変換
	var world_dir = cam_right * screen_offset.x + cam_forward * (-screen_offset.y)

	if world_dir.length_squared() > 0.001:
		world_dir = world_dir.normalized()

		# キャラクターの現在の前方向（+Z）
		var body_forward = character.global_transform.basis.z
		body_forward.y = 0
		body_forward = body_forward.normalized()

		# マウス方向との角度差を計算（ラジアン）
		var angle_diff = atan2(
			body_forward.cross(world_dir).y,
			body_forward.dot(world_dir)
		)
		var angle_deg = rad_to_deg(angle_diff)

		# ヒステリシス付きの限界処理
		# 限界を超えたらリセット状態に入る
		if abs(angle_deg) > UPPER_BODY_MAX_ANGLE:
			_twist_disabled = true
		# リセット状態では70度以下になるまで追従を再開しない
		elif _twist_disabled and abs(angle_deg) < 70.0:
			_twist_disabled = false

		# 適用
		if _twist_disabled:
			character.animation.apply_spine_rotation(0.0, 0.0)
		else:
			character.animation.apply_spine_rotation(angle_deg, 0.0)

		# ストレイフモードのfacing_directionはマウス方向を維持
		character.movement._facing_direction = world_dir


func _update_ui(input_dir: Vector3, is_running: bool) -> void:
	# 状態表示
	var state = "Idle"
	if input_dir.length_squared() > 0:
		state = "Running" if is_running else "Walking"
		if character.movement.strafe_mode:
			state += " (Strafe)"
	_info_label.text = "State: %s" % state

	# ブレンド座標表示
	var blend = character.movement.get_strafe_blend()
	_blend_label.text = "Blend: (%.2f, %.2f)" % [blend.x, blend.y]
