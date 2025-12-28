extends CharacterBody3D

## タクティカルシューター プレイヤーコントローラー
## パス追従移動 + 自動射撃

@export_group("移動設定")
@export var walk_speed: float = 3.0
@export var run_speed: float = 6.0
@export var rotation_speed: float = 10.0

@export_group("カメラ設定")
@export var camera_distance: float = 8.0
@export var camera_height: float = 10.0
@export var camera_smooth_speed: float = 5.0
@export var min_zoom: float = 5.0
@export var max_zoom: float = 15.0

@export_group("地形追従設定")
@export var terrain_follow_enabled: bool = true
@export var terrain_ray_length: float = 20.0
@export var terrain_smooth_speed: float = 10.0
@export var ground_offset: float = 0.0

var gravity: float = -9.81
var vertical_velocity: float = 0.0

# 地形追従用
var target_ground_y: float = 0.0

# カメラ回転用
var camera_yaw: float = 0.0
var camera_pitch: float = 75.0  # トップダウンビュー

# パス追従用
var waypoints: Array[Vector3] = []
var current_waypoint_index: int = 0
var is_moving: bool = false
var is_running: bool = false

# アニメーション
var anim_player: AnimationPlayer = null
var current_move_state: int = 0  # 0: idle, 1: walk, 2: run
const ANIM_BLEND_TIME: float = 0.3

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	if camera == null:
		camera = get_viewport().get_camera_3d()

	if terrain_follow_enabled:
		floor_snap_length = 1.0

	# アニメーションプレイヤーを取得
	var model = get_node_or_null("CharacterModel")
	if model:
		anim_player = model.get_node_or_null("AnimationPlayer")
		if anim_player:
			_load_animations()
			if anim_player.has_animation("idle"):
				anim_player.play("idle")


func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	_handle_path_movement(delta)
	_handle_camera_follow(delta)
	_update_animation()


## パス追従移動
func _handle_path_movement(delta: float) -> void:
	if is_moving and waypoints.size() > 0:
		var target := waypoints[current_waypoint_index]
		var direction := (target - global_position)
		direction.y = 0  # 水平方向のみ
		var distance := direction.length()

		if distance < 0.3:  # ウェイポイント到達
			current_waypoint_index += 1
			if current_waypoint_index >= waypoints.size():
				# パス完了
				_stop_moving()
			return

		# 移動方向に回転
		if direction.length() > 0.1:
			var target_rotation := atan2(direction.x, direction.z)
			rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)

		# 移動
		var speed := run_speed if is_running else walk_speed
		var move_dir := direction.normalized()
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed
	else:
		velocity.x = 0
		velocity.z = 0

	# 地形追従
	_handle_terrain_follow(delta)

	move_and_slide()


## 地形追従処理
func _handle_terrain_follow(delta: float) -> void:
	if not terrain_follow_enabled:
		_apply_gravity(delta)
		return

	var space_state = get_world_3d().direct_space_state
	var ray_origin = global_position + Vector3(0, 1, 0)
	var ray_end = global_position + Vector3(0, -terrain_ray_length, 0)

	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = 2
	query.collide_with_bodies = true
	query.hit_back_faces = true

	var result = space_state.intersect_ray(query)

	if result:
		target_ground_y = result.position.y + ground_offset
		var y_diff = abs(global_position.y - target_ground_y)

		if y_diff < 0.01:
			global_position.y = target_ground_y
		else:
			global_position.y = lerp(global_position.y, target_ground_y, terrain_smooth_speed * delta)

		vertical_velocity = 0.0
		velocity.y = 0.0
	else:
		_apply_gravity(delta)


## 重力を適用
func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		vertical_velocity = -2.0
	else:
		vertical_velocity += gravity * delta
	velocity.y = vertical_velocity


## カメラ追従
func _handle_camera_follow(_delta: float) -> void:
	if camera == null:
		return

	# トップダウンビュー
	var yaw_rad := deg_to_rad(camera_yaw)
	var pitch_rad := deg_to_rad(camera_pitch)

	var offset := Vector3(
		sin(yaw_rad) * cos(pitch_rad) * camera_distance,
		sin(pitch_rad) * camera_distance + camera_height,
		cos(yaw_rad) * cos(pitch_rad) * camera_distance
	)

	camera.global_position = global_position + offset
	camera.look_at(global_position + Vector3.UP * 0.5)


## パスを設定して移動開始
func set_path(new_waypoints: Array[Vector3], run: bool = false) -> void:
	waypoints = new_waypoints
	current_waypoint_index = 0
	is_running = run
	is_moving = waypoints.size() > 0


## 移動停止
func _stop_moving() -> void:
	is_moving = false
	waypoints.clear()
	current_waypoint_index = 0


## 現在位置へのパス追加（クリック移動用）
func move_to(target: Vector3, run: bool = false) -> void:
	waypoints = [target]
	current_waypoint_index = 0
	is_running = run
	is_moving = true


## アニメーション読み込み
func _load_animations() -> void:
	var lib = anim_player.get_animation_library("")
	if lib == null:
		return

	_load_animation_from_fbx(lib, "res://assets/characters/animations/idle.fbx", "idle")
	_load_animation_from_fbx(lib, "res://assets/characters/animations/walking.fbx", "walking")
	_load_animation_from_fbx(lib, "res://assets/characters/animations/running.fbx", "running")


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
				anim_copy.loop_mode = Animation.LOOP_LINEAR
				lib.add_animation(anim_name, anim_copy)
				break
	instance.queue_free()


## アニメーション更新
func _update_animation() -> void:
	if anim_player == null:
		return

	var new_state: int = 0
	if is_moving:
		new_state = 2 if is_running else 1
	else:
		new_state = 0

	if new_state != current_move_state:
		current_move_state = new_state
		anim_player.speed_scale = 1.0
		match current_move_state:
			0:
				if anim_player.has_animation("idle"):
					anim_player.play("idle", ANIM_BLEND_TIME)
			1:
				if anim_player.has_animation("walking"):
					anim_player.play("walking", ANIM_BLEND_TIME)
			2:
				if anim_player.has_animation("running"):
					anim_player.play("running", ANIM_BLEND_TIME)
				elif anim_player.has_animation("walking"):
					anim_player.play("walking", ANIM_BLEND_TIME)
					anim_player.speed_scale = 1.5


## 入力処理（デバッグ用 - クリック移動）
func _input(event: InputEvent) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# マウスクリックで移動（仮実装）
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var target := _get_world_position_from_mouse(event.position)
			if target != Vector3.INF:
				move_to(target, false)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var target := _get_world_position_from_mouse(event.position)
			if target != Vector3.INF:
				move_to(target, true)  # 右クリックで走り

	# マウスホイールでズーム
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = max(min_zoom, camera_distance - 1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = min(max_zoom, camera_distance + 1.0)


## マウス位置からワールド座標を取得
func _get_world_position_from_mouse(mouse_pos: Vector2) -> Vector3:
	if camera == null:
		return Vector3.INF

	var from := camera.project_ray_origin(mouse_pos)
	var to := from + camera.project_ray_normal(mouse_pos) * 100.0

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2  # 地形レイヤー

	var result := space_state.intersect_ray(query)
	if result:
		return result.position

	return Vector3.INF
