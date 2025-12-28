extends CharacterBody3D

## TPSスタイルのプレイヤー操作コントローラー
## モバイル対応（タッチ操作 + スワイプカメラ）

@export_group("移動設定")
@export var walk_speed: float = 3.0
@export var run_speed: float = 7.0
@export var run_threshold: float = 0.7  # ジョイスティックをこれ以上傾けたら走る
@export var rotation_speed: float = 10.0

@export_group("カメラ設定")
@export var camera_distance: float = 5.0
@export var camera_height: float = 3.0
@export var camera_smooth_speed: float = 5.0
@export var camera_sensitivity: float = 0.002
@export var touch_sensitivity: float = 0.15  # タッチ操作用の感度（高め）
@export var min_vertical_angle: float = -20.0
@export var max_vertical_angle: float = 60.0

var gravity: float = -9.81
var vertical_velocity: float = 0.0

# カメラ回転用
var camera_yaw: float = 0.0
var camera_pitch: float = 20.0

# モバイル入力用
var joystick_input: Vector2 = Vector2.ZERO
var is_camera_dragging: bool = false
var last_touch_position: Vector2 = Vector2.ZERO
var camera_touch_id: int = -1

# アニメーション
var anim_player: AnimationPlayer = null
var current_move_state: int = 0  # 0: idle, 1: walk, 2: run
const ANIM_BLEND_TIME: float = 0.3  # アニメーションブレンド時間

# 現在の移動スピード（ジョイスティック距離で変化）
var current_speed: float = 0.0

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	# カメラが無ければメインカメラを取得
	if camera == null:
		camera = get_viewport().get_camera_3d()

	# アニメーションプレイヤーを取得
	var model = get_node_or_null("CharacterModel")
	if model:
		anim_player = model.get_node_or_null("AnimationPlayer")
		if anim_player:
			# アニメーションを読み込んで追加
			_load_animations()
			print("AnimationPlayer found, animations: ", anim_player.get_animation_list())
			# 初期状態でIdleを再生
			if anim_player.has_animation("idle"):
				anim_player.play("idle")


func _physics_process(delta: float) -> void:
	if GameManager.is_game_over:
		return

	_handle_input()
	_handle_camera_input()
	_handle_movement(delta)
	_handle_camera_follow(delta)
	_update_animation()


func _handle_input() -> void:
	# キーボード入力
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_forward", "move_backward")

	var input_strength := input_dir.length()

	# モバイルジョイスティック入力がある場合はそちらを優先
	if joystick_input.length() > 0.1:
		input_dir = joystick_input
		input_strength = joystick_input.length()

	# ジョイスティックの傾き具合でスピードを決定
	if input_strength > run_threshold:
		# 走る
		current_speed = run_speed
	elif input_strength > 0.1:
		# 歩く（傾き具合に応じて速度を補間）
		var walk_factor := input_strength / run_threshold
		current_speed = walk_speed * walk_factor
	else:
		current_speed = 0.0

	# カメラの向きを基準にした移動方向を計算
	var forward := -camera.global_transform.basis.z
	var right := camera.global_transform.basis.x
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()

	var move_direction := (forward * -input_dir.y + right * input_dir.x).normalized()
	velocity.x = move_direction.x * current_speed
	velocity.z = move_direction.z * current_speed


func _handle_camera_input() -> void:
	# この関数は使用しない（_inputで処理）
	pass


func _input(event: InputEvent) -> void:
	# マウスモーション（右クリックまたは左クリックでカメラ回転）
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			camera_yaw -= event.relative.x * camera_sensitivity
			# PC版もY軸は変更しない（モバイルと統一）

	# タッチ入力（モバイル用）- 画面右半分でのスワイプ
	if event is InputEventScreenTouch:
		var screen_width := get_viewport().get_visible_rect().size.x
		if event.position.x > screen_width * 0.5:
			if event.pressed:
				if not is_camera_dragging:
					is_camera_dragging = true
					camera_touch_id = event.index
					last_touch_position = event.position
			else:
				if event.index == camera_touch_id:
					is_camera_dragging = false
					camera_touch_id = -1

	if event is InputEventScreenDrag:
		if is_camera_dragging and event.index == camera_touch_id:
			var touch_delta: Vector2 = event.position - last_touch_position
			camera_yaw -= touch_delta.x * touch_sensitivity
			# Y軸（高さ）は変更しない - 水平回転のみ
			last_touch_position = event.position


