class_name BossController
extends CharacterBody3D
## Reusable boss framework (guide §11, Sprint 10): brain-driven state machine,
## target tracking, weighted data-driven attacks, health, defeat. Sprint 11
## inserts TELEGRAPH into the attack flow, Sprints 13/14 add stagger/breakout —
## this controller is the host for all of it.

signal state_changed(new_state: State)
signal defeated
## D-037: emitted when the boss's guard negates an attack — feedback hook.
signal boss_blocked(event: DamageEvent)
## Sprint 13: emitted when a stagger opens the punish window.
signal stagger_started

enum State { OBSERVE, APPROACH, SELECT_ATTACK, TELEGRAPH, ATTACK, RECOVERY, GUARD, STAGGERED, BREAKOUT, DEAD }

@export var attacks: Array[BossAttackData] = []
@export var movement_speed := 3.0
@export var acceleration := 20.0
@export var deceleration := 25.0
@export var turn_speed := 8.0
@export var arena_half_extent := 18.0

@export_group("Breakout")
## Sprint 14 (D-045): a hit with this attack id during the stagger window
## breaks the boss out — the player's finisher tag.
@export var breakout_attack_id := StringName("finisher_01")
## Finishers needed inside one stagger window (MVP 1; Sprint 39 chains).
@export var breakout_finishers := 1
## Readable recovery after the breakout, then defend-or-attack (D-046).
@export var breakout_duration := 0.8

@export_group("Strings")
## D-040: post-string opening (architecture: "predictable recovery"). The
## boss stands down this long after a melee string ends, so the player gets
## a real window to act. A teaching boss pauses; a DPS-check boss doesn't.
@export var string_pause := 1.2

@export_group("Guard")
## Sprint 12 "basic defense" (D-037): raised after strings; negates NORMAL
## hits and reduces HEAVY/SPECIAL ones.
@export var guard_duration := 1.0
@export var guard_cooldown := 5.0
@export var guard_chance := 0.4
@export var guard_heavy_multiplier := 0.4

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _target: Node3D
var _cooldowns: Dictionary = {}
var _current_attack: BossAttackData
var _rng := RandomNumberGenerator.new()
var _telegraph_marker: MeshInstance3D
var _telegraph_aura: MeshInstance3D
var _telegraph_mat: StandardMaterial3D
var _guard_aura: MeshInstance3D
var _guard_mat: StandardMaterial3D
var _stagger_aura: MeshInstance3D
var _stagger_mat: StandardMaterial3D
var _finishers_in_stagger := 0
var _sword_pivot: Node3D
var _pause_left := 0.0
var _flinch := 0.0
var state_elapsed := 0.0

@onready var _attack_hitbox: HitboxComponent = $AttackHitbox
@onready var _visual: Node3D = $Visual
@onready var _hurtbox: HurtboxComponent = $Hurtbox
@onready var _health: HealthComponent = $Health
@onready var _stagger: StaggerComponent = $Stagger

var state: State = State.OBSERVE:
	set(value):
		if value == state:
			return
		state = value
		state_elapsed = 0.0
		state_changed.emit(value)

func _ready() -> void:
	_rng.randomize()
	if attacks.is_empty():
		push_warning("BossController has no attacks — it will observe but never fight.")
	_build_telegraph_visuals()
	_build_guard_visuals()
	_build_stagger_visuals()
	_sword_pivot = get_node_or_null("Visual/SwordPivot")
	_health.died.connect(_on_died)
	_stagger.staggered.connect(_enter_stagger)
	_attack_hitbox.hit_landed.connect(func(_event: DamageEvent, _target: HurtboxComponent) -> void:
		HitFeedback.request_hit_stop(30))
	# D-033 with the Sprint 12 guard: the hurtbox signal is still the boss's
	# resolved path, but an active GUARD negates/reduces before health.
	_hurtbox.damaged.connect(_resolve_incoming_damage)

