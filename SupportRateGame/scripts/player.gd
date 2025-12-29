extends CharacterBody3D

## タクティカルシューター プレイヤーコントローラー
## パス追従移動 + 自動射撃

signal path_completed
signal waypoint_reached(index: int)

@export_group("移動設定")
@export var walk_speed: float = 3.0
@export var run_speed: float = 6.0
@export var rotation_speed: float = 10.0

@export_group("カメラ設定")
@export var camera_distance: float = 5.0
@export var camera_angle: float = -60.0  # 斜めアングル（度）
@export var min_zoom: float = 4.0
@export var max_zoom: float = 25.0
@export var zoom_speed: float = 2.0

var gravity: float = -20.0
var vertical_velocity: float = 0.0

# カメラ
var target_zoom: float = 5.0
var camera_offset: Vector3 = Vector3.ZERO

# タッチ入力管理
var active_touches: Dictionary = {}  # {touch_index: position}
var is_panning: bool = false
var last_touch_distance: float = 0.0
var last_touch_center: Vector2 = Vector2.ZERO

# パス追従用
var waypoints: Array = []  # Array of {position: Vector3, run: bool}
var current_waypoint_index: int = 0
var is_moving: bool = false
var is_running: bool = false  # 現在のウェイポイントへの移動が走りかどうか

# アニメーション
var anim_player: AnimationPlayer = null
var current_move_state: int = 0  # 0: idle, 1: walk, 2: run
const ANIM_BLEND_TIME: float = 0.3

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	if camera == null:
		camera = get_viewport().get_camera_3d()

	target_zoom = camera_distance
	floor_snap_length = 1.0

	# 開始時に地面に配置（物理ワールド初期化を待つ）
	_initial_placement.call_deferred()

	# アニメーションプレイヤーを取得
	var model = get_node_or_null("CharacterModel")
	if model:
		print("[Player] %s: CharacterModel tree:" % name)
		_print_tree(model, 0)

		# マテリアルを光対応に設定
		_setup_lit_materials(model)

		anim_player = model.get_node_or_null("AnimationPlayer")
		if anim_player:
			print("[Player] %s: AnimationPlayer found" % name)
			print("[Player] %s: AnimationPlayer root: %s" % [name, anim_player.root_node])
			# パスが解決できるか確認
			var root = anim_player.get_node_or_null(anim_player.root_node)
			if root:
				var skel = root.get_node_or_null("Armature/Skeleton3D")
				print("[Player] %s: Root node: %s, Skeleton found: %s" % [name, root.name, skel != null])
			# まず元のアニメーションを試す
			var orig_anims = anim_player.get_animation_list()
			print("[Player] %s: Original animations: %s" % [name, orig_anims])
			if orig_anims.size() > 0:
				var first_anim = orig_anims[0]
				var anim = anim_player.get_animation(first_anim)
				if anim and anim.get_track_count() > 0:
					print("[Player] %s: First orig anim '%s' path[0]: %s" % [name, first_anim, anim.track_get_path(0)])

			# 元のFBXアニメーションの内容を詳しく確認
			if orig_anims.size() > 0:
				var test_anim_name = orig_anims[0]
				var test_anim = anim_player.get_animation(test_anim_name)
				if test_anim:
					print("[Player] %s: Animation '%s' details:" % [name, test_anim_name])
					print("[Player] %s:   Length: %f sec" % [name, test_anim.length])
					print("[Player] %s:   Track count: %d" % [name, test_anim.get_track_count()])
					# 最初の5トラックを表示
					for i in range(min(5, test_anim.get_track_count())):
						var path = test_anim.track_get_path(i)
						var track_type = test_anim.track_get_type(i)
						var key_count = test_anim.track_get_key_count(i)
						print("[Player] %s:   Track %d: path=%s, type=%d, keys=%d" % [name, i, path, track_type, key_count])
						# 最初のキーの値を表示
						if key_count > 0:
							var key_time = test_anim.track_get_key_time(i, 0)
							var key_val = test_anim.track_get_key_value(i, 0)
							print("[Player] %s:     Key0: time=%f, val=%s" % [name, key_time, key_val])

			_load_animations()
			if anim_player.has_animation("idle"):
				anim_player.play("idle")
				print("[Player] %s: Playing idle, current=%s, is_playing=%s" % [name, anim_player.current_animation, anim_player.is_playing()])
		else:
			print("[Player] %s: NO AnimationPlayer!" % name)
	else:
		print("[Player] %s: NO CharacterModel!" % name)


