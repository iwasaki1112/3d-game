extends Node3D

## パスドロワーのテストシーン
## キャラクター選択 → コンテキストメニュー → パス描画

const SelectionManagerScript = preload("res://scripts/managers/selection_manager.gd")
const ContextMenuScript = preload("res://scripts/ui/context_menu_component.gd")
const InputRotationScript = preload("res://scripts/characters/components/input_rotation_component.gd")
const InteractionManagerScript = preload("res://scripts/managers/character_interaction_manager.gd")
const MovementMarkerScript = preload("res://scripts/effects/movement_marker.gd")

@onready var camera: Camera3D = $OrbitCamera
@onready var path_drawer: Node3D = $PathDrawer
@onready var clear_button: Button = $CanvasLayer/UI/ClearButton
@onready var execute_button: Button = $CanvasLayer/UI/ExecuteButton
@onready var point_count_label: Label = $CanvasLayer/UI/PointCountLabel
@onready var character: CharacterBody3D = $CharacterBody
@onready var canvas_layer: CanvasLayer = $CanvasLayer

var _selection_manager: Node
var _context_menu: Control
var _input_rotation: Node
var _interaction_manager: Node
var _selected_character: CharacterBody3D
var _movement_marker: MeshInstance3D
var _moving_character: CharacterBase  # 移動中のキャラクター
var _pending_path: PackedVector3Array  # 実行待ちのパス
var _pending_character: CharacterBase  # パスを実行するキャラクター


func _ready() -> void:
	# カメラを固定（入力無効化）
	camera.input_disabled = true

	# カメラのターゲットを設定（OrbitCameraが正しく動作するために必要）
	if camera.has_method("set_target"):
		camera.set_target(character)

	# PathDrawerにカメラを設定
	path_drawer.setup(camera)

	# コンポーネント初期化を待つ
	await get_tree().process_frame

	# アウトラインカメラをセットアップ
	if character:
		character.setup_outline_camera(camera)
		# Idleアニメーションを再生（デフォルトはpistol_idle）
		if character.animation:
			character.animation.anim_tree.active = true
			character.animation.set_locomotion(0)  # IDLE

	# 選択システムをセットアップ
	_setup_selection_system()

	# 入力回転コンポーネントをセットアップ
	_setup_input_rotation()

	# コンテキストメニューをセットアップ
	_setup_context_menu()

	# インタラクションマネージャーをセットアップ
	_setup_interaction_manager()

	# 移動マーカーをセットアップ
	_setup_movement_marker()

	# シグナル接続
	path_drawer.drawing_started.connect(_on_drawing_started)
	path_drawer.drawing_updated.connect(_on_drawing_updated)
	path_drawer.drawing_finished.connect(_on_drawing_finished)
	clear_button.pressed.connect(_on_clear_pressed)
	execute_button.pressed.connect(_on_execute_pressed)

	# キャラクターの移動完了シグナルを接続
	if character:
		character.path_completed.connect(_on_path_completed)

	print("[TestPathDrawer] Ready - Click character, select 'Move' from menu")


func _setup_movement_marker() -> void:
	_movement_marker = MovementMarkerScript.new()
	add_child(_movement_marker)


func _setup_selection_system() -> void:
	_selection_manager = SelectionManagerScript.new()
	_selection_manager.selection_changed.connect(_on_selection_changed)
	add_child(_selection_manager)


func _setup_input_rotation() -> void:
	_input_rotation = InputRotationScript.new()
	_input_rotation.require_menu_activation = true  # 長押し回転を無効化
	character.add_child(_input_rotation)
	_input_rotation.setup(camera)


func _setup_context_menu() -> void:
	_context_menu = ContextMenuScript.new()
	canvas_layer.add_child(_context_menu)

	# 標準メニュー項目をセットアップ
	_context_menu.setup_default_items()


func _setup_interaction_manager() -> void:
	_interaction_manager = InteractionManagerScript.new()
	add_child(_interaction_manager)

	# 各コンポーネントを接続
	_interaction_manager.setup(
		_selection_manager,
		_context_menu,
		_input_rotation,
		camera
	)

	# アクションシグナルを接続
	_interaction_manager.action_started.connect(_on_action_started)


func _on_selection_changed(selected: CharacterBody3D) -> void:
	_selected_character = selected
	if selected:
		print("[TestPathDrawer] Character selected")
	else:
		print("[TestPathDrawer] Selection cleared")


func _on_action_started(action_id: String, action_character: CharacterBody3D) -> void:
	match action_id:
		"move":
			# パス描画を有効化
			path_drawer.enable(action_character)
			print("[TestPathDrawer] Move selected - draw a path")


func _on_drawing_started() -> void:
	point_count_label.text = "Points: 1"


func _on_drawing_updated(points: PackedVector3Array) -> void:
	point_count_label.text = "Points: %d" % points.size()


func _on_drawing_finished(points: PackedVector3Array) -> void:
	print("[TestPathDrawer] Path completed with %d points" % points.size())
	# パス描画を無効化
	path_drawer.disable()

	# パスを保存して実行ボタンを有効化
	if points.size() >= 2 and _selected_character:
		_pending_path = points
		_pending_character = _selected_character as CharacterBase
		execute_button.disabled = false
		print("[TestPathDrawer] Path ready - press Execute to start")


func _on_clear_pressed() -> void:
	path_drawer.clear()
	point_count_label.text = "Points: 0"
	_pending_path = PackedVector3Array()
	_pending_character = null
	execute_button.disabled = true
	print("[TestPathDrawer] Path cleared")


func _on_execute_pressed() -> void:
	if _pending_path.size() < 2 or _pending_character == null:
		return

	# パスに沿って移動開始
	var path_array: Array[Vector3] = []
	for point in _pending_path:
		path_array.append(point)
	_pending_character.set_path(path_array, false)  # 歩き移動
	_moving_character = _pending_character

	# マーカーを表示
	_movement_marker.show_marker()

	# 実行ボタンを無効化
	execute_button.disabled = true
	_pending_path = PackedVector3Array()
	_pending_character = null

	print("[TestPathDrawer] Movement started")


func _on_path_completed() -> void:
	# 移動完了時にマーカーを非表示
	_movement_marker.hide_marker()
	_moving_character = null
	# パスをクリア
	path_drawer.clear()
	print("[TestPathDrawer] Movement completed")


func _process(_delta: float) -> void:
	# 移動中のキャラクターがいればマーカー位置を更新
	if _moving_character and _movement_marker:
		_movement_marker.update_position(_moving_character.global_position)
