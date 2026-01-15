class_name PositionHelper
extends RefCounted

## 位置計算ユーティリティ
## キャラクターの目線位置、ターゲット位置等の共通計算


## キャラクターの目線位置を取得
## @param character_pos: キャラクターの位置
## @param eye_height: 目の高さ（デフォルト: 1.5m）
## @return: 目線の位置
static func get_eye_position(character_pos: Vector3, eye_height: float = 1.5) -> Vector3:
	return character_pos + Vector3(0, eye_height, 0)


## ターゲットの胴体位置を取得（視線チェック用）
## @param target_pos: ターゲットの位置
## @param body_height: 胴体の高さ（デフォルト: 1.0m）
## @return: 胴体の位置
static func get_body_position(target_pos: Vector3, body_height: float = 1.0) -> Vector3:
	return target_pos + Vector3(0, body_height, 0)


## ターゲットの頭の位置を取得（ヘッドショット判定用）
## @param target_pos: ターゲットの位置
## @param head_height: 頭の高さ（デフォルト: 1.7m）
## @return: 頭の位置
static func get_head_position(target_pos: Vector3, head_height: float = 1.7) -> Vector3:
	return target_pos + Vector3(0, head_height, 0)


## 地面上の位置を取得（Y座標を指定の高さに設定）
## @param pos: 入力位置
## @param ground_height: 地面の高さ（デフォルト: 0）
## @return: 地面上の位置
static func get_ground_position(pos: Vector3, ground_height: float = 0.0) -> Vector3:
	return Vector3(pos.x, ground_height, pos.z)


## 2点間の水平距離を計算（Y軸を無視）
## @param from: 起点
## @param to: 終点
## @return: 水平距離
static func get_horizontal_distance(from: Vector3, to: Vector3) -> float:
	var diff := to - from
	diff.y = 0
	return diff.length()


## 水平方向の方向ベクトルを取得（正規化済み）
## @param from: 起点
## @param to: 終点
## @return: 正規化された水平方向ベクトル
static func get_horizontal_direction(from: Vector3, to: Vector3) -> Vector3:
	var diff := to - from
	diff.y = 0
	if diff.length_squared() < 0.0001:
		return Vector3.ZERO
	return diff.normalized()
