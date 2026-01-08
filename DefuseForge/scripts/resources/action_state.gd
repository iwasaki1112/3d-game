class_name ActionState
extends RefCounted
## アクション状態を管理するクラス
## 移動状態（Locomotion）と一時アクション（Action）を分離管理

# 移動状態（排他的）
enum LocomotionState { IDLE, WALK, SPRINT, CROUCH }

# 一時アクション（排他的、NONEなら何もしていない）
enum ActionType { NONE, RELOAD, OPEN_DOOR, THROW, INTERACT }

# 移動状態の属性定義
const LOCOMOTION_PROPERTIES := {
	LocomotionState.IDLE: { "can_shoot": true, "speed_modifier": 0.0 },
	LocomotionState.WALK: { "can_shoot": true, "speed_modifier": 1.0 },
	LocomotionState.SPRINT: { "can_shoot": false, "speed_modifier": 1.8 },
	LocomotionState.CROUCH: { "can_shoot": true, "speed_modifier": 0.5 }
}

# 一時アクションの属性定義
const ACTION_PROPERTIES := {
	ActionType.NONE: { "can_shoot": true, "can_move": true },
	ActionType.RELOAD: { "can_shoot": false, "can_move": false },
	ActionType.OPEN_DOOR: { "can_shoot": false, "can_move": false },
	ActionType.THROW: { "can_shoot": false, "can_move": false },
	ActionType.INTERACT: { "can_shoot": false, "can_move": true }
}


## 移動状態から射撃可能かを取得
static func can_shoot_in_locomotion(state: int) -> bool:
	var props = LOCOMOTION_PROPERTIES.get(state, {})
	return props.get("can_shoot", true)


## 一時アクションから射撃可能かを取得
static func can_shoot_in_action(action: int) -> bool:
	var props = ACTION_PROPERTIES.get(action, {})
	return props.get("can_shoot", true)


## 一時アクション中に移動可能かを取得
static func can_move_in_action(action: int) -> bool:
	var props = ACTION_PROPERTIES.get(action, {})
	return props.get("can_move", true)


## 移動状態の速度係数を取得
static func get_speed_modifier(state: int) -> float:
	var props = LOCOMOTION_PROPERTIES.get(state, {})
	return props.get("speed_modifier", 1.0)