func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	_handle_path_movement(delta)
	_handle_camera(delta)
	_update_animation()


## パス追従移動
func _handle_path_movement(delta: float) -> void:
	if is_moving and waypoints.size() > 0 and current_waypoint_index < waypoints.size():
		var waypoint: Dictionary = waypoints[current_waypoint_index]
		var target: Vector3 = waypoint.position
		is_running = waypoint.run  # このウェイポイントへの移動は走りか

		var direction := (target - global_position)
		direction.y = 0  # 水平方向のみ
		var distance := direction.length()

		if distance < 0.3:  # ウェイポイント到達
			waypoint_reached.emit(current_waypoint_index)
			current_waypoint_index += 1
			if current_waypoint_index >= waypoints.size():
				# パス完了
				_stop_moving()
				path_completed.emit()
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


## 地形追従処理（重力ベース）
func _handle_terrain_follow(delta: float) -> void:
	# 重力を適用
	if is_on_floor():
		vertical_velocity = -0.1  # 床に接地するための小さな下向き力
	else:
		vertical_velocity += gravity * delta
		vertical_velocity = max(vertical_velocity, -50.0)  # 最大落下速度を制限

	velocity.y = vertical_velocity


## カメラ処理
func _handle_camera(delta: float) -> void:
	if camera == null:
		return

	# ズームを即座に適用（イージングなし）
	camera_distance = target_zoom

	# 斜めからのトップダウンビュー（キャラクターの回転に影響されない）
	# camera_offsetでパン位置を調整
	# -90度 = 真上、-60度 = 斜め
	var elevation_rad = deg_to_rad(-camera_angle)  # -80 → 80度
	var cam_y = camera_distance * sin(elevation_rad)  # 高さ
	var cam_z = camera_distance * cos(elevation_rad)  # 後方オフセット
	var target_pos = global_position + camera_offset + Vector3(0, cam_y, cam_z)
	camera.global_position = target_pos
	# キャラクターを常に画面中央に
	camera.look_at(global_position + camera_offset + Vector3(0, 1, 0), Vector3.UP)


## パスを設定して移動開始
## new_waypoints: Array of {position: Vector3, run: bool}
func set_path(new_waypoints: Array) -> void:
	waypoints = new_waypoints
	current_waypoint_index = 0
	is_running = false
	is_moving = waypoints.size() > 0


## 移動停止
func _stop_moving() -> void:
	is_moving = false
	waypoints.clear()
	current_waypoint_index = 0


## 移動を中断
func stop() -> void:
	_stop_moving()


## 初期配置（物理ワールド初期化後に実行）
func _initial_placement() -> void:
	print("[Player] %s: _initial_placement started, pos=%s" % [name, global_position])
	# 最初は非表示
	visible = false

	# 物理ワールドが完全に初期化されるまで待つ
	await get_tree().physics_frame
	await get_tree().physics_frame
	_snap_to_ground()
	print("[Player] %s: after snap, pos=%s" % [name, global_position])

	# カメラも即座に配置（斜めアングル）
	if camera:
		var elevation_rad = deg_to_rad(-camera_angle)
		var cam_y = camera_distance * sin(elevation_rad)
		var cam_z = camera_distance * cos(elevation_rad)
		camera.global_position = global_position + camera_offset + Vector3(0, cam_y, cam_z)
		camera.look_at(global_position + camera_offset + Vector3(0, 1, 0), Vector3.UP)

	# スナップ完了後に表示
	visible = true
	print("[Player] %s: visible=true, final pos=%s" % [name, global_position])


