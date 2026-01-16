class_name VisionComponent
extends Node3D

## Vision Component for Fog of War System (Shadow Cast Method)
## Uses wall corner points for stable visibility calculation

signal vision_updated(visible_points: PackedVector3Array)
signal wall_hit_updated(hit_points: PackedVector3Array)

# ============================================
# Export Settings
# ============================================
@export_group("Vision Settings")
@export var fov_degrees: float = 90.0  ## Field of view in degrees
@export var view_distance: float = 15.0  ## Vision distance in meters
@export var edge_ray_count: int = 30  ## Number of rays for FOV edges
@export var update_interval: float = 0.033  ## Update interval in seconds
@export var eye_height: float = 1.5  ## Eye height from ground

@export_group("Collision Settings")
@export_flags_3d_physics var wall_collision_mask: int = 2  ## Collision mask for walls

# ============================================
# State
# ============================================
var _enabled: bool = true
var _visible_polygon: PackedVector3Array = PackedVector3Array()
var _wall_hit_points: PackedVector3Array = PackedVector3Array()
var _time_since_update: float = 0.0

# ============================================
# References
# ============================================
var _character: Node3D = null

# ============================================
# Lifecycle
# ============================================

func _ready() -> void:
	_character = get_parent()


func _physics_process(delta: float) -> void:
	if not _enabled:
		return

	_time_since_update += delta
	if _time_since_update >= update_interval:
		_time_since_update = 0.0
		_calculate_shadow_cast_vision()


# ============================================
# Public API
# ============================================

## Get the visible polygon (used by FogOfWarSystem)
func get_visible_polygon() -> PackedVector3Array:
	return _visible_polygon


## Get wall hit points
func get_wall_hit_points() -> PackedVector3Array:
	return _wall_hit_points


## Force immediate vision update
func force_update() -> void:
	_calculate_shadow_cast_vision()


## Set field of view
func set_fov(degrees: float) -> void:
	fov_degrees = clamp(degrees, 1.0, 360.0)


## Set view distance
func set_view_distance(distance: float) -> void:
	view_distance = max(1.0, distance)


## Disable vision (for death, etc.)
func disable() -> void:
	_enabled = false
	_visible_polygon = PackedVector3Array()
	vision_updated.emit(_visible_polygon)


## Enable vision
func enable() -> void:
	_enabled = true
	_calculate_shadow_cast_vision()


## Check if vision is enabled
func is_enabled() -> bool:
	return _enabled


# ============================================
# Shadow Cast Vision Calculation
# ============================================

func _calculate_shadow_cast_vision() -> void:
	if not _character:
		return

	var space_state := get_world_3d().direct_space_state
	if not space_state:
		return

	var origin := _get_eye_position()
	var char_rotation := _get_look_angle()
	var half_fov := deg_to_rad(fov_degrees / 2.0)

	# FOV boundary angles
	var fov_min_angle := char_rotation - half_fov
	var fov_max_angle := char_rotation + half_fov

	# Collect wall corners
	var wall_corners := _collect_wall_corners(origin)

	# Build list of ray angles
	var ray_angles: Array[float] = []

	# 1. Evenly distributed rays across FOV
	for i in range(edge_ray_count + 1):
		var t := float(i) / float(edge_ray_count)
		var angle := fov_min_angle + t * (fov_max_angle - fov_min_angle)
		ray_angles.append(angle)

	# 2. Rays toward wall corners (with slight offsets for smooth edges)
	for corner in wall_corners:
		var to_corner := Vector2(corner.x - origin.x, corner.z - origin.z)
		var corner_angle := atan2(to_corner.x, -to_corner.y)  # -Z is forward

		# Only corners within FOV
		var relative_angle := _wrap_angle(corner_angle - char_rotation)
		if abs(relative_angle) <= half_fov + 0.01:
			# Corner and slight offsets for smooth edges
			ray_angles.append(corner_angle - 0.002)
			ray_angles.append(corner_angle)
			ray_angles.append(corner_angle + 0.002)

	# Sort angles
	ray_angles.sort()

	# Remove duplicates
	var unique_angles: Array[float] = []
	for angle in ray_angles:
		if unique_angles.is_empty() or abs(angle - unique_angles[-1]) > 0.0001:
			unique_angles.append(angle)

	# Cast rays at each angle
	_visible_polygon.clear()
	_wall_hit_points.clear()

	# First point is the origin
	_visible_polygon.append(origin)

	for angle in unique_angles:
		# Check if within FOV range
		var relative := _wrap_angle(angle - char_rotation)
		if abs(relative) > half_fov:
			continue

		var direction := Vector3(sin(angle), 0, -cos(angle))
		var end_point := origin + direction * view_distance

		var query := PhysicsRayQueryParameters3D.create(origin, end_point, wall_collision_mask)
		if _character is CollisionObject3D:
			query.exclude = [_character.get_rid()]

		var result := space_state.intersect_ray(query)

		if result:
			_visible_polygon.append(result.position)
			_wall_hit_points.append(result.position)
		else:
			_visible_polygon.append(end_point)

	vision_updated.emit(_visible_polygon)
	wall_hit_updated.emit(_wall_hit_points)


