extends CharacterBody3D
## Sprint 03: responsive third-person movement plus the committed dodge.
## Movement: camera-relative direction, tuned acceleration/deceleration,
## rotation toward movement, gravity, temporary arena-bound clamp.
## Dodge (architecture §6, guide §8): authored movement state — travel burst,
## precisely bounded i-frames, committed recovery. Not a teleport, not a speed
## multiplier on walk input.

signal state_changed(new_state: State)

enum State { IDLE, MOVE, AIRBORNE, DODGE, DODGE_RECOVERY }

@export var movement_speed := 5.0
@export var acceleration := 40.0
@export var deceleration := 50.0
@export var turn_speed := 12.0
@export var arena_half_extent := 18.0
## Placeholder responsiveness feedback until real animations exist (D-008).
@export var lean_amount := 0.08

@export_group("Dodge")
## Travel burst speed; must stay clearly above movement_speed (roadmap check).
@export var dodge_speed := 12.0
@export var dodge_duration := 0.25
## Invulnerability lives only inside this window at the start of travel (D-012).
@export var dodge_invulnerability := 0.15
## Committed recovery: no input, no re-dodge, always vulnerable (D-012).
@export var dodge_recovery := 1.0

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _dodge_direction := Vector3.ZERO
var state_elapsed := 0.0

@onready var _visual: Node3D = $Visual

var state: State = State.IDLE:
	set(value):
		if value == state:
			return
		state = value
		state_elapsed = 0.0
		state_changed.emit(value)
		match value:
			State.IDLE:
				play_animation("idle")
			State.MOVE:
				play_animation("run")
			State.AIRBORNE:
				play_animation("airborne")
			State.DODGE:
				play_animation("dodge_start")
			State.DODGE_RECOVERY:
				play_animation("dodge_recover")

func _physics_process(delta: float) -> void:
	state_elapsed += delta
	match state:
		State.DODGE:
			_dodge_physics(delta)
		State.DODGE_RECOVERY:
			_dodge_recovery_physics(delta)
		_:
			_neutral_physics(delta)
	_update_facing(delta)
	_apply_lean(delta)
	_enforce_arena_bounds()

func is_invulnerable() -> bool:
	return state == State.DODGE and state_elapsed < dodge_invulnerability

func _neutral_physics(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if Input.is_action_just_pressed("dodge") and is_on_floor():
		_start_dodge(input_dir)
		return
	var direction := _camera_relative_direction(input_dir)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	# Brake harder than we accelerate so releasing input stops the player on a
	# dime instead of sliding (roadmap: "does not slide uncontrollably").
	var rate := acceleration if direction != Vector3.ZERO else deceleration
	velocity.x = move_toward(velocity.x, direction.x * movement_speed, rate * delta)
	velocity.z = move_toward(velocity.z, direction.z * movement_speed, rate * delta)
	move_and_slide()
	_update_movement_state()

func _start_dodge(input_dir: Vector2) -> void:
	var direction := _camera_relative_direction(input_dir)
	if direction == Vector3.ZERO:
		direction = _backward_direction()
	_dodge_direction = direction
	state = State.DODGE

func _backward_direction() -> Vector3:
	# Neutral dodge goes backward relative to the camera (D-011).
	var camera := get_viewport().get_camera_3d()
	var backward := global_basis.z if camera == null else camera.global_basis.z
	backward.y = 0.0
	return backward.normalized()

func _dodge_physics(delta: float) -> void:
	velocity.x = _dodge_direction.x * dodge_speed
	velocity.z = _dodge_direction.z * dodge_speed
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()
	if state_elapsed >= dodge_duration:
		# The burst ends cleanly: no recovery skid.
		velocity.x = 0.0
		velocity.z = 0.0
		state = State.DODGE_RECOVERY

func _dodge_recovery_physics(delta: float) -> void:
	# Committed recovery: input is ignored, the player stands/vulnerable.
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()
	if state_elapsed >= dodge_recovery:
		state = State.IDLE

func _update_movement_state() -> void:
	if not is_on_floor():
		state = State.AIRBORNE
	elif Vector3(velocity.x, 0.0, velocity.z).length() > 0.1:
		state = State.MOVE
	else:
		state = State.IDLE

func _update_facing(delta: float) -> void:
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	if planar.length() < 0.5:
		return
	# Yaw that points the body's -Z (forward) along the movement direction.
	var target_yaw := atan2(-planar.x, -planar.z)
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

## Basic animation hook (guide §16 naming). No-ops until an AnimationPlayer
## with the named animation is attached to the player scene.
func play_animation(anim_name: String) -> void:
	var animation_player := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player != null and animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