func _handle_movement(delta: float) -> void:
	# 重力処理
	if is_on_floor():
		vertical_velocity = -2.0
	else:
		vertical_velocity += gravity * delta

	velocity.y = vertical_velocity
	move_and_slide()

	# キャラクターの向きを移動方向に合わせる
	var horizontal_velocity := Vector3(velocity.x, 0, velocity.z)
	if horizontal_velocity.length() > 0.1:
		var target_rotation := atan2(horizontal_velocity.x, horizontal_velocity.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)


func _handle_camera_follow(_delta: float) -> void:
	if camera == null:
		return

	# カメラの回転角度からオフセットを計算
	var yaw_rad := deg_to_rad(camera_yaw)
	var pitch_rad := deg_to_rad(camera_pitch)

	# 球面座標からカメラ位置を計算（プレイヤーの周りを回る）
	var offset := Vector3(
		sin(yaw_rad) * cos(pitch_rad) * camera_distance,
		sin(pitch_rad) * camera_distance + camera_height,
		cos(yaw_rad) * cos(pitch_rad) * camera_distance
	)

	# カメラ位置を直接設定（揺れない）
	camera.global_position = global_position + offset

	# プレイヤーの少し上を見る
	camera.look_at(global_position + Vector3.UP * 1.0)


## モバイルジョイスティックからの入力を受け取る
func set_joystick_input(input: Vector2) -> void:
	joystick_input = input


## コイン取得時の効果
func on_coin_collected() -> void:
	# エフェクトを追加可能
	pass


## アニメーションを読み込む
func _load_animations() -> void:
	var lib = anim_player.get_animation_library("")
	if lib == null:
		return

	# 各アニメーションをロード
	_load_animation_from_fbx(lib, "res://assets/characters/animations/idle.fbx", "idle")
	_load_animation_from_fbx(lib, "res://assets/characters/animations/walking.fbx", "walking")
	_load_animation_from_fbx(lib, "res://assets/characters/animations/running.fbx", "running")


## FBXからアニメーションを読み込んでライブラリに追加
func _load_animation_from_fbx(lib: AnimationLibrary, path: String, anim_name: String) -> void:
	var scene = load(path)
	if scene == null:
		return

	var instance = scene.instantiate()
	var scene_anim_player = instance.get_node_or_null("AnimationPlayer")
	if scene_anim_player:
		for name in scene_anim_player.get_animation_list():
			var anim = scene_anim_player.get_animation(name)
			if anim:
				var anim_copy = anim.duplicate()
				anim_copy.loop_mode = Animation.LOOP_LINEAR  # ループ設定
				lib.add_animation(anim_name, anim_copy)
				print(anim_name + " animation added!")
				break
	instance.queue_free()


## アニメーションを更新
func _update_animation() -> void:
	if anim_player == null:
		return

	# 現在の速度から状態を判定
	var new_state: int = 0  # idle
	if current_speed >= run_speed * 0.9:
		new_state = 2  # run
	elif current_speed > 0.1:
		new_state = 1  # walk

	# 状態が変わったらアニメーションを切り替え
	if new_state != current_move_state:
		current_move_state = new_state
		anim_player.speed_scale = 1.0  # 速度をリセット
		match current_move_state:
			0:  # idle
				if anim_player.has_animation("idle"):
					anim_player.play("idle", ANIM_BLEND_TIME)
			1:  # walk
				if anim_player.has_animation("walking"):
					anim_player.play("walking", ANIM_BLEND_TIME)
			2:  # run
				if anim_player.has_animation("running"):
					anim_player.play("running", ANIM_BLEND_TIME)
				elif anim_player.has_animation("walking"):
					# runningが無ければwalkingを高速再生
					anim_player.play("walking", ANIM_BLEND_TIME)
					anim_player.speed_scale = 1.5
