extends CharacterBody3D
## Sprint 02: responsive third-person movement — camera-relative direction,
## tuned acceleration/deceleration, rotation toward movement, gravity, and a
## temporary arena-bound clamp. Combat states arrive in later sprints.

signal state_changed(new_state: State)

enum State { IDLE, MOVE, AIRBORNE }

@export var movement_speed := 5.0
@export var acceleration := 40.0
@export var deceleration := 50.0
@export var turn_speed := 12.0
@export var arena_half_extent := 18.0
## Placeholder responsiveness feedback until real animations exist (D-008).
@export var lean_amount := 0.08

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))

@onready var _visual: Node3D = $Visual

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := _camera_relative_direction(input_dir)

	if not is_on_floor():
		velocity.y -= _gravity * delta

	# Brake harder than we accelerate so releasing input stops the player on a
	# dime instead of sliding (roadmap: "does not slide uncontrollably").
	var rate := acceleration if direction != Vector3.ZERO else deceleration
	velocity.x = move_toward(velocity.x, direction.x * movement_speed, rate * delta)
	velocity.z = move_toward(velocity.z, direction.z * movement_speed, rate * delta)
	move_and_slide()

	_update_facing(delta, direction)
	_apply_lean(delta)
	_enforce_arena_bounds()
	_update_state(delta)

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

func _update_facing(delta: float, direction: Vector3) -> void:
	if direction == Vector3.ZERO:
		return
	# Yaw that points the body's -Z (forward) along the movement direction.
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))

func _apply_lean(delta: float) -> void:
	var local_velocity := _visual.global_transform.basis.inverse() * Vector3(velocity.x, 0.0, velocity.z)
	var target_pitch := clampf(-local_velocity.z / movement_speed, -1.0, 1.0) * lean_amount
	var target_roll := clampf(-local_velocity.x / movement_speed, -1.0, 1.0) * lean_amount
	_visual.rotation.x = lerpf(_visual.rotation.x, target_pitch, 1.0 - exp(-10.0 * delta))
	_visual.rotation.z = lerpf(_visual.rotation.z, target_roll, 1.0 - exp(-10.0 * delta))

func _enforce_arena_bounds() -> void:
	# Temporary arena boundary until Sprint 17 adds the real Colosseum walls.
	global_position.x = clampf(global_position.x, -arena_half_extent, arena_half_extent)
	global_position.z = clampf(global_position.z, -arena_half_extent, arena_half_extent)

func _update_state(_delta: float) -> void:
	if not is_on_floor():
		state = State.AIRBORNE
	elif Vector3(velocity.x, 0.0, velocity.z).length() > 0.1:
		state = State.MOVE
	else:
		state = State.IDLE

var state: State = State.IDLE:
	set(value):
		if value == state:
			return
		state = value
		state_changed.emit(value)
		match value:
			State.IDLE:
				play_animation("idle")
			State.MOVE:
				play_animation("run")
			State.AIRBORNE:
				play_animation("airborne")

## Basic animation hook (guide §16 naming). No-ops until an AnimationPlayer
## with the named animation is attached to the player scene.
func play_animation(anim_name: String) -> void:
	var animation_player := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player != null and animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
