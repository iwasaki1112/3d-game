class_name InputRotationComponent
extends Node

## Mouse-based character rotation component
## Click near a character and drag to rotate them to face the mouse position

signal rotation_started()
signal rotation_ended()
signal clicked()  ## Emitted on short click (not long-press) on character
signal clicked_empty()  ## Emitted on short click on empty area (not on character)

## Proximity check radius for click detection (fallback when raycast misses)
@export var click_radius: float = 0.3
## Collision mask for character detection (Layer 1 = characters)
@export_flags_3d_physics var character_collision_mask: int = 1
## Ground plane height for mouse intersection calculation
@export var ground_plane_height: float = 0.0
## Hold duration before rotation starts (seconds)
@export var hold_duration: float = 0.2
## If true, rotation requires menu activation (disables long-press auto-rotation)
@export var require_menu_activation: bool = false

var _character: CharacterBody3D
var _external_rotation_mode: bool = false  ## External control for rotation mode
var _camera: Camera3D
var _is_rotating: bool = false
var _is_holding: bool = false
var _is_any_click_started: bool = false
var _click_started_on_any_character: bool = false  ## 他のキャラクターも含めてクリックされたか
var _rotation_blocked: bool = false
var _hold_timer: float = 0.0
var _hold_mouse_pos: Vector2
var _ground_plane: Plane


func _ready() -> void:
	_character = get_parent() as CharacterBody3D
	if _character == null:
		push_error("[InputRotationComponent] Parent must be CharacterBody3D")
	_ground_plane = Plane(Vector3.UP, ground_plane_height)


## Setup camera reference for mouse raycasting
func setup(camera: Camera3D) -> void:
	_camera = camera


func _process(delta: float) -> void:
	# External rotation mode is handled via tap-to-rotate in _unhandled_input
	if _external_rotation_mode:
		return

	# Long-press rotation (only if menu activation is not required)
	if require_menu_activation:
		return

	if _is_holding and not _is_rotating and not _rotation_blocked:
		_hold_timer += delta
		if _hold_timer >= hold_duration:
			# Only allow rotation if character is selected
			if _character.is_selected():
				_is_rotating = true
				rotation_started.emit()
				_rotate_character_to_mouse(_hold_mouse_pos)
			else:
				# Block rotation attempt on unselected character
				_rotation_blocked = true


func _unhandled_input(event: InputEvent) -> void:
	if _camera == null or _character == null:
		return

	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_is_any_click_started = true
				_click_started_on_any_character = _is_clicking_on_any_character(mouse_event.position)
				if _external_rotation_mode:
					# External mode: tap to rotate instantly and end rotation mode
					_rotate_character_to_mouse(mouse_event.position)
					_external_rotation_mode = false
					rotation_ended.emit()
				elif _is_clicking_on_character(mouse_event.position):
					_is_holding = true
					_hold_timer = 0.0
					_hold_mouse_pos = mouse_event.position
			else:
				if _is_any_click_started and not _external_rotation_mode:
					if _is_holding and not _is_rotating and not _rotation_blocked:
						# Short click on character - not long-press for rotation
						clicked.emit()
					elif not _is_holding and not _click_started_on_any_character:
						# Short click on empty area - only if click started on empty area
						clicked_empty.emit()
					# Note: if _rotation_blocked, emit nothing (attempted rotation on unselected)
					_is_holding = false
					_hold_timer = 0.0
					_rotation_blocked = false
					_click_started_on_any_character = false
					if _is_rotating:
						_is_rotating = false
						rotation_ended.emit()
				_is_any_click_started = false

	if event is InputEventMouseMotion:
		if _is_holding:
			_hold_mouse_pos = event.position
		if _is_rotating:
			_rotate_character_to_mouse(event.position)


func _is_clicking_on_character(mouse_pos: Vector2) -> bool:
	var ray_origin = _camera.project_ray_origin(mouse_pos)
	var ray_direction = _camera.project_ray_normal(mouse_pos)
	var ray_end = ray_origin + ray_direction * 100.0

	# Raycast to check direct character hit
	var space_state = _character.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = character_collision_mask
	var result = space_state.intersect_ray(query)

	if result and result.collider == _character:
		return true

	# Proximity fallback - allow clicks near character
	var intersection = _ground_plane.intersects_ray(ray_origin, ray_direction)
	if intersection:
		var click_pos = intersection as Vector3
		var char_pos = _character.global_position
		if click_pos.distance_to(char_pos) < click_radius:
			return true

	return false


## Check if clicking on ANY character (not just this one) - for clicked_empty detection
func _is_clicking_on_any_character(mouse_pos: Vector2) -> bool:
	var ray_origin = _camera.project_ray_origin(mouse_pos)
	var ray_direction = _camera.project_ray_normal(mouse_pos)
	var ray_end = ray_origin + ray_direction * 100.0

	var space_state = _character.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = character_collision_mask
	var result = space_state.intersect_ray(query)

	# Hit any character
	if result and result.collider is CharacterBody3D:
		return true

	return false


func _rotate_character_to_mouse(mouse_pos: Vector2) -> void:
	var ray_origin = _camera.project_ray_origin(mouse_pos)
	var ray_direction = _camera.project_ray_normal(mouse_pos)

	var intersection = _ground_plane.intersects_ray(ray_origin, ray_direction)
	if intersection == null:
		return

	var char_pos = _character.global_position
	var target_pos = intersection as Vector3
	var direction = target_pos - char_pos
	direction.y = 0  # Horizontal only

	if direction.length_squared() < 0.01:
		return

	var target_angle = atan2(direction.x, direction.z)
	_character.rotation.y = target_angle


## Check if currently in rotation mode
func is_rotating() -> bool:
	return _is_rotating or _external_rotation_mode


## Start rotation mode externally (from menu)
func start_rotation_mode() -> void:
	_external_rotation_mode = true
	rotation_started.emit()


## Stop rotation mode externally
func stop_rotation_mode() -> void:
	if _external_rotation_mode:
		_external_rotation_mode = false
		_is_holding = false
		rotation_ended.emit()
