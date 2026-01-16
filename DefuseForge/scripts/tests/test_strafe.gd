extends Node3D

## ストレイフ（8方向移動）テストシーン
## WASD移動、Shiftで走る（走り中はストレイフ無効）
## FoW（視界）システム統合
## パスドロワー + コンテキストメニュー統合

const FogOfWarSystemScript = preload("res://scripts/systems/fog_of_war_system.gd")
const PathDrawerScript = preload("res://scripts/effects/path_drawer.gd")
const SelectionManagerScript = preload("res://scripts/managers/selection_manager.gd")
const ContextMenuScript = preload("res://scripts/ui/context_menu_component.gd")
const InputRotationScript = preload("res://scripts/characters/components/input_rotation_component.gd")
const InteractionManagerScript = preload("res://scripts/managers/character_interaction_manager.gd")
const ContextMenuItemScript = preload("res://scripts/resources/context_menu_item.gd")

## テスト状態
enum TestState { MANUAL, DRAWING_PATH, SETTING_VISION, READY_TO_EXECUTE, EXECUTING }

@onready var camera: Camera3D = $Camera3D
@onready var character: CharacterBase = $CharacterBody

var _strafe_enabled: bool = true
var _current_state: TestState = TestState.MANUAL
var fog_of_war_system: Node3D = null

# パスドロワー・インタラクション
var path_drawer: Node3D = null
var _selection_manager: Node = null
var _context_menu: Control = null
var _input_rotation: Node = null
var _interaction_manager: Node = null
var _canvas_layer: CanvasLayer = null

# 動的メニュー項目
var _add_vision_item: Resource = null
var _clear_move_item: Resource = null

# UI
var _info_label: Label
var _blend_label: Label
var _state_label: Label
var _path_count_label: Label
var _vision_count_label: Label
var _execute_button: Button
var _done_vision_button: Button


func _ready() -> void:
	# UI作成
	_setup_ui()

	# キャラクター初期化を待つ
	await get_tree().process_frame

	# ストレイフモードを有効化（+Zが前方）
	if character:
		var facing = character.global_transform.basis.z
		character.enable_strafe(facing)
		# アウトラインカメラをセットアップ
		character.setup_outline_camera(camera)

	# パスドロワーをセットアップ
	_setup_path_drawer()

	# 選択システムをセットアップ
	_setup_selection_system()

	# 入力回転コンポーネントをセットアップ
	_setup_input_rotation()

	# コンテキストメニューをセットアップ
	_setup_context_menu()

	# インタラクションマネージャーをセットアップ
	_setup_interaction_manager()

	# FoWシステムをセットアップ
	_setup_fog_of_war()

	print("[TestStrafe] Ready")
	print("[TestStrafe] WASD: Move, Shift: Run, C: Crouch, Click: Context Menu")


func _setup_path_drawer() -> void:
	path_drawer = Node3D.new()
	path_drawer.set_script(PathDrawerScript)
	path_drawer.name = "PathDrawer"
	add_child(path_drawer)

	path_drawer.setup(camera)

	# シグナル接続
	path_drawer.drawing_started.connect(_on_drawing_started)
	path_drawer.drawing_updated.connect(_on_drawing_updated)
	path_drawer.drawing_finished.connect(_on_drawing_finished)
	path_drawer.vision_point_added.connect(_on_vision_point_added)
	path_drawer.path_execution_completed.connect(_on_path_execution_completed)


func _setup_selection_system() -> void:
	_selection_manager = SelectionManagerScript.new()
	_selection_manager.selection_changed.connect(_on_selection_changed)
	add_child(_selection_manager)


func _setup_input_rotation() -> void:
	_input_rotation = InputRotationScript.new()
	_input_rotation.require_menu_activation = true
	character.add_child(_input_rotation)
	_input_rotation.setup(camera)


func _setup_context_menu() -> void:
	_context_menu = ContextMenuScript.new()
	_canvas_layer.add_child(_context_menu)
	_context_menu.setup_default_items()


func _setup_interaction_manager() -> void:
	_interaction_manager = InteractionManagerScript.new()
	add_child(_interaction_manager)

	_interaction_manager.setup(
		_selection_manager,
		_context_menu,
		_input_rotation,
		camera
	)

	_interaction_manager.action_started.connect(_on_action_started)


