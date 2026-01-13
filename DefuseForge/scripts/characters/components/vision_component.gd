class_name VisionComponent
extends Node

## 視界管理コンポーネント
## キャラクターの視界計算、レイキャスト処理を担当

signal vision_updated(visible_points: PackedVector3Array)
signal wall_hit_updated(hit_points: PackedVector3Array)

## 視界パラメータ
@export var fov_degrees: float = 90.0           # 視野角（度）
@export var view_distance: float = 15.0         # 視界距離
@export var ray_count: int = 30                 # レイキャスト本数（軽量化）
@export var update_interval: float = 0.1        # 更新間隔（秒）
@export var eye_height: float = 1.5             # 目の高さ

## 壁検出用コリジョンマスク
@export_flags_3d_physics var wall_collision_mask: int = 2  # Layer 2 = 壁

## 壁ライトエフェクト設定
@export_group("Wall Light Effect")
@export var enable_wall_lights: bool = false    # デフォルト無効（パフォーマンス）
@export var wall_light_energy: float = 0.5
@export var wall_light_range: float = 2.0
@export var wall_light_angle: float = 30.0
@export var wall_light_color: Color = Color(1.0, 0.9, 0.7)
@export var max_wall_lights: int = 5            # 軽量化

## 内部変数
var _character: CharacterBody3D
var _update_timer: float = 0.0
var _visible_polygon: PackedVector3Array = []   # 視界ポリゴン頂点
var _wall_hit_points: PackedVector3Array = []   # 壁ヒットポイント（光エフェクト用）

## キャッシュ
var _ray_directions: Array[Vector3] = []        # 事前計算したレイ方向

## 壁ライト
var _wall_lights: Array[SpotLight3D] = []
var _wall_lights_container: Node3D


func _ready() -> void:
	_character = get_parent() as CharacterBody3D
	if _character == null:
		push_error("[VisionComponent] Parent must be CharacterBody3D")
		return
	_precalculate_ray_directions()
	_setup_wall_lights()


## 壁ライトをセットアップ
func _setup_wall_lights() -> void:
	if not enable_wall_lights:
		return

	_wall_lights_container = Node3D.new()
	_wall_lights_container.name = "WallLights"
	add_child(_wall_lights_container)

	for i in range(max_wall_lights):
		var light = SpotLight3D.new()
		light.light_energy = wall_light_energy
		light.spot_range = wall_light_range
		light.spot_angle = wall_light_angle
		light.light_color = wall_light_color
		light.shadow_enabled = false  # パフォーマンスのため無効
		light.visible = false
		_wall_lights_container.add_child(light)
		_wall_lights.append(light)


## 壁ライトを更新
func _update_wall_lights() -> void:
	if not enable_wall_lights or _wall_lights.is_empty():
		return

	var origin = _character.global_position + Vector3(0, eye_height, 0)

	# ヒットポイントをサンプリング（全部ではなく間隔をあけて）
	var sample_interval = max(1, int(_wall_hit_points.size() / float(max_wall_lights)))
	var light_index = 0

	for i in range(0, _wall_hit_points.size(), sample_interval):
		if light_index >= max_wall_lights:
			break

		var hit_point = _wall_hit_points[i]
		var light = _wall_lights[light_index]

		# ライトを壁に向けて配置
		var direction = (hit_point - origin).normalized()
		light.global_position = hit_point - direction * 0.5  # 少し手前に
		light.look_at(hit_point, Vector3.UP)
		light.visible = true
		light_index += 1

	# 残りのライトを非表示
	for i in range(light_index, max_wall_lights):
		_wall_lights[i].visible = false


## レイ方向を事前計算（キャラクターのローカル座標系）
func _precalculate_ray_directions() -> void:
	_ray_directions.clear()
	var half_fov = deg_to_rad(fov_degrees / 2.0)
	var angle_step = deg_to_rad(fov_degrees) / max(ray_count - 1, 1)

	for i in range(ray_count):
		var angle = -half_fov + angle_step * i
		# 前方（-Z）を基準に左右に広がる
		_ray_directions.append(Vector3(sin(angle), 0, -cos(angle)).normalized())


## 更新処理（CharacterBaseから呼ばれる）
func update(delta: float) -> void:
	_update_timer -= delta
	if _update_timer <= 0:
		_update_timer = update_interval
		_calculate_vision()


## 視界を計算
func _calculate_vision() -> void:
	if _character == null:
		return

	var space_state = _character.get_world_3d().direct_space_state
	var origin = _character.global_position + Vector3(0, eye_height, 0)
	var char_rotation = _character.rotation.y

	_visible_polygon.clear()
	_wall_hit_points.clear()

	# 原点を追加（メッシュ生成用）
	_visible_polygon.append(origin)

	for ray_dir in _ray_directions:
		# キャラクターの回転を適用
		var rotated_dir = ray_dir.rotated(Vector3.UP, char_rotation)
		var end_point = origin + rotated_dir * view_distance

		var query = PhysicsRayQueryParameters3D.create(origin, end_point, wall_collision_mask)
		query.exclude = [_character.get_rid()]  # 自分自身を除外
		var result = space_state.intersect_ray(query)

		if result:
			# 壁にヒット
			_visible_polygon.append(result.position)
			_wall_hit_points.append(result.position)
		else:
			# 最大距離まで視認可能
			_visible_polygon.append(end_point)

	vision_updated.emit(_visible_polygon)
	wall_hit_updated.emit(_wall_hit_points)

	# 壁ライトを更新
	_update_wall_lights()


## 視界ポリゴンを取得
func get_visible_polygon() -> PackedVector3Array:
	return _visible_polygon


## 壁ヒットポイントを取得（光エフェクト用）
func get_wall_hit_points() -> PackedVector3Array:
	return _wall_hit_points


## 視野角を変更
func set_fov(degrees: float) -> void:
	fov_degrees = degrees
	_precalculate_ray_directions()


## 視界距離を変更
func set_view_distance(distance: float) -> void:
	view_distance = distance


## 即座に視界を更新
func force_update() -> void:
	_calculate_vision()
