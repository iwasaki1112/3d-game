extends CharacterBody3D
## Mixamo player with strafe movement using BlendSpace2D
## Based on Godot4ThirdPersonCombatPrototype style

const WALK_SPEED := 2.5
const RUN_SPEED := 5.0
const ROTATION_SPEED := 15.0

# Animation designed speeds (typical Mixamo values)
# Adjust these if animations still slide
const ANIM_WALK_SPEED := 1.4  # Speed the walk animation was designed for
const ANIM_RUN_SPEED := 5.5   # Speed the run animation was designed for

@onready var model: Node3D = $CharacterModel
@onready var anim_player: AnimationPlayer = $CharacterModel/AnimationPlayer
@onready var anim_tree: AnimationTree = $AnimationTree

var current_speed := WALK_SPEED
var is_running := false
var aim_position := Vector3.ZERO

# Smooth blend values (Combat Prototype style)
var _input_dir := Vector2.ZERO
var _movement_blend := 0.0

# Ground plane for mouse raycasting
var ground_plane := Plane(Vector3.UP, 0)

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)

	if anim_player:
		_setup_animation_loops()

	_setup_animation_tree()

func _setup_animation_loops() -> void:
	var loop_anims := [
		"idle", "idle_aiming",
		"walk_forward", "walk_backward", "walk_left", "walk_right",
		"walk_forward_left", "walk_forward_right", "walk_backward_left", "walk_backward_right",
		"run_forward", "run_backward", "run_left", "run_right",
		"run_forward_left", "run_forward_right", "run_backward_left", "run_backward_right",
	]

	var anim_lib = anim_player.get_animation_library("")
	for anim_name in loop_anims:
		if anim_player.has_animation(anim_name):
			var anim = anim_lib.get_animation(anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR

func _setup_animation_tree() -> void:
	if not anim_tree:
		push_error("AnimationTree not found!")
		return

	var blend_tree := AnimationNodeBlendTree.new()

	# BlendSpace2D for walk - Combat Prototype convention:
	# X: right(+) / left(-)
	# Y: backward(+) / forward(-)
	var walk_blend_space := AnimationNodeBlendSpace2D.new()
	walk_blend_space.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED
	walk_blend_space.auto_triangles = true
	walk_blend_space.min_space = Vector2(-1, -1)
	walk_blend_space.max_space = Vector2(1, 1)

	var walk_anims := {
		Vector2(0, -1): "walk_forward",
		Vector2(0, 1): "walk_backward",
		Vector2(-1, 0): "walk_left",
		Vector2(1, 0): "walk_right",
		Vector2(-0.707, -0.707): "walk_forward_left",
		Vector2(0.707, -0.707): "walk_forward_right",
		Vector2(-0.707, 0.707): "walk_backward_left",
		Vector2(0.707, 0.707): "walk_backward_right",
	}

	for pos in walk_anims:
		var anim_name: String = walk_anims[pos]
		if anim_player.has_animation(anim_name):
			var anim_node := AnimationNodeAnimation.new()
			anim_node.animation = anim_name
			walk_blend_space.add_blend_point(anim_node, pos)

	# BlendSpace2D for run
	var run_blend_space := AnimationNodeBlendSpace2D.new()
	run_blend_space.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED
	run_blend_space.auto_triangles = true
	run_blend_space.min_space = Vector2(-1, -1)
	run_blend_space.max_space = Vector2(1, 1)

	var run_anims := {
		Vector2(0, -1): "run_forward",
		Vector2(0, 1): "run_backward",
		Vector2(-1, 0): "run_left",
		Vector2(1, 0): "run_right",
		Vector2(-0.707, -0.707): "run_forward_left",
		Vector2(0.707, -0.707): "run_forward_right",
		Vector2(-0.707, 0.707): "run_backward_left",
		Vector2(0.707, 0.707): "run_backward_right",
	}

	for pos in run_anims:
		var anim_name: String = run_anims[pos]
		if anim_player.has_animation(anim_name):
			var anim_node := AnimationNodeAnimation.new()
			anim_node.animation = anim_name
			run_blend_space.add_blend_point(anim_node, pos)

	var idle_anim := AnimationNodeAnimation.new()
	idle_anim.animation = "idle"

	# TimeScale nodes to adjust animation speed to match movement speed
	var walk_speed_node := AnimationNodeTimeScale.new()
	var run_speed_node := AnimationNodeTimeScale.new()

	var walk_run_blend := AnimationNodeBlend2.new()
	var idle_movement_blend := AnimationNodeBlend2.new()

	blend_tree.add_node("Idle", idle_anim, Vector2(-200, 0))
	blend_tree.add_node("WalkBlend", walk_blend_space, Vector2(-400, 200))
	blend_tree.add_node("RunBlend", run_blend_space, Vector2(-400, 400))
	blend_tree.add_node("WalkSpeed", walk_speed_node, Vector2(-200, 200))
	blend_tree.add_node("RunSpeed", run_speed_node, Vector2(-200, 400))
	blend_tree.add_node("WalkRunBlend", walk_run_blend, Vector2(100, 300))
	blend_tree.add_node("IdleMovementBlend", idle_movement_blend, Vector2(300, 150))

	# Connect BlendSpace -> TimeScale -> WalkRunBlend
	blend_tree.connect_node("WalkSpeed", 0, "WalkBlend")
	blend_tree.connect_node("RunSpeed", 0, "RunBlend")
	blend_tree.connect_node("WalkRunBlend", 0, "WalkSpeed")
	blend_tree.connect_node("WalkRunBlend", 1, "RunSpeed")
	blend_tree.connect_node("IdleMovementBlend", 0, "Idle")
	blend_tree.connect_node("IdleMovementBlend", 1, "WalkRunBlend")
	blend_tree.connect_node("output", 0, "IdleMovementBlend")

	anim_tree.tree_root = blend_tree
	anim_tree.anim_player = anim_player.get_path()
	anim_tree.active = true

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CONFINED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)