func _setup_fog_of_war() -> void:
	fog_of_war_system = Node3D.new()
	fog_of_war_system.set_script(FogOfWarSystemScript)
	fog_of_war_system.name = "FogOfWarSystem"
	add_child(fog_of_war_system)

	await get_tree().process_frame

	if character and character.vision:
		fog_of_war_system.register_vision(character.vision)
		print("[TestStrafe] Vision registered with FogOfWarSystem")


func _setup_ui() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "CanvasLayer"
	add_child(_canvas_layer)

	var panel = PanelContainer.new()
	panel.position = Vector2(10, 10)
	_canvas_layer.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "Strafe Test"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var controls = Label.new()
	controls.text = "WASD: Move\nShift: Run\nC: Crouch\nClick: Menu"
	vbox.add_child(controls)

	vbox.add_child(HSeparator.new())

	_state_label = Label.new()
	_state_label.text = "Mode: Manual"
	vbox.add_child(_state_label)

	_info_label = Label.new()
	_info_label.text = "State: Idle"
	vbox.add_child(_info_label)

	_blend_label = Label.new()
	_blend_label.text = "Blend: (0.0, 0.0)"
	vbox.add_child(_blend_label)

	_path_count_label = Label.new()
	_path_count_label.text = "Path: 0"
	vbox.add_child(_path_count_label)

	_vision_count_label = Label.new()
	_vision_count_label.text = "Vision: 0"
	vbox.add_child(_vision_count_label)

	vbox.add_child(HSeparator.new())

	_execute_button = Button.new()
	_execute_button.text = "Execute"
	_execute_button.disabled = true
	_execute_button.pressed.connect(_on_execute_pressed)
	vbox.add_child(_execute_button)

	_done_vision_button = Button.new()
	_done_vision_button.text = "Done Vision"
	_done_vision_button.disabled = true
	_done_vision_button.pressed.connect(_on_done_vision_pressed)
	vbox.add_child(_done_vision_button)


func _input(event: InputEvent) -> void:
	# Cキーでしゃがみトグル
	if event is InputEventKey and event.keycode == KEY_C and event.pressed and not event.echo:
		if character:
			character.toggle_crouch()


func _physics_process(_delta: float) -> void:
	if not character or not character.movement:
		return

	# パス実行中はストレイフを無効にして移動を任せる
	if _current_state == TestState.EXECUTING:
		if character.movement.strafe_mode:
			character.movement.strafe_mode = false
		return

	# パス描画中・視線設定中も入力を無視
	if _current_state == TestState.DRAWING_PATH or _current_state == TestState.SETTING_VISION:
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

	# Shiftで走る（しゃがみ中は走れない）
	var is_running = Input.is_key_pressed(KEY_SHIFT) and not character.is_crouching

	# 走り中はストレイフを一時無効
	if is_running and character.movement.strafe_mode:
		character.movement.strafe_mode = false
	elif not is_running and _strafe_enabled and not character.movement.strafe_mode:
		var facing = character.global_transform.basis.z
		character.movement.enable_strafe_mode(facing)

	# 移動
	character.movement.set_input_direction(input_dir, is_running)

	# 詳細ログ: 毎フレーム位置を出力
	var root_bone_pos = Vector3.ZERO
	if character.skeleton:
		for i in range(character.skeleton.get_bone_count()):
			var bone_name = character.skeleton.get_bone_name(i).to_lower()
			if "hip" in bone_name:
				root_bone_pos = character.skeleton.get_bone_pose_position(i)
				break
	print("[LOG] body=%s hips=%s input=%s" % [
		character.global_position,
		root_bone_pos,
		input_dir
	])

	# UI更新
	_update_ui(input_dir, is_running)


func _set_state(new_state: TestState) -> void:
	_current_state = new_state
	var state_names = ["Manual", "Drawing Path", "Setting Vision", "Ready", "Executing"]
	_state_label.text = "Mode: %s" % state_names[new_state]
	_update_ui_for_state()


