extends CharacterBody3D
## Sprint 01: raw input-to-movement placeholder so controller input and camera
## framing can be verified. Sprint 02 replaces this with tuned acceleration,
## deceleration, rotation toward movement, and real arena-boundary handling.

const MOVE_SPEED := 5.0
const ARENA_HALF_EXTENT := 18.0

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := _camera_relative_direction(input_dir)

	if not is_on_floor():
		velocity.y -= _gravity * delta

	velocity.x = direction.x * MOVE_SPEED
	velocity.z = direction.z * MOVE_SPEED
	move_and_slide()

	# Temporary arena boundary until Sprint 17 adds the real Colosseum walls.
	global_position.x = clampf(global_position.x, -ARENA_HALF_EXTENT, ARENA_HALF_EXTENT)
	global_position.z = clampf(global_position.z, -ARENA_HALF_EXTENT, ARENA_HALF_EXTENT)

func _camera_relative_direction(input_dir: Vector2) -> Vector3:
	if input_dir == Vector2.ZERO:
		return Vector3.ZERO
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(input_dir.x, 0.0, input_dir.y)
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := camera.global_basis.x
	right.y = 0.0
	right = right.normalized()
	return (right * input_dir.x + forward * -input_dir.y).normalized()