func _physics_process(delta: float) -> void:
	_update_aim_position()

	# Get world space input direction (Combat Prototype style)
	var world_input := Vector3.ZERO
	world_input.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	world_input.z = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))

	is_running = Input.is_key_pressed(KEY_SHIFT)
	current_speed = RUN_SPEED if is_running else WALK_SPEED

	# Rotate model to face aim position
	# Note: Mixamo models face +Z, but Basis.looking_at points -Z toward target
	# So we negate look_dir to make model's +Z face the target
	var look_dir := aim_position - global_position
	look_dir.y = 0
	if look_dir.length() > 0.1:
		var target_basis := Basis.looking_at(-look_dir.normalized(), Vector3.UP)
		var target_quat := target_basis.get_rotation_quaternion()
		var current_quat := Quaternion(model.transform.basis)
		var new_quat := current_quat.slerp(target_quat, ROTATION_SPEED * delta)
		model.transform.basis = Basis(new_quat)

	# Calculate movement
	var move_dir := world_input.normalized()

	if move_dir.length() > 0.1:
		velocity.x = move_dir.x * current_speed
		velocity.z = move_dir.z * current_speed

		# Calculate blend position based on angle between facing and movement
		# This avoids issues with basis transformation flipping axes
		var char_forward := model.global_transform.basis.z  # +Z is forward for Mixamo
		var angle := char_forward.signed_angle_to(move_dir, Vector3.UP)
		# Convert angle to blend position:
		# angle = 0 → forward → (0, -1)
		# angle = PI/2 → left → (-1, 0)
		# angle = -PI/2 → right → (1, 0)
		# angle = PI → backward → (0, 1)
		var target_blend := Vector2(-sin(angle), -cos(angle))

		# Smooth blend transition (Combat Prototype style)
		var blend_speed := 0.3 if target_blend.length() > _input_dir.length() else 0.1
		_input_dir = _input_dir.lerp(target_blend, blend_speed)

		_movement_blend = lerp(_movement_blend, 1.0, 0.1)
	else:
		velocity.x = 0
		velocity.z = 0
		_movement_blend = lerp(_movement_blend, 0.0, 0.1)
		_input_dir = _input_dir.lerp(Vector2.ZERO, 0.1)

	_update_animation_tree()

	if not is_on_floor():
		velocity.y -= 9.8 * delta

	move_and_slide()

func _update_aim_position() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)

	var intersection = ground_plane.intersects_ray(ray_origin, ray_dir)
	if intersection:
		aim_position = intersection

func _update_animation_tree() -> void:
	if not anim_tree or not anim_tree.active:
		return

	# Only update blend position if moving (Combat Prototype style)
	if _movement_blend > 0.01:
		anim_tree.set("parameters/WalkBlend/blend_position", _input_dir)
		anim_tree.set("parameters/RunBlend/blend_position", _input_dir)

	# Adjust animation speed to match movement speed (prevents sliding)
	var actual_speed := Vector2(velocity.x, velocity.z).length()
	var walk_scale := actual_speed / ANIM_WALK_SPEED if ANIM_WALK_SPEED > 0 else 1.0
	var run_scale := actual_speed / ANIM_RUN_SPEED if ANIM_RUN_SPEED > 0 else 1.0
	# Clamp to reasonable range to prevent weird playback
	walk_scale = clamp(walk_scale, 0.5, 2.0)
	run_scale = clamp(run_scale, 0.5, 2.0)
	anim_tree.set("parameters/WalkSpeed/scale", walk_scale)
	anim_tree.set("parameters/RunSpeed/scale", run_scale)

	var run_blend := 1.0 if is_running else 0.0
	anim_tree.set("parameters/WalkRunBlend/blend_amount", run_blend)
	anim_tree.set("parameters/IdleMovementBlend/blend_amount", _movement_blend)