func _update_ui_for_state() -> void:
	match _current_state:
		TestState.MANUAL:
			_execute_button.disabled = true
			_done_vision_button.disabled = true
			_remove_add_vision_menu()
			_remove_clear_move_menu()
		TestState.DRAWING_PATH:
			_execute_button.disabled = true
			_done_vision_button.disabled = true
			_remove_add_vision_menu()
			_remove_clear_move_menu()
		TestState.SETTING_VISION:
			_execute_button.disabled = true
			_done_vision_button.disabled = false
			_remove_add_vision_menu()
			_add_clear_move_menu()
		TestState.READY_TO_EXECUTE:
			_execute_button.disabled = false
			_done_vision_button.disabled = true
			_add_add_vision_menu()
			_add_clear_move_menu()
		TestState.EXECUTING:
			_execute_button.disabled = true
			_done_vision_button.disabled = true
			_remove_add_vision_menu()
			_remove_clear_move_menu()

	_update_counts()


func _update_counts() -> void:
	if path_drawer:
		_vision_count_label.text = "Vision: %d" % path_drawer.get_vision_point_count()


func _add_add_vision_menu() -> void:
	if _add_vision_item != null:
		return
	_add_vision_item = ContextMenuItemScript.create("add_vision", "Add Vision", 3)
	_context_menu.add_item(_add_vision_item)


func _remove_add_vision_menu() -> void:
	if _add_vision_item == null:
		return
	_context_menu.remove_item("add_vision")
	_add_vision_item = null


func _add_clear_move_menu() -> void:
	if _clear_move_item != null:
		return
	_clear_move_item = ContextMenuItemScript.create("clear_move", "Clear Move", 4)
	_context_menu.add_item(_clear_move_item)


func _remove_clear_move_menu() -> void:
	if _clear_move_item == null:
		return
	_context_menu.remove_item("clear_move")
	_clear_move_item = null


# シグナルハンドラ
func _on_selection_changed(selected: CharacterBody3D) -> void:
	if selected:
		print("[TestStrafe] Character selected")
	else:
		print("[TestStrafe] Selection cleared")


func _on_action_started(action_id: String, _action_character: CharacterBody3D) -> void:
	match action_id:
		"move":
			path_drawer.enable(character)
			_set_state(TestState.DRAWING_PATH)
			print("[TestStrafe] Move selected - draw a movement path")
		"add_vision":
			_on_add_vision_selected()
		"clear_move":
			_on_clear_move_selected()


func _on_drawing_started() -> void:
	_path_count_label.text = "Path: 1"


func _on_drawing_updated(points: PackedVector3Array) -> void:
	_path_count_label.text = "Path: %d" % points.size()


func _on_drawing_finished(points: PackedVector3Array) -> void:
	print("[TestStrafe] Movement path completed with %d points" % points.size())
	path_drawer.disable()

	if path_drawer.has_pending_path():
		_set_state(TestState.READY_TO_EXECUTE)
		print("[TestStrafe] Path ready. Click 'Add Vision' or 'Execute'.")


func _on_vision_point_added(_anchor: Vector3, _direction: Vector3) -> void:
	_update_counts()
	print("[TestStrafe] Vision point added. Total: %d" % path_drawer.get_vision_point_count())


func _on_add_vision_selected() -> void:
	if path_drawer.start_vision_mode():
		_set_state(TestState.SETTING_VISION)
		print("[TestStrafe] Click on path and drag to set look direction")


func _on_done_vision_pressed() -> void:
	path_drawer.disable()
	_set_state(TestState.READY_TO_EXECUTE)
	print("[TestStrafe] Vision setup done. Press Execute to start.")


func _on_clear_move_selected() -> void:
	path_drawer.clear()
	path_drawer.clear_pending()
	_path_count_label.text = "Path: 0"
	_set_state(TestState.MANUAL)
	print("[TestStrafe] Move path cleared")


func _on_execute_pressed() -> void:
	if path_drawer.execute_with_vision(false):
		_set_state(TestState.EXECUTING)
		var vision_count = path_drawer.get_vision_point_count()
		print("[TestStrafe] Movement started with %d vision points" % vision_count)


func _on_path_execution_completed(_completed_character: CharacterBody3D) -> void:
	_set_state(TestState.MANUAL)
	print("[TestStrafe] Movement completed")


func _update_ui(input_dir: Vector3, is_running: bool) -> void:
	var state = "Idle"
	if input_dir.length_squared() > 0:
		state = "Running" if is_running else "Walking"
		if character.movement.strafe_mode:
			state += " (Strafe)"
	if character.is_crouching:
		state += " [Crouch]"
	_info_label.text = "State: %s" % state

	var blend = character.movement.get_strafe_blend()
	_blend_label.text = "Blend: (%.2f, %.2f)" % [blend.x, blend.y]
