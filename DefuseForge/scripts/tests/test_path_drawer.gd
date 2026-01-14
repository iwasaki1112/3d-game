extends Node3D

## パスドロワーのテストシーン
## キャラクター選択 → コンテキストメニュー → パス描画

const SelectionManagerScript = preload("res://scripts/managers/selection_manager.gd")
const ContextMenuScript = preload("res://scripts/ui/context_menu_component.gd")
const InputRotationScript = preload("res://scripts/characters/components/input_rotation_component.gd")
const InteractionManagerScript = preload("res://scripts/managers/character_interaction_manager.gd")

@onready var camera: Camera3D = $OrbitCamera
@onready var path_drawer: Node3D = $PathDrawer
@onready var clear_button: Button = $CanvasLayer/UI/ClearButton
@onready var point_count_label: Label = $CanvasLayer/UI/PointCountLabel
@onready var character: CharacterBody3D = $CharacterBody
@onready var canvas_layer: CanvasLayer = $CanvasLayer

var _selection_manager: Node
var _context_menu: Control
var _input_rotation: Node
var _interaction_manager: Node
var _selected_character: CharacterBody3D


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
		# アニメーション設定
		if character.animation:
			var anim = character.animation
			# 武器タイプをrifleに設定（アニメーション名がrifle_idleなど）
			anim.set_weapon_type(1)  # 1 = RIFLE
			# AnimationTreeを有効化
			anim.anim_tree.active = true
			anim.set_locomotion(0)  # IDLE

	# 選択システムをセットアップ
	_setup_selection_system()

	# 入力回転コンポーネントをセットアップ
	_setup_input_rotation()

	# コンテキストメニューをセットアップ
	_setup_context_menu()

	# インタラクションマネージャーをセットアップ
	_setup_interaction_manager()

	# シグナル接続
	path_drawer.drawing_started.connect(_on_drawing_started)
	path_drawer.drawing_updated.connect(_on_drawing_updated)
	path_drawer.drawing_finished.connect(_on_drawing_finished)
	clear_button.pressed.connect(_on_clear_pressed)

	print("[TestPathDrawer] Ready - Click character, select 'Move' from menu")


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


func _on_clear_pressed() -> void:
	path_drawer.clear()
	point_count_label.text = "Points: 0"
	print("[TestPathDrawer] Path cleared")
