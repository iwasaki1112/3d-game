extends Node3D

## アニメーションテストシーン
## 武器タイプ切り替えと移動アニメーションのテスト用

@onready var player: CharacterBase = $Player
@onready var status_label: Label = $UI/VBoxContainer/StatusLabel
@onready var camera: Camera3D = $Camera3D

# キャラクターシーンのプリロード
const PLAYER_SCENE = preload("res://scenes/player.tscn")
const ENEMY_SCENE = preload("res://scenes/enemy.tscn")

# 現在のキャラクタータイプ
enum CharacterType { GSG9, LEET }
var current_character_type: CharacterType = CharacterType.GSG9

# カメラ設定
var camera_distance := 10.0  # カメラ距離
var camera_angle := 60.0  # カメラ角度（度）
var camera_move_speed := 10.0
var camera_zoom_speed := 2.0
var camera_min_distance := 3.0
var camera_max_distance := 30.0
var camera_target_position := Vector3.ZERO
var follow_player := true  # プレイヤーを追従するか


func _ready() -> void:
	# GameManagerの状態をPLAYINGに設定
	GameManager.current_state = GameManager.GameState.PLAYING
	camera_target_position = Vector3.ZERO
	_update_status()


func _process(delta: float) -> void:
	_update_status()
	_handle_camera_input(delta)
	_update_camera(delta)


func _handle_camera_input(delta: float) -> void:
	var input_dir := Vector3.ZERO

	# WASDキーでカメラ移動
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input_dir.z -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input_dir.z += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_dir.x += 1

	# カメラ移動中はプレイヤー追従を解除
	if input_dir.length() > 0:
		follow_player = false
		camera_target_position += input_dir.normalized() * camera_move_speed * delta

	# Fキーでプレイヤー追従に戻す
	if Input.is_key_pressed(KEY_F):
		follow_player = true


func _unhandled_input(event: InputEvent) -> void:
	# マウスホイールでズーム
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = max(camera_min_distance, camera_distance - camera_zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = min(camera_max_distance, camera_distance + camera_zoom_speed)


func _update_camera(_delta: float) -> void:
	if camera:
		var look_at_pos: Vector3
		var camera_pos: Vector3

		# カメラオフセットを距離と角度から計算
		var angle_rad := deg_to_rad(camera_angle)
		var offset := Vector3(0, sin(angle_rad) * camera_distance, cos(angle_rad) * camera_distance)

		if follow_player and player:
			look_at_pos = player.global_position
			camera_pos = player.global_position + offset
		else:
			look_at_pos = camera_target_position
			camera_pos = camera_target_position + offset

		# イージングなしで即座に移動
		camera.global_position = camera_pos
		camera.look_at(look_at_pos, Vector3.UP)


func _update_status() -> void:
	if player and status_label:
		var character_name = "GSG9" if current_character_type == CharacterType.GSG9 else "LEET"
		var weapon = player.get_weapon_type_name()
		var state = "idle"
		if player.is_moving:
			state = "running" if player.is_running else "walking"

		var anim = "---"
		if player.anim_player:
			anim = player.anim_player.current_animation

		var camera_mode = "追従" if follow_player else "自由"
		status_label.text = "キャラ: %s\n武器: %s\n状態: %s\nアニメ: %s\nカメラ: %s (%.1f)\n---\nWASD: 移動\nホイール: ズーム\nF: 追従に戻す" % [character_name, weapon, state, anim, camera_mode, camera_distance]


func _on_btn_none_pressed() -> void:
	player.set_weapon_type(CharacterSetup.WeaponType.NONE)
	print("[Test] Weapon changed to NONE")


func _on_btn_rifle_pressed() -> void:
	player.set_weapon_type(CharacterSetup.WeaponType.RIFLE)
	print("[Test] Weapon changed to RIFLE")


func _on_btn_pistol_pressed() -> void:
	player.set_weapon_type(CharacterSetup.WeaponType.PISTOL)
	print("[Test] Weapon changed to PISTOL")


func _on_btn_walk_pressed() -> void:
	# 移動せずに歩きアニメーションをその場で再生
	player.is_moving = true
	player.is_running = false
	print("[Test] Walking animation started")


func _on_btn_run_pressed() -> void:
	# 移動せずに走りアニメーションをその場で再生
	player.is_moving = true
	player.is_running = true
	print("[Test] Running animation started")


func _on_btn_stop_pressed() -> void:
	# アニメーションを停止（idle状態に）
	player.is_moving = false
	player.is_running = false
	player.velocity = Vector3.ZERO
	player.waypoints.clear()
	player.current_waypoint_index = 0
	print("[Test] Stopped")


func _on_btn_dying_pressed() -> void:
	# 死亡アニメーションを再生
	player.is_moving = false
	player.is_running = false
	player.play_dying_animation()
	print("[Test] Dying animation started")


func _on_btn_gsg9_pressed() -> void:
	_switch_character(CharacterType.GSG9)


func _on_btn_leet_pressed() -> void:
	_switch_character(CharacterType.LEET)


## キャラクター切り替え
func _switch_character(new_type: CharacterType) -> void:
	if current_character_type == new_type:
		return

	# 現在のキャラクターの状態を保存
	var was_moving := player.is_moving
	var was_running := player.is_running
	var weapon_type := player.current_weapon_type
	var old_pos := player.global_position

	# 古いキャラクターを削除
	player.queue_free()

	# 新しいキャラクターをインスタンス化
	var new_player: CharacterBase
	if new_type == CharacterType.GSG9:
		new_player = PLAYER_SCENE.instantiate()
		new_player.name = "Player"
	else:
		new_player = ENEMY_SCENE.instantiate()
		new_player.name = "Player"  # 参照名は同じにする

	# シーンに追加
	add_child(new_player)
	new_player.global_position = old_pos

	# 参照を更新
	player = new_player
	current_character_type = new_type

	# 状態を復元（1フレーム待ってから）
	await get_tree().process_frame
	player.set_weapon_type(weapon_type)
	player.is_moving = was_moving
	player.is_running = was_running

	var type_name = "GSG9" if new_type == CharacterType.GSG9 else "LEET"
	print("[Test] Character changed to: %s" % type_name)
