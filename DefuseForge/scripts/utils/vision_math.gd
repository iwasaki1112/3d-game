class_name VisionMath
extends RefCounted

## 視界計算ユーティリティ
## FOV角度計算、角度ラッピング等の共通関数


## 角度を -PI 〜 PI の範囲にラップ
## @param angle: 入力角度（ラジアン）
## @return: -PI 〜 PI の範囲にラップされた角度
static func wrap_angle(angle: float) -> float:
	while angle > PI:
		angle -= TAU
	while angle < -PI:
		angle += TAU
	return angle


## 角度を 0 〜 TAU (2*PI) の範囲にラップ
## @param angle: 入力角度（ラジアン）
## @return: 0 〜 TAU の範囲にラップされた角度
static func wrap_angle_positive(angle: float) -> float:
	while angle >= TAU:
		angle -= TAU
	while angle < 0:
		angle += TAU
	return angle


## 2つのベクトル間の水平角度を計算（XZ平面）
## @param from: 起点
## @param to: 終点
## @return: 角度（ラジアン）- atan2(x, z) 形式
static func get_horizontal_angle_to(from: Vector3, to: Vector3) -> float:
	var diff := to - from
	diff.y = 0
	if diff.length_squared() < 0.0001:
		return 0.0
	return atan2(diff.x, diff.z)


## ターゲットがFOV内にあるかチェック
## @param forward: 前方方向ベクトル（正規化済み）
## @param to_target: ターゲットへの方向ベクトル（正規化不要）
## @param fov_degrees: 視野角（度）
## @return: FOV内ならtrue
static func is_in_fov(forward: Vector3, to_target: Vector3, fov_degrees: float) -> bool:
	# 水平方向のみで判定
	var forward_2d := Vector3(forward.x, 0, forward.z).normalized()
	var target_2d := Vector3(to_target.x, 0, to_target.z)

	if forward_2d.length_squared() < 0.0001 or target_2d.length_squared() < 0.0001:
		return true  # ほぼ同じ位置

	var angle := rad_to_deg(forward_2d.angle_to(target_2d.normalized()))
	return angle <= fov_degrees / 2.0


## 方向ベクトルから回転角度を計算（-Zが前方の規約）
## @param direction: 方向ベクトル（XZ平面）
## @return: 回転角度（ラジアン）
static func direction_to_rotation(direction: Vector3) -> float:
	var dir_2d := Vector3(direction.x, 0, direction.z).normalized()
	return atan2(dir_2d.x, -dir_2d.z)


## 回転角度から方向ベクトルを計算（-Zが前方の規約）
## @param angle: 回転角度（ラジアン）
## @return: 方向ベクトル
static func rotation_to_direction(angle: float) -> Vector3:
	return Vector3(sin(angle), 0, -cos(angle))


## FOVの境界角度を計算
## @param center_angle: 中心角度（ラジアン）
## @param fov_degrees: 視野角（度）
## @return: Dictionary { min: float, max: float }
static func get_fov_bounds(center_angle: float, fov_degrees: float) -> Dictionary:
	var half_fov := deg_to_rad(fov_degrees / 2.0)
	return {
		"min": center_angle - half_fov,
		"max": center_angle + half_fov,
	}


## 角度がFOV範囲内かチェック
## @param angle: チェック対象角度（ラジアン）
## @param center_angle: 中心角度（ラジアン）
## @param fov_degrees: 視野角（度）
## @return: 範囲内ならtrue
static func is_angle_in_fov(angle: float, center_angle: float, fov_degrees: float) -> bool:
	var relative := wrap_angle(angle - center_angle)
	var half_fov := deg_to_rad(fov_degrees / 2.0)
	return abs(relative) <= half_fov
