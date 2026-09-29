extends CharacterBody3D
## Player controller: movement (Sprint 02), committed dodge (Sprint 03),
## light attack (Sprint 05). Combat intent crosses actors only via
## DamageEvents carried by Hitbox/HurtboxComponents (guide §6).

signal state_changed(new_state: State)
## Hit-reaction hook (D-021): hitstop, VFX, and target reactions hang from
## this in Sprints 13/15 without touching the attack state machine.
signal attack_connected(event: DamageEvent, target: HurtboxComponent)

enum State { IDLE, MOVE, AIRBORNE, DODGE, DODGE_RECOVERY, ATTACK }

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
## D-018 (playtest): short vulnerable window; movement stays live, only
## re-dodging is blocked until it completes.
@export var dodge_recovery := 0.15

@export_group("Attack")
## Timing only (D-019) — the payload lives on the AttackHitbox node.
@export var attack_startup := 0.10
@export var attack_active := 0.12
@export var attack_recovery := 0.25

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _dodge_direction := Vector3.ZERO
var state_elapsed := 0.0

@onready var _visual: Node3D = $Visual
@onready var _attack_hitbox: HitboxComponent = $AttackHitbox

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
			State.ATTACK:
				play_animation("attack_01")

func _ready() -> void:
	_attack_hitbox.hit_landed.connect(_on_attack_hit_landed)

func _on_attack_hit_landed(event: DamageEvent, target: HurtboxComponent) -> void:
	attack_connected.emit(event, target)

func _physics_process(delta: float) -> void:
	state_elapsed += delta
	match state:
		State.DODGE:
			_dodge_physics(delta)
		State.DODGE_RECOVERY:
			_dodge_recovery_physics(delta)
		State.ATTACK:
			_attack_physics(delta)
		_:
			_neutral_physics(delta)
	_update_facing(delta)
	_apply_lean(delta)
	_enforce_arena_bounds()

func is_invulnerable() -> bool:
	return state == State.DODGE and state_elapsed < dodge_invulnerability

func _neutral_physics(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if is_on_floor():
		if Input.is_action_just_pressed("dodge"):
			_start_dodge(input_dir)
			return
		if Input.is_action_just_pressed("attack"):
			_start_attack()
			return
	_neutral_movement(delta, input_dir)
	_update_movement_state()

func _neutral_movement(delta: float, input_dir: Vector2) -> void:
	var direction := _camera_relative_direction(input_dir)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	# Brake harder than we accelerate so releasing input stops the player on a
	# dime instead of sliding (roadmap: "does not slide uncontrollably").
	var rate := acceleration if direction != Vector3.ZERO else deceleration
	velocity.x = move_toward(velocity.x, direction.x * movement_speed, rate * delta)
	velocity.z = move_toward(velocity.z, direction.z * movement_speed, rate * delta)
	move_and_slide()

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
	# D-018: a short vulnerable window, not a movement lock — input moves the
	# player normally; only a new dodge is blocked until the window completes.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_neutral_movement(delta, input_dir)
	if state_elapsed >= dodge_recovery:
		_update_movement_state()

func _start_attack() -> void:
	state = State.ATTACK

func _attack_physics(delta: float) -> void:
	# Rooted, committed (D-020): movement input ignored, hitbox live only
	# during [startup, startup + active).
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()
	var active_started := state_elapsed >= attack_startup
	var active_ended := state_elapsed >= attack_startup + attack_active
	_attack_hitbox.set_active(active_started and not active_ended)
	if state_elapsed >= attack_startup + attack_active + attack_recovery:
		_attack_hitbox.set_active(false)
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