## 地面にスナップ
func _snap_to_ground() -> void:
	var space_state := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 10, 0)
	var to := global_position + Vector3(0, -100, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2  # 地形レイヤー
	query.exclude = [self]

	var result := space_state.intersect_ray(query)
	if result:
		global_position = result.position
		vertical_velocity = 0


## 単一地点への移動
func move_to(target: Vector3, run: bool = false) -> void:
	set_path([{"position": target, "run": run}])


## 入力処理（ズーム・パン）
func _input(event: InputEvent) -> void:
	# マウスホイールでズーム
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = max(min_zoom, target_zoom - 1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = min(max_zoom, target_zoom + 1.0)

	# タッチ入力（2本指操作）
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)

	if event is InputEventScreenDrag:
		_handle_screen_drag(event)


## タッチ開始/終了の処理
func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		# タッチ開始
		active_touches[event.index] = event.position
	else:
		# タッチ終了
		active_touches.erase(event.index)
		if active_touches.size() < 2:
			is_panning = false

	# 2本指になったら初期状態を記録
	if active_touches.size() == 2:
		_init_two_finger_gesture()


## 2本指ジェスチャーの初期化
func _init_two_finger_gesture() -> void:
	var positions = active_touches.values()
	last_touch_distance = positions[0].distance_to(positions[1])
	last_touch_center = (positions[0] + positions[1]) / 2.0
	is_panning = true


## タッチドラッグ処理
func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	# タッチ位置を更新
	if active_touches.has(event.index):
		active_touches[event.index] = event.position

	# 2本指でない場合は処理しない
	if active_touches.size() != 2:
		return

	var positions = active_touches.values()
	var current_distance: float = positions[0].distance_to(positions[1])
	var current_center: Vector2 = (positions[0] + positions[1]) / 2.0

	# ピンチズーム（2本指の距離変化）
	if last_touch_distance > 0:
		var zoom_factor = last_touch_distance / current_distance
		target_zoom = clamp(target_zoom * zoom_factor, min_zoom, max_zoom)

	# パン（2本指の中心移動）
	var delta_center = current_center - last_touch_center
	# スクリーン座標からワールド座標への変換（カメラ距離に応じてスケール）
	var pan_scale = camera_distance * 0.002  # 調整可能
	camera_offset.x -= delta_center.x * pan_scale
	camera_offset.z -= delta_center.y * pan_scale

	# 状態を更新
	last_touch_distance = current_distance
	last_touch_center = current_center


## アニメーション読み込み
func _load_animations() -> void:
	var lib = anim_player.get_animation_library("")
	if lib == null:
		print("[Player] %s: No animation library found!" % name)
		return

	print("[Player] %s: Loading animations..." % name)
	# スケルトンのボーン名を確認
	var char_model = get_node_or_null("CharacterModel")
	if char_model:
		var skeleton = char_model.get_node_or_null("Armature/Skeleton3D")
		if skeleton:
			var bone_names = []
			for i in range(min(3, skeleton.get_bone_count())):
				bone_names.append(skeleton.get_bone_name(i))
			print("[Player] %s: Skeleton bones: %s" % [name, bone_names])
	_load_animation_from_fbx(lib, "res://assets/characters/animations/idle.fbx", "idle")
	_load_animation_from_fbx(lib, "res://assets/characters/animations/walking.fbx", "walking")
	_load_animation_from_fbx(lib, "res://assets/characters/animations/running.fbx", "running")
	print("[Player] %s: Available animations: %s" % [name, anim_player.get_animation_list()])


func _load_animation_from_fbx(lib: AnimationLibrary, path: String, anim_name: String) -> void:
	var scene = load(path)
	if scene == null:
		print("[Player] %s: Failed to load %s" % [name, path])
		return

	var instance = scene.instantiate()
	var scene_anim_player = instance.get_node_or_null("AnimationPlayer")
	if scene_anim_player:
		for anim_name_in_lib in scene_anim_player.get_animation_list():
			var anim = scene_anim_player.get_animation(anim_name_in_lib)
			if anim:
				# 最初のアニメーションの詳細を表示（Playerのみ）
				if name == "Player" and anim_name == "idle":
					print("[Player] %s: %s - length: %f, tracks: %d" % [name, anim_name, anim.length, anim.get_track_count()])
					# トラックタイプの統計
					var type_counts = {}
					for i in range(anim.get_track_count()):
						var t = anim.track_get_type(i)
						type_counts[t] = type_counts.get(t, 0) + 1
					print("[Player] %s: Track types: %s" % [name, type_counts])
					# 最初の10トラックを表示
					for i in range(min(10, anim.get_track_count())):
						var p = anim.track_get_path(i)
						var t = anim.track_get_type(i)
						var k = anim.track_get_key_count(i)
						print("[Player] %s:   [%d] %s (type=%d, keys=%d)" % [name, i, p, t, k])

				var anim_copy = anim.duplicate()
				anim_copy.loop_mode = Animation.LOOP_LINEAR
				_adjust_animation_paths(anim_copy)
				lib.add_animation(anim_name, anim_copy)
				break
	else:
		print("[Player] %s: No AnimationPlayer in %s" % [name, path])
	instance.queue_free()


## アニメーションのトラックパスをモデル階層に合わせて調整
func _adjust_animation_paths(anim: Animation) -> void:
	var model = get_node_or_null("CharacterModel")
	if model == null:
		return

	# Armatureノードが存在するかチェック
	var has_armature = model.get_node_or_null("Armature") != null

	# トラックパスを調整
	for i in range(anim.get_track_count()):
		var track_path = anim.track_get_path(i)
		var path_str = str(track_path)

		# ボーン名の違いを修正（アニメーションは"mixamorig1_"、キャラクターは"mixamorig_"）
		path_str = path_str.replace("mixamorig1_", "mixamorig_")

		# Armatureノードがある場合のみプレフィックスを追加
		if has_armature and path_str.begins_with("Skeleton3D:"):
			path_str = "Armature/" + path_str

		anim.track_set_path(i, NodePath(path_str))


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


## キャラクターモデルのマテリアルを光対応に設定＋テクスチャ適用
func _setup_lit_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		# 影をキャストするように設定
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

		# メッシュ名に基づいてテクスチャを適用
		_apply_textures_to_mesh(mesh_instance)

	# 子ノードを再帰的に処理
	for child in node.get_children():
		_setup_lit_materials(child)


## メッシュにテクスチャを適用
func _apply_textures_to_mesh(mesh_instance: MeshInstance3D) -> void:
	var mesh_name = mesh_instance.name.to_lower()
	var albedo_path := ""
	var normal_path := ""

	# メッシュ名に基づいてテクスチャパスを決定
	if "t_leet_glass" in mesh_name:
		albedo_path = "res://assets/characters/leet/t_leet_glass.tga"
	elif "t_leet" in mesh_name:
		albedo_path = "res://assets/characters/leet/t_leet.tga"
		normal_path = "res://assets/characters/leet/t_leet_normal.tga"
	elif "ct_gsg9" in mesh_name:
		albedo_path = "res://assets/characters/gsg9/ct_gsg9.tga"
		normal_path = "res://assets/characters/gsg9/ct_gsg9_normal.tga"

	if albedo_path.is_empty():
		return

	# テクスチャをロード
	var albedo_tex = load(albedo_path) as Texture2D
	if albedo_tex == null:
		print("[Player] %s: Failed to load texture: %s" % [name, albedo_path])
		return

	var normal_tex: Texture2D = null
	if not normal_path.is_empty():
		normal_tex = load(normal_path) as Texture2D

	# 各サーフェスにマテリアルを適用
	if mesh_instance.mesh:
		var surface_count = mesh_instance.mesh.get_surface_count()
		for i in range(surface_count):
			var mat = mesh_instance.get_active_material(i)
			var new_mat: StandardMaterial3D

			if mat and mat is StandardMaterial3D:
				new_mat = mat.duplicate() as StandardMaterial3D
			else:
				new_mat = StandardMaterial3D.new()

			new_mat.albedo_texture = albedo_tex
			new_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

			if normal_tex:
				new_mat.normal_enabled = true
				new_mat.normal_texture = normal_tex

			mesh_instance.set_surface_override_material(i, new_mat)

	print("[Player] %s: Applied texture to mesh '%s'" % [name, mesh_instance.name])


func _print_tree(node: Node, depth: int) -> void:
	var indent = "  ".repeat(depth)
	var extra = ""
	if node is MeshInstance3D:
		var mi = node as MeshInstance3D
		extra = " [mesh=%s, visible=%s, pos=%s, scale=%s]" % [mi.mesh != null, mi.visible, mi.position, mi.global_transform.basis.get_scale()]
	elif node is Node3D:
		var n3d = node as Node3D
		extra = " [pos=%s, scale=%s]" % [n3d.position, n3d.global_transform.basis.get_scale()]
	print("[Player] %s%s (%s)%s" % [indent, node.name, node.get_class(), extra])
	for child in node.get_children():
		_print_tree(child, depth + 1)
