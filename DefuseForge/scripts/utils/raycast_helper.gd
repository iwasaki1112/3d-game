class_name RaycastHelper
extends RefCounted

## レイキャストヘルパー
## PhysicsRayQueryParameters3D の作成と実行を簡素化


## レイキャストを実行
## @param space_state: PhysicsDirectSpaceState3D
## @param from: 開始位置
## @param to: 終了位置
## @param collision_mask: 衝突マスク（デフォルト：全レイヤー）
## @param exclude: 除外するRIDの配列
## @return: intersect_ray の結果Dictionary
static func cast_ray(
	space_state: PhysicsDirectSpaceState3D,
	from: Vector3,
	to: Vector3,
	collision_mask: int = 0xFFFFFFFF,
	exclude: Array[RID] = []
) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	query.exclude = exclude
	return space_state.intersect_ray(query)


## カメラからのレイキャストを実行
## @param camera: Camera3D
## @param mouse_pos: マウス位置（スクリーン座標）
## @param space_state: PhysicsDirectSpaceState3D
## @param collision_mask: 衝突マスク
## @param max_distance: 最大距離
## @return: intersect_ray の結果Dictionary
static func cast_ray_from_camera(
	camera: Camera3D,
	mouse_pos: Vector2,
	space_state: PhysicsDirectSpaceState3D,
	collision_mask: int = 0xFFFFFFFF,
	max_distance: float = 100.0
) -> Dictionary:
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)
	var ray_end := ray_origin + ray_direction * max_distance
	return cast_ray(space_state, ray_origin, ray_end, collision_mask)


## 視線遮蔽チェック（キャラクター間）
## @param space_state: PhysicsDirectSpaceState3D
## @param from_pos: 視点位置
## @param to_pos: ターゲット位置
## @param wall_mask: 壁の衝突マスク
## @param exclude_rids: 除外するRID（自分とターゲット）
## @return: 壁に遮られていればtrue
static func is_line_of_sight_blocked(
	space_state: PhysicsDirectSpaceState3D,
	from_pos: Vector3,
	to_pos: Vector3,
	wall_mask: int,
	exclude_rids: Array[RID] = []
) -> bool:
	var result := cast_ray(space_state, from_pos, to_pos, wall_mask, exclude_rids)
	return not result.is_empty()


## 地面との交点を取得
## @param camera: Camera3D
## @param mouse_pos: マウス位置
## @param ground_height: 地面の高さ
## @return: 交点座標（nullなら交差なし）
static func get_ground_intersection(
	camera: Camera3D,
	mouse_pos: Vector2,
	ground_height: float = 0.0
) -> Variant:
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)
	var ground_plane := Plane(Vector3.UP, ground_height)
	return ground_plane.intersects_ray(ray_origin, ray_direction)