func _physics_process(delta: float) -> void:
	# Sprint 15 hit-stop: the whole actor freezes while the window holds.
	if Time.get_ticks_msec() < HitFeedback.hit_stop_until_msec:
		velocity = Vector3.ZERO
		return
	state_elapsed += delta
	_tick_cooldowns(delta)
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player") as Node3D
	match state:
		State.DEAD:
			# Corpse: no attacks, no movement, just settle.
			velocity.x = 0.0
			velocity.z = 0.0
			_apply_gravity(delta)
			move_and_slide()
		State.OBSERVE:
			_observe_physics(delta)
		State.APPROACH:
			_approach_physics(delta)
		State.SELECT_ATTACK:
			_select_attack()
		State.TELEGRAPH:
			_telegraph_physics(delta)
		State.ATTACK:
			_attack_physics(delta)
		State.RECOVERY:
			_recovery_physics(delta)
		State.GUARD:
			_guard_physics(delta)
		State.STAGGERED:
			_staggered_physics(delta)
	_enforce_arena_bounds()
	_animate_sword(delta)
	# Sprint 15 flinch: a small tilt kick that decays back to rest.
	_flinch *= exp(-9.0 * delta)
	_visual.rotation.z = _flinch * 0.3

func is_dead() -> bool:
	return state == State.DEAD

## Sprint 15: current hit-reaction tilt (0..1), for verification and feel.
func flinch_level() -> float:
	return _flinch

## Clean reset for retry flows (roadmap: "boss can be reset cleanly").
func reset() -> void:
	_health.reset()
	_cooldowns.clear()
	_current_attack = null
	_attack_hitbox.set_active(false)
	_hide_telegraph()
	_hide_guard()
	_hide_stagger()
	_stagger.reset()
	_pause_left = 0.0
	state = State.OBSERVE

