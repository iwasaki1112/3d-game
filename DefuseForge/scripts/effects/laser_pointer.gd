extends Node3D
class_name LaserPointer
## Laser pointer effect for weapon aiming
## Displays a red laser beam from muzzle to collision point with a dot marker

@onready var ray_cast: RayCast3D = $RayCast3D
@onready var laser_beam: MeshInstance3D = $LaserBeam
@onready var laser_dot: MeshInstance3D = $LaserDot

const MAX_RANGE := 100.0  # Maximum laser range in meters
const BEAM_RADIUS := 0.002  # Beam thickness

var _is_active := false


func _ready() -> void:
	_set_visible(false)


func _process(_delta: float) -> void:
	if not _is_active:
		return
	_update_laser()


func toggle() -> void:
	_is_active = not _is_active
	_set_visible(_is_active)
	if _is_active:
		ray_cast.force_raycast_update()
		_update_laser()


func set_active(active: bool) -> void:
	_is_active = active
	_set_visible(_is_active)
	if _is_active:
		ray_cast.force_raycast_update()
		_update_laser()


func _set_visible(visible_state: bool) -> void:
	laser_beam.visible = visible_state
	laser_dot.visible = visible_state


func _update_laser() -> void:
	var hit_point: Vector3
	var hit_distance: float

	if ray_cast.is_colliding():
		hit_point = ray_cast.get_collision_point()
		hit_distance = global_position.distance_to(hit_point)
	else:
		# No collision - extend to max range
		hit_distance = MAX_RANGE
		hit_point = global_position + global_transform.basis.z * -MAX_RANGE

	# Update beam mesh - cylinder extends along Y axis, so we need to rotate and scale
	var beam_mesh := laser_beam.mesh as CylinderMesh
	beam_mesh.height = hit_distance

	# Position beam at midpoint between origin and hit point
	laser_beam.position = Vector3(0, 0, -hit_distance / 2.0)

	# Position dot at hit point (in local space)
	laser_dot.position = Vector3(0, 0, -hit_distance)

	# Show dot only when hitting something
	laser_dot.visible = ray_cast.is_colliding()
