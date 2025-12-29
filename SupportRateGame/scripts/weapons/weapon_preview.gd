extends Node3D

## 武器プレビュー用シーンのスクリプト
## エディタ上で武器の位置・角度を確認・調整するためのシーン
##
## 操作方法:
## - 左クリック + ドラッグ: カメラ回転
## - マウスホイール: ズームイン/アウト

@export var weapon_scene: PackedScene
@export var character_model: PackedScene

## カメラ設定
@export var camera_distance: float = 3.0
@export var camera_height: float = 1.5
@export var rotation_speed: float = 0.005
@export var zoom_speed: float = 0.2
@export var min_distance: float = 1.0
@export var max_distance: float = 5.0

var character_instance: Node3D
var weapon_attachment: BoneAttachment3D
var weapon_instance: Node3D
var animation_player: AnimationPlayer

var camera: Camera3D
var camera_pivot: Node3D
var camera_angle: float = 0.0
var camera_pitch: float = 0.3  # 初期の上下角度
var is_dragging: bool = false

var is_animation_paused: bool = false
var current_character: String = "leet"  # "leet" or "gsg9"

# キャラクターモデルのパス
const CHARACTER_MODELS = {
	"leet": "res://assets/characters/leet/leet.fbx",
	"gsg9": "res://assets/characters/gsg9/gsg9.fbx"
}

func _ready() -> void:
	_setup_camera()
	_setup_preview()
	_setup_ui()
	_show_instructions()


func _setup_camera() -> void:
	# カメラピボット（回転の中心）を作成
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position = Vector3(0, camera_height, 0)
	add_child(camera_pivot)

	# カメラを作成
	camera = Camera3D.new()
	camera.name = "OrbitCamera"
	camera_pivot.add_child(camera)

	_update_camera_position()


func _update_camera_position() -> void:
	# 球面座標でカメラ位置を計算
	var x = camera_distance * cos(camera_pitch) * sin(camera_angle)
	var y = camera_distance * sin(camera_pitch)
	var z = camera_distance * cos(camera_pitch) * cos(camera_angle)

	camera.position = Vector3(x, y, z)
	# キャラクターの中心（胸あたり）を見る
	camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)


func _show_instructions() -> void:
	print("")
	print("=== 武器プレビュー ===")
	print("操作方法:")
	print("  左クリック + ドラッグ: カメラ回転")
	print("  マウスホイール: ズームイン/アウト")
	print("======================")
	print("")


func _input(event: InputEvent) -> void:
	# マウスボタン
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton

		# 左クリック
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging = mouse_event.pressed

		# マウスホイール（ズーム）
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = max(min_distance, camera_distance - zoom_speed)
			_update_camera_position()
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = min(max_distance, camera_distance + zoom_speed)
			_update_camera_position()

	# マウス移動（ドラッグ中）
	if event is InputEventMouseMotion and is_dragging:
		var motion = event as InputEventMouseMotion
		camera_angle -= motion.relative.x * rotation_speed
		camera_pitch += motion.relative.y * rotation_speed
		# ピッチ角度を制限（-80度〜80度）
		camera_pitch = clamp(camera_pitch, -1.4, 1.4)
		_update_camera_position()


func _setup_preview() -> void:
	# キャラクターモデルをインスタンス化
	if character_model:
		character_instance = character_model.instantiate()
		character_instance.transform = Transform3D(
			Basis.IDENTITY.scaled(Vector3(2, 2, 2)),
			Vector3.ZERO
		)
		add_child(character_instance)

		# マテリアルをセットアップ
		CharacterSetup.setup_materials(character_instance, "WeaponPreview")

		# スケルトンを探す
		var skeleton = CharacterSetup.find_skeleton(character_instance)
		if skeleton:
			print("[WeaponPreview] Found skeleton: %s" % skeleton.name)
			_attach_weapon(skeleton)

			# アニメーションを再生
			animation_player = CharacterSetup.find_animation_player(character_instance)
			if animation_player:
				CharacterSetup.load_animations(animation_player, character_instance, "WeaponPreview")
				animation_player.play("walking_rifle")
				print("[WeaponPreview] Playing walking_rifle animation")
		else:
			push_error("[WeaponPreview] Could not find skeleton in character model")