## Collect wall corner points from scene
func _collect_wall_corners(origin: Vector3) -> Array[Vector3]:
	var corners: Array[Vector3] = []

	# Search for walls in "walls" group
	var walls := get_tree().get_nodes_in_group("walls")

	for wall in walls:
		var wall_corners := _get_node_corners(wall)
		for corner in wall_corners:
			var dist := Vector2(corner.x - origin.x, corner.z - origin.z).length()
			if dist <= view_distance * 1.5:
				corners.append(corner)

	# Also check CSGBox3D nodes with collision layer 2
	_collect_csg_corners(get_tree().root, origin, corners)

	return corners


## Recursively collect corners from CSGBox3D nodes
func _collect_csg_corners(node: Node, origin: Vector3, corners: Array[Vector3]) -> void:
	if node is CSGBox3D:
		var csg: CSGBox3D = node
		if csg.use_collision and (csg.collision_layer & wall_collision_mask) != 0:
			var box_corners := _get_csg_box_corners(csg)
			for corner in box_corners:
				var dist := Vector2(corner.x - origin.x, corner.z - origin.z).length()
				if dist <= view_distance * 1.5:
					corners.append(corner)

	for child in node.get_children():
		_collect_csg_corners(child, origin, corners)


## Get corners from CSGBox3D
func _get_csg_box_corners(csg: CSGBox3D) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var half_size := csg.size / 2.0

	# Local XZ plane corners
	var local_corners := [
		Vector3(-half_size.x, 0, -half_size.z),
		Vector3(half_size.x, 0, -half_size.z),
		Vector3(half_size.x, 0, half_size.z),
		Vector3(-half_size.x, 0, half_size.z),
	]

	# Convert to global coordinates
	for local_corner in local_corners:
		result.append(csg.global_transform * local_corner)

	return result


## Get corners from StaticBody3D with BoxShape3D
func _get_node_corners(wall: Node) -> Array[Vector3]:
	var corners: Array[Vector3] = []

	if wall is StaticBody3D:
		var static_body: StaticBody3D = wall
		for child in static_body.get_children():
			if child is CollisionShape3D:
				var col_shape: CollisionShape3D = child
				var shape = col_shape.shape
				if shape is BoxShape3D:
					var box_shape: BoxShape3D = shape
					var half_size: Vector3 = box_shape.size / 2.0
					var local_corners: Array[Vector3] = [
						Vector3(-half_size.x, 0, -half_size.z),
						Vector3(half_size.x, 0, -half_size.z),
						Vector3(half_size.x, 0, half_size.z),
						Vector3(-half_size.x, 0, half_size.z),
					]
					var combined_transform: Transform3D = static_body.global_transform * col_shape.transform
					for local_corner in local_corners:
						corners.append(combined_transform * local_corner)

	return corners


## Wrap angle to -PI to PI range
func _wrap_angle(angle: float) -> float:
	while angle > PI:
		angle -= TAU
	while angle < -PI:
		angle += TAU
	return angle


func _get_eye_position() -> Vector3:
	if not _character:
		return global_position

	var pos := _character.global_position
	pos.y += eye_height
	return pos


func _get_look_angle() -> float:
	var direction := _get_look_direction()
	return atan2(direction.x, -direction.z)


func _get_look_direction() -> Vector3:
	if not _character:
		return Vector3.FORWARD

	# Try to get direction from animation controller
	if _character.has_method("get_anim_controller"):
		var anim_ctrl = _character.get_anim_controller()
		if anim_ctrl and anim_ctrl.has_method("get_look_direction"):
			var dir = anim_ctrl.get_look_direction()
			dir.y = 0
			if dir.length_squared() > 0.001:
				return dir.normalized()

	# Fallback: use character's forward direction
	var forward := _character.global_transform.basis.z
	forward.y = 0

	if forward.length_squared() < 0.001:
		return Vector3.FORWARD

	return forward.normalized()
