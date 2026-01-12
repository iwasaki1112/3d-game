extends Node

## VisionComponent - 視野管理コンポーネント（スタブ）
## TODO: 完全な実装を追加

@export var fov_angle: float = 90.0
@export var view_distance: float = 15.0
@export var ray_count: int = 24
@export var update_interval: float = 0.1

signal target_spotted(target: Node3D)
signal target_lost(target: Node3D)

var _parent: CharacterBody3D = null
var _update_timer: float = 0.0


func _ready() -> void:
	_parent = get_parent() as CharacterBody3D


func _physics_process(delta: float) -> void:
	_update_timer += delta
	if _update_timer >= update_interval:
		_update_timer = 0.0
		# TODO: 視野内のターゲットを検出


## 位置が視野内にあるか確認
func is_position_visible(position: Vector3) -> bool:
	if _parent == null:
		return false

	var to_target := position - _parent.global_position
	var distance := to_target.length()

	if distance > view_distance:
		return false

	var forward := -_parent.global_transform.basis.z
	var angle := rad_to_deg(forward.angle_to(to_target))

	return angle <= fov_angle / 2.0


## レイキャストで遮蔽物を確認
func has_line_of_sight(position: Vector3, collision_mask: int = 1) -> bool:
	if _parent == null:
		return false

	var space_state := _parent.get_world_3d().direct_space_state
	var ray_origin := _parent.global_position + Vector3(0, 1.5, 0)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, position)
	query.collision_mask = collision_mask
	query.exclude = [_parent]

	var result := space_state.intersect_ray(query)
	return result.is_empty()
