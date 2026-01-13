class_name FogOfWarSystem
extends Node3D

## Fog of War システム
## 複数キャラクターの視界を統合し、フォグを管理

signal fog_updated

## 設定
@export_group("Map Settings")
@export var map_size: Vector2 = Vector2(40, 40)  # マップサイズ（メートル）
@export var fog_height: float = 0.1              # フォグ表示高さ

@export_group("Visibility Grid")
@export var grid_resolution: int = 64            # 可視性グリッド解像度（軽量化）
@export var update_interval: float = 0.1         # 更新間隔

@export_group("Visual Settings")
@export var fog_color: Color = Color(0.1, 0.15, 0.25, 0.9)
@export var temporal_blend: float = 0.8          # スムーズ遷移係数

## 内部
var _visibility_texture: ImageTexture
var _prev_visibility_texture: ImageTexture
var _visibility_image: Image
var _fog_mesh: MeshInstance3D
var _fog_material: ShaderMaterial
var _update_timer: float = 0.0

## 視界コンポーネントリスト
var _vision_components: Array[VisionComponent] = []


func _ready() -> void:
	_setup_visibility_texture()
	_setup_fog_mesh()


## 可視性テクスチャをセットアップ
func _setup_visibility_texture() -> void:
	_visibility_image = Image.create(grid_resolution, grid_resolution, false, Image.FORMAT_R8)
	_visibility_image.fill(Color(0, 0, 0))  # 全て不可視で初期化

	_visibility_texture = ImageTexture.create_from_image(_visibility_image)
	_prev_visibility_texture = ImageTexture.create_from_image(_visibility_image)


## フォグメッシュをセットアップ
func _setup_fog_mesh() -> void:
	_fog_mesh = MeshInstance3D.new()
	_fog_mesh.name = "FogMesh"

	# マップサイズの平面メッシュ
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = map_size
	_fog_mesh.mesh = plane_mesh
	_fog_mesh.position.y = fog_height

	# シェーダーマテリアル
	var shader = load("res://shaders/fog_of_war.gdshader")
	if shader:
		_fog_material = ShaderMaterial.new()
		_fog_material.shader = shader
		_fog_material.set_shader_parameter("visibility_texture", _visibility_texture)
		_fog_material.set_shader_parameter("prev_visibility_texture", _prev_visibility_texture)
		_fog_material.set_shader_parameter("map_min", Vector2(-map_size.x / 2, -map_size.y / 2))
		_fog_material.set_shader_parameter("map_max", Vector2(map_size.x / 2, map_size.y / 2))
		_fog_material.set_shader_parameter("temporal_blend", temporal_blend)
		_fog_material.set_shader_parameter("fog_color", fog_color)
		_fog_mesh.material_override = _fog_material
	else:
		push_warning("[FogOfWarSystem] fog_of_war.gdshader not found")

	add_child(_fog_mesh)


## VisionComponentを登録
func register_vision(vision: VisionComponent) -> void:
	if vision and vision not in _vision_components:
		_vision_components.append(vision)


## VisionComponentを解除
func unregister_vision(vision: VisionComponent) -> void:
	_vision_components.erase(vision)


## CharacterBaseから視界コンポーネントを自動登録
func register_character(character: CharacterBase) -> void:
	if character and character.vision:
		register_vision(character.vision)


## CharacterBaseから視界コンポーネントを解除
func unregister_character(character: CharacterBase) -> void:
	if character and character.vision:
		unregister_vision(character.vision)


func _physics_process(delta: float) -> void:
	_update_timer -= delta
	if _update_timer <= 0:
		_update_timer = update_interval
		_update_visibility()


## 可視性を更新
func _update_visibility() -> void:
	# 前フレームの状態を保存
	_prev_visibility_texture.update(_visibility_image)

	# 新しいイメージをクリア
	_visibility_image.fill(Color(0, 0, 0))

	# 全視界コンポーネントの可視領域を統合
	for vision in _vision_components:
		if not is_instance_valid(vision):
			continue

		var polygon = vision.get_visible_polygon()
		if polygon.size() < 3:
			continue

		_rasterize_polygon(polygon)

	# テクスチャを更新
	_visibility_texture.update(_visibility_image)
	fog_updated.emit()


## ポリゴンをグリッドにラスタライズ
func _rasterize_polygon(polygon: PackedVector3Array) -> void:
	var half_map = map_size / 2
	var cell_size = map_size / Vector2(grid_resolution, grid_resolution)

	# バウンディングボックスを計算
	var min_x = INF
	var max_x = -INF
	var min_z = INF
	var max_z = -INF

	for point in polygon:
		min_x = min(min_x, point.x)
		max_x = max(max_x, point.x)
		min_z = min(min_z, point.z)
		max_z = max(max_z, point.z)

	# グリッド座標に変換
	var grid_min_x = int(clamp((min_x + half_map.x) / cell_size.x, 0, grid_resolution - 1))
	var grid_max_x = int(clamp((max_x + half_map.x) / cell_size.x, 0, grid_resolution - 1))
	var grid_min_z = int(clamp((min_z + half_map.y) / cell_size.y, 0, grid_resolution - 1))
	var grid_max_z = int(clamp((max_z + half_map.y) / cell_size.y, 0, grid_resolution - 1))

	# ポリゴン内のセルを塗りつぶし
	for gx in range(grid_min_x, grid_max_x + 1):
		for gz in range(grid_min_z, grid_max_z + 1):
			var world_x = gx * cell_size.x - half_map.x + cell_size.x / 2
			var world_z = gz * cell_size.y - half_map.y + cell_size.y / 2
			var test_point = Vector3(world_x, 0, world_z)

			if _point_in_polygon(test_point, polygon):
				_visibility_image.set_pixel(gx, gz, Color(1, 1, 1))


## 点がポリゴン内にあるかチェック（XZ平面）
func _point_in_polygon(point: Vector3, polygon: PackedVector3Array) -> bool:
	if polygon.size() < 3:
		return false

	var origin = polygon[0]

	# 三角形ファンで内外判定
	for i in range(1, polygon.size() - 1):
		var p1 = polygon[i]
		var p2 = polygon[i + 1]

		if _point_in_triangle_xz(point, origin, p1, p2):
			return true

	# 最後の三角形
	if polygon.size() > 2:
		if _point_in_triangle_xz(point, origin, polygon[polygon.size() - 1], polygon[1]):
			return true

	return false


## XZ平面での三角形内外判定
func _point_in_triangle_xz(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> bool:
	var v0 = Vector2(c.x - a.x, c.z - a.z)
	var v1 = Vector2(b.x - a.x, b.z - a.z)
	var v2 = Vector2(p.x - a.x, p.z - a.z)

	var dot00 = v0.dot(v0)
	var dot01 = v0.dot(v1)
	var dot02 = v0.dot(v2)
	var dot11 = v1.dot(v1)
	var dot12 = v1.dot(v2)

	var denom = dot00 * dot11 - dot01 * dot01
	if abs(denom) < 0.0001:
		return false

	var inv_denom = 1.0 / denom
	var u = (dot11 * dot02 - dot01 * dot12) * inv_denom
	var v = (dot00 * dot12 - dot01 * dot02) * inv_denom

	return (u >= 0) and (v >= 0) and (u + v <= 1)


## フォグの表示/非表示
func set_fog_visible(fog_visible: bool) -> void:
	if _fog_mesh:
		_fog_mesh.visible = fog_visible


## フォグの色を設定
func set_fog_color(color: Color) -> void:
	fog_color = color
	if _fog_material:
		_fog_material.set_shader_parameter("fog_color", fog_color)
