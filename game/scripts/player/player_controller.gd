extends CharacterBody3D
## Player controller: movement (Sprint 02), committed dodge (Sprint 03),
## light combo chain (Sprint 06). Combat intent crosses actors only via
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

@export_group("Combo")
## Data-driven chain (D-022): per-step timing, payload, and buffer windows.
@export var combo: ComboData

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _dodge_direction := Vector3.ZERO
var _combo_index := 0
var _buffered := false
var _grace_left := 0.0
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
			# ATTACK is animated by _play_combo_step: the swing's animation
			# comes from the combo step data, and chaining re-enters ATTACK
			# without a state change.

func _ready() -> void:
	_ensure_combo()
	_attack_hitbox.hit_landed.connect(_on_attack_hit_landed)

## Never soft-lock on missing data: fall back to a single swing.
func _ensure_combo() -> void:
	if combo != null and not combo.steps.is_empty():
		return
	combo = ComboData.new()
	var step := ComboStepData.new()
	step.attack_id = &"light_01"
	step.animation = &"attack_01"
	combo.steps.append(step)
	push_warning("ComboData missing — using fallback single-step combo.")

func _current_step() -> ComboStepData:
	return combo.steps[_combo_index]

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
			_play_combo_step()
			return
	_tick_combo_grace(delta)
	_neutral_movement(delta, input_dir)
	_update_movement_state()

## A step that ended without buffered input keeps the chain alive briefly;
## letting the grace expire resets the combo to its first step (D-023).
func _tick_combo_grace(delta: float) -> void:
	if _grace_left <= 0.0:
		return
	_grace_left -= delta
	if _grace_left <= 0.0:
		_grace_left = 0.0
		_combo_index = 0

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
	# Any dodge interrupts the chain (guide §9 reset conditions).
	_combo_index = 0
	_grace_left = 0.0
	_buffered = false
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

func _play_combo_step() -> void:
	var step := _current_step()
	# Per-step payload (D-022): the shared hitbox carries what this swing
	# hits with; the controller carries only timing and chain flow.
	_attack_hitbox.damage = step.damage
	_attack_hitbox.stagger_damage = step.stagger_damage
	_attack_hitbox.attack_id = step.attack_id
	_grace_left = 0.0
	state = State.ATTACK
	# Chaining into the next step while already ATTACK skips the setter's
	# reset (same value), so restart the step clock explicitly.
	state_elapsed = 0.0
	play_animation(step.animation)

func _attack_physics(delta: float) -> void:
	var step := _current_step()
	# Rooted, committed (D-020): movement input ignored, hitbox live only
	# during [startup, startup + active).
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()
	if not _buffered \
			and state_elapsed >= step.buffer_open \
			and state_elapsed <= step.buffer_close \
			and Input.is_action_just_pressed("attack"):
		_buffered = true
	var active_started := state_elapsed >= step.startup
	var active_ended := state_elapsed >= step.startup + step.active
	_attack_hitbox.set_active(active_started and not active_ended)
	if state_elapsed >= step.total_duration():
		_attack_hitbox.set_active(false)
		_advance_after_step()

func _advance_after_step() -> void:
	var next := _combo_index + 1
	if _buffered and next < combo.steps.size():
		_combo_index = next
		_play_combo_step()
	elif next < combo.steps.size():
		# Unbuffered: keep the chain alive for reset_timeout so the next
		# press continues it (D-023); expiring resets to the first step.
		_combo_index = next
		_grace_left = combo.reset_timeout
		state = State.IDLE
	else:
		# Chain completed (Sprint 07 appends the automatic finisher here).
		_combo_index = 0
		state = State.IDLE
	_buffered = false

## Debug overlay text: current step, chain length, buffered flag.
func combo_debug_text() -> String:
	if state != State.ATTACK and _grace_left <= 0.0:
		return "-"
	return "%d/%d%s" % [_combo_index + 1, combo.steps.size(), " buffered" if _buffered else ""]

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