func _attach_weapon(skeleton: Skeleton3D) -> void:
	if weapon_scene == null:
		push_error("[WeaponPreview] No weapon scene assigned")
		return

	# 右手のボーンを探す
	var bone_name = "mixamorig_RightHand"
	var bone_idx = skeleton.find_bone(bone_name)
	if bone_idx == -1:
		bone_name = "mixamorig1_RightHand"
		bone_idx = skeleton.find_bone(bone_name)

	if bone_idx == -1:
		push_error("[WeaponPreview] Could not find hand bone")
		return

	print("[WeaponPreview] Found bone: %s (index: %d)" % [bone_name, bone_idx])

	# BoneAttachment3Dを作成
	weapon_attachment = BoneAttachment3D.new()
	weapon_attachment.name = "WeaponAttachment"
	weapon_attachment.bone_name = bone_name
	skeleton.add_child(weapon_attachment)

	# 武器シーンをインスタンス化
	weapon_instance = weapon_scene.instantiate()
	weapon_attachment.add_child(weapon_instance)

	print("[WeaponPreview] Weapon attached successfully!")
	print("[WeaponPreview] Adjust the weapon position in: %s" % weapon_scene.resource_path)


func _setup_ui() -> void:
	# CanvasLayerを作成
	var canvas = CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)

	# VBoxContainerを作成
	var vbox = VBoxContainer.new()
	vbox.name = "ButtonContainer"
	vbox.position = Vector2(20, 20)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS  # スクロールを通過させる
	canvas.add_child(vbox)

	# アニメーション停止/再生ボタン
	var pause_button = Button.new()
	pause_button.name = "PauseButton"
	pause_button.text = "Pause Animation"
	pause_button.custom_minimum_size = Vector2(150, 40)
	pause_button.pressed.connect(_on_pause_button_pressed)
	vbox.add_child(pause_button)

	# キャラクター切り替えボタン
	var character_button = Button.new()
	character_button.name = "CharacterButton"
	character_button.text = "Switch to GSG9"
	character_button.custom_minimum_size = Vector2(150, 40)
	character_button.pressed.connect(_on_character_button_pressed)
	vbox.add_child(character_button)


func _on_pause_button_pressed() -> void:
	if animation_player == null:
		return

	is_animation_paused = !is_animation_paused

	if is_animation_paused:
		animation_player.pause()
		print("[WeaponPreview] Animation paused")
	else:
		animation_player.play()
		print("[WeaponPreview] Animation resumed")

	# ボタンテキストを更新
	var button = get_node("UI/ButtonContainer/PauseButton") as Button
	if button:
		button.text = "Resume Animation" if is_animation_paused else "Pause Animation"


func _on_character_button_pressed() -> void:
	# キャラクターを切り替え
	var new_character = "gsg9" if current_character == "leet" else "leet"
	_switch_character(new_character)

	# ボタンテキストを更新
	var button = get_node("UI/ButtonContainer/CharacterButton") as Button
	if button:
		var next_character = "GSG9" if current_character == "leet" else "LEET"
		button.text = "Switch to " + next_character


func _switch_character(new_character: String) -> void:
	if new_character == current_character:
		return

	# 現在のキャラクターを削除
	if character_instance:
		character_instance.queue_free()
		character_instance = null
		weapon_attachment = null
		weapon_instance = null
		animation_player = null

	# 新しいキャラクターをロード
	current_character = new_character
	var model_path = CHARACTER_MODELS[new_character]
	var model_scene = load(model_path) as PackedScene

	if model_scene:
		character_instance = model_scene.instantiate()
		character_instance.transform = Transform3D(
			Basis.IDENTITY.scaled(Vector3(2, 2, 2)),
			Vector3.ZERO
		)
		add_child(character_instance)

		# マテリアルをセットアップ
		CharacterSetup.setup_materials(character_instance, "WeaponPreview")

		# スケルトンを探す
		var skeleton = CharacterSetup.find_skeleton(character_instance)
		if skeleton:
			_attach_weapon(skeleton)

			# アニメーションを再生
			animation_player = CharacterSetup.find_animation_player(character_instance)
			if animation_player:
				CharacterSetup.load_animations(animation_player, character_instance, "WeaponPreview")
				animation_player.play("walking_rifle")

				# 一時停止状態を維持
				if is_animation_paused:
					animation_player.pause()

		print("[WeaponPreview] Switched to %s" % new_character.to_upper())