func _observe_physics(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
	move_and_slide()
	_face_target(delta)
	if _target == null or _target_is_dead():
		return  # stand down: never fight a corpse (roadmap: no soft-locks)
	if _pause_left > 0.0:
		_pause_left -= delta
		return  # D-040: the post-string opening the player acts in
	var distance := _flat_distance()
	if distance < _best_min_range() - 0.2:
		# D-041: inside every attack's minimum range — create space instead
		# of standing inert (the soft-lock the flagship check caught).
		_step_away_physics(delta)
		return
	if BossBrain.select_attack(attacks, distance, _cooldowns, _rng) != null:
		state = State.SELECT_ATTACK
	elif distance > _best_max_range():
		state = State.APPROACH
	# else: in range but everything is cooling down — stand and watch.

## D-041: back-pedal to a striking distance when the target hugs the boss.
func _step_away_physics(delta: float) -> void:
	_apply_gravity(delta)
	if _target != null:
		var away := global_position - _target.global_position
		away.y = 0.0
		var direction := away.normalized() if away.length() > 0.05 else Vector3.ZERO
		velocity.x = direction.x * movement_speed
		velocity.z = direction.z * movement_speed
	move_and_slide()
	_face_target(delta)

func _approach_physics(delta: float) -> void:
	_apply_gravity(delta)
	if _target != null:
		var to_target := _target.global_position - global_position
		to_target.y = 0.0
		var direction := to_target.normalized() if to_target.length() > 0.05 else Vector3.ZERO
		var rate := acceleration if direction != Vector3.ZERO else deceleration
		velocity.x = move_toward(velocity.x, direction.x * movement_speed, rate * delta)
		velocity.z = move_toward(velocity.z, direction.z * movement_speed, rate * delta)
	move_and_slide()
	_face_target(delta)
	if _flat_distance() <= _best_max_range():
		state = State.SELECT_ATTACK

func _select_attack() -> void:
	if _target_is_dead():
		state = State.OBSERVE
		return
	_current_attack = BossBrain.select_attack(attacks, _flat_distance(), _cooldowns, _rng)
	if _current_attack == null:
		state = State.OBSERVE
		return
	_push_payload(_current_attack)
	play_animation(_current_attack.animation)
	# D-034: the warning window comes before the windup; 0 means immediate.
	if _current_attack.telegraph_duration > 0.0:
		_show_telegraph(_current_attack)
		state = State.TELEGRAPH
	else:
		state = State.ATTACK

func _telegraph_physics(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
	move_and_slide()
	_face_target(delta)
	# The warning is only honest while it points at a reachable, living
	# target — leave the range (with a small grace margin) or die, and it cancels.
	if _target == null or _target_is_dead() or _flat_distance() > _current_attack.max_range + 0.5:
		_cancel_telegraph()
		return
	if state_elapsed >= _current_attack.telegraph_duration:
		_hide_telegraph()
		state = State.ATTACK

func _cancel_telegraph() -> void:
	# D-034: canceled attacks still pay the full cooldown so the player
	# cannot bait the telegraph forever.
	_cooldowns[_current_attack.attack_id] = _current_attack.cooldown
	_hide_telegraph()
	_current_attack = null
	state = State.OBSERVE

func _show_telegraph(attack: BossAttackData) -> void:
	# One visual language: yellow = NORMAL, red = HEAVY/SPECIAL (D-034).
	if _telegraph_mat != null:
		_telegraph_mat.albedo_color = Color(1.0, 0.2, 0.15, 0.5) if attack.hit_type != CombatTypes.HitType.NORMAL \
				else Color(1.0, 0.85, 0.2, 0.5)
	if _telegraph_marker != null:
		_telegraph_marker.visible = true
	if _telegraph_aura != null:
		_telegraph_aura.visible = true

func _hide_telegraph() -> void:
	if _telegraph_marker != null:
		_telegraph_marker.visible = false
	if _telegraph_aura != null:
		_telegraph_aura.visible = false

func _build_telegraph_visuals() -> void:
	# Placeholder readability visuals (D-035): a ground marker mirroring the
	# attack hitbox footprint plus a body aura. Real VFX at the art pass;
	# gameplay timing never depends on these.
	var telegraph_material := StandardMaterial3D.new()
	telegraph_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	telegraph_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	telegraph_material.albedo_color = Color(1.0, 0.85, 0.2, 0.5)
	_telegraph_mat = telegraph_material

	var marker := MeshInstance3D.new()
	marker.name = "TelegraphMarker"
	var box := BoxMesh.new()
	var shape := _attack_box_shape()
	if shape != null:
		box.size = Vector3(shape.size.x, 0.06, shape.size.z)
	else:
		box.size = Vector3(1.6, 0.06, 2.4)
	marker.mesh = box
	marker.material_override = telegraph_material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var attack_hitbox := get_node_or_null("AttackHitbox") as Node3D
	if attack_hitbox != null:
		marker.position = Vector3(attack_hitbox.position.x, 0.04, attack_hitbox.position.z)
	add_child(marker)
	marker.visible = false
	_telegraph_marker = marker

	var aura := MeshInstance3D.new()
	aura.name = "TelegraphAura"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.75
	capsule.height = 2.7
	aura.mesh = capsule
	aura.material_override = telegraph_material
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.position = Vector3(0, 1.25, 0)
	add_child(aura)
	aura.visible = false
	_telegraph_aura = aura

func _attack_box_shape() -> BoxShape3D:
	var attack_hitbox := get_node_or_null("AttackHitbox")
	if attack_hitbox == null:
		return null
	for child in attack_hitbox.get_children():
		var shape_node := child as CollisionShape3D
		if shape_node != null and shape_node.shape is BoxShape3D:
			return shape_node.shape
	return null

func _attack_physics(delta: float) -> void:
	_apply_gravity(delta)
	# Rooted unless this attack lunges (the pressure/approach attack).
	var active := state_elapsed >= _current_attack.startup \
			and state_elapsed < _current_attack.startup + _current_attack.active
	if _current_attack.lunge_speed > 0.0 and active and _target != null:
		var to_target := _target.global_position - global_position
		to_target.y = 0.0
		var direction := to_target.normalized() if to_target.length() > 0.05 else Vector3.ZERO
		velocity.x = direction.x * _current_attack.lunge_speed
		velocity.z = direction.z * _current_attack.lunge_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
	move_and_slide()
	_attack_hitbox.set_active(active)
	if state_elapsed >= _current_attack.startup + _current_attack.active:
		state = State.RECOVERY

func _recovery_physics(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
	move_and_slide()
	_face_target(delta)
	if state_elapsed >= _current_attack.recovery:
		_cooldowns[_current_attack.attack_id] = _current_attack.cooldown
		_continue_or_guard()

## D-036: followup attacks chain into a melee string; when the string ends,
## roll the D-037 guard — the Defensive-Response placeholder for Sprint 14.
func _continue_or_guard() -> void:
	var next := _attack_by_id(_current_attack.followup)
	var distance := _flat_distance()
	if next != null and not _target_is_dead() and distance <= next.max_range and distance >= next.min_range - 0.3:
		_current_attack = next
		_push_payload(next)
		play_animation(next.animation)
		if next.telegraph_duration > 0.0:
			_show_telegraph(next)
			state = State.TELEGRAPH
		else:
			state = State.ATTACK
		return
	if not _target_is_dead() and distance <= _best_max_range() \
			and not _cooldowns.has(&"guard") and _rng.randf() < guard_chance:
		_cooldowns[&"guard"] = guard_cooldown
		_show_guard()
		state = State.GUARD
		return
	# D-040: the post-string opening — a teaching boss stands down so the
	# player gets a real window to act (predictable recovery).
	_current_attack = null
	_pause_left = string_pause
	state = State.OBSERVE

func _attack_by_id(attack_id: StringName) -> BossAttackData:
	if attack_id == StringName(""):
		return null
	for attack in attacks:
		if attack != null and attack.attack_id == attack_id:
			return attack
	return null

func _guard_physics(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
	move_and_slide()
	_face_target(delta)
	if state_elapsed >= guard_duration:
		_hide_guard()
		state = State.OBSERVE

func _target_is_dead() -> bool:
	return _target != null and _target.has_method("is_dead") and _target.is_dead()

func _on_died() -> void:
	_attack_hitbox.set_active(false)
	_current_attack = null
	_hide_telegraph()
	_hide_guard()
	_hide_stagger()
	_stagger.reset()
	_finishers_in_stagger = 0
	state = State.DEAD
	defeated.emit()

## D-037: an active GUARD negates NORMAL hits and reduces HEAVY/SPECIAL
## ones before they reach health — the mirror of the player's block.
func _resolve_incoming_damage(event: DamageEvent) -> void:
	if is_dead():
		return
	if state == State.STAGGERED:
		_health.apply_damage(event)
		_flinch = minf(_flinch + 0.6, 1.0)  # Sprint 15 hit reaction
		if is_dead():
			return  # death beats breakout: never let the window revive a corpse
		# D-045: the finisher landing inside the punish window breaks out.
		if event.attack_id == breakout_attack_id:
			_finishers_in_stagger += 1
			if _finishers_in_stagger >= breakout_finishers:
				_finishers_in_stagger = 0
				_begin_breakout()
		return
	if state == State.GUARD:
		# Blocked hits build no stagger (D-043): the boss defended.
		if event.hit_type == CombatTypes.HitType.NORMAL:
			boss_blocked.emit(event)
			return
		event.amount *= guard_heavy_multiplier
	_health.apply_damage(event)
	_stagger.add_stagger(event)

## Sprint 13: the punish window — interrupts whatever the boss was doing
## (D-043) and lasts for the component's stagger_duration.
func _enter_stagger() -> void:
	if is_dead():
		return
	_attack_hitbox.set_active(false)
	_hide_telegraph()
	_hide_guard()
	_current_attack = null
	_finishers_in_stagger = 0
	_show_stagger()
	play_animation("stagger")
	state = State.STAGGERED
	stagger_started.emit()

func _staggered_physics(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
	move_and_slide()
	_face_target(delta)
	# Timer ender: no finisher landed, the window closes on its own (D-046).
	if _stagger.tick_recovery(delta):
		_hide_stagger()
		_pause_left = string_pause
		state = State.OBSERVE

## D-046: readable recovery, then defend or attack.
func _begin_breakout() -> void:
	_stagger.breakout()
	_hide_stagger()
	_show_guard()  # blue: the defensive posture the breakout reads as
	state = State.BREAKOUT

func _breakout_physics(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
	move_and_slide()
	_face_target(delta)
	if state_elapsed >= breakout_duration:
		_hide_guard()
		_pause_left = string_pause
		if _rng.randf() < 0.5 and not _cooldowns.has(&"guard"):
			_cooldowns[&"guard"] = guard_cooldown
			_show_guard()
			state = State.GUARD
		else:
			state = State.OBSERVE

func _show_stagger() -> void:
	if _stagger_mat != null:
		_stagger_mat.albedo_color = Color(0.8, 0.4, 1.0, 0.45)  # violet (D-044)
	if _stagger_aura != null:
		_stagger_aura.visible = true

func _hide_stagger() -> void:
	if _stagger_aura != null:
		_stagger_aura.visible = false

func _build_stagger_visuals() -> void:
	var stagger_material := StandardMaterial3D.new()
	stagger_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stagger_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	stagger_material.albedo_color = Color(0.8, 0.4, 1.0, 0.45)
	_stagger_mat = stagger_material
	var aura := MeshInstance3D.new()
	aura.name = "StaggerAura"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.78
	capsule.height = 2.8
	aura.mesh = capsule
	aura.material_override = stagger_material
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.position = Vector3(0, 1.25, 0)
	add_child(aura)
	aura.visible = false
	_stagger_aura = aura

func _show_guard() -> void:
	if _guard_mat != null:
		_guard_mat.albedo_color = Color(0.3, 0.6, 1.0, 0.45)
	if _guard_aura != null:
		_guard_aura.visible = true

func _hide_guard() -> void:
	if _guard_aura != null:
		_guard_aura.visible = false

func _build_guard_visuals() -> void:
	var guard_material := StandardMaterial3D.new()
	guard_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	guard_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	guard_material.albedo_color = Color(0.3, 0.6, 1.0, 0.45)
	_guard_mat = guard_material
	var aura := MeshInstance3D.new()
	aura.name = "GuardAura"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.75
	capsule.height = 2.7
	aura.mesh = capsule
	aura.material_override = guard_material
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.position = Vector3(0, 1.25, 0)
	add_child(aura)
	aura.visible = false
	_guard_aura = aura

## D-036: procedural sword anticipation and impact — the telegraph reads as
## a wind-up, the attack snaps through. No-op on framework hosts without a
## SwordPivot.
func _animate_sword(delta: float) -> void:
	if _sword_pivot == null:
		return
	var target_rotation := 0.0
	var speed := 6.0
	match state:
		State.TELEGRAPH:
			target_rotation = 1.1  # blade rises: the readable anticipation
			speed = 5.0
		State.ATTACK:
			target_rotation = -1.5  # snap through the swing
			speed = 22.0
		State.STAGGERED:
			target_rotation = 0.6  # hit reaction: guard droops mid-window
			speed = 8.0
	_sword_pivot.rotation.x = lerpf(_sword_pivot.rotation.x, target_rotation, 1.0 - exp(-speed * delta))

func _push_payload(attack: BossAttackData) -> void:
	_attack_hitbox.damage = attack.damage
	_attack_hitbox.stagger_damage = attack.stagger_damage
	_attack_hitbox.attack_id = attack.attack_id
	_attack_hitbox.hit_type = attack.hit_type

func _tick_cooldowns(delta: float) -> void:
	for attack_id in _cooldowns.keys():
		var remaining: float = _cooldowns[attack_id] - delta
		if remaining <= 0.0:
			_cooldowns.erase(attack_id)
		else:
			_cooldowns[attack_id] = remaining

func _flat_distance() -> float:
	if _target == null:
		return INF
	var offset := _target.global_position - global_position
	offset.y = 0.0
	return offset.length()

func _best_min_range() -> float:
	var best := INF
	for attack in attacks:
		if attack != null:
			best = minf(best, attack.min_range)
	return best

func _best_max_range() -> float:
	var best := 0.0
	for attack in attacks:
		if attack != null:
			best = maxf(best, attack.max_range)
	return best

func _face_target(delta: float) -> void:
	if _target == null:
		return
	var to_target := _target.global_position - global_position
	to_target.y = 0.0
	if to_target.length() < 0.1:
		return
	var target_yaw := atan2(-to_target.x, -to_target.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

func _enforce_arena_bounds() -> void:
	global_position.x = clampf(global_position.x, -arena_half_extent, arena_half_extent)
	global_position.z = clampf(global_position.z, -arena_half_extent, arena_half_extent)

## Animation hook (guide §16 naming). No-ops until an AnimationPlayer with
## the named animation is attached.
func play_animation(anim_name: String) -> void:
	var animation_player := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player != null and animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
