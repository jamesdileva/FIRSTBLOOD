class_name BossController
extends CharacterBody3D
## Reusable boss framework (guide §11, Sprint 10): brain-driven state machine,
## target tracking, weighted data-driven attacks, health, defeat. Sprint 11
## inserts TELEGRAPH into the attack flow, Sprints 13/14 add stagger/breakout —
## this controller is the host for all of it.

signal state_changed(new_state: State)
signal defeated

enum State { OBSERVE, APPROACH, SELECT_ATTACK, TELEGRAPH, ATTACK, RECOVERY, DEAD }

@export var attacks: Array[BossAttackData] = []
@export var movement_speed := 3.0
@export var acceleration := 20.0
@export var deceleration := 25.0
@export var turn_speed := 8.0
@export var arena_half_extent := 18.0

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _target: Node3D
var _cooldowns: Dictionary = {}
var _current_attack: BossAttackData
var _rng := RandomNumberGenerator.new()
var _telegraph_marker: MeshInstance3D
var _telegraph_aura: MeshInstance3D
var _telegraph_mat: StandardMaterial3D
var state_elapsed := 0.0

@onready var _attack_hitbox: HitboxComponent = $AttackHitbox
@onready var _hurtbox: HurtboxComponent = $Hurtbox
@onready var _health: HealthComponent = $Health

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
	_health.died.connect(_on_died)
	# For the boss, the hurtbox signal IS the resolved path (D-033): bosses
	# have no mitigation layer, so nothing negates their incoming damage.
	_hurtbox.damaged.connect(_health.apply_damage)

func _physics_process(delta: float) -> void:
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
	_enforce_arena_bounds()

func is_dead() -> bool:
	return state == State.DEAD

## Clean reset for retry flows (roadmap: "boss can be reset cleanly").
func reset() -> void:
	_health.reset()
	_cooldowns.clear()
	_current_attack = null
	_attack_hitbox.set_active(false)
	_hide_telegraph()
	state = State.OBSERVE

func _observe_physics(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
	move_and_slide()
	_face_target(delta)
	if _target == null:
		return
	if BossBrain.select_attack(attacks, _flat_distance(), _cooldowns, _rng) != null:
		state = State.SELECT_ATTACK
	elif _flat_distance() > _best_max_range():
		state = State.APPROACH
	# else: in range but everything is cooling down — stand and watch.

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
	# The warning is only honest while it points at a reachable target —
	# leave the attack's range (with a small grace margin) and it cancels.
	if _target == null or _flat_distance() > _current_attack.max_range + 0.5:
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
	# Rooted while swinging, like the player.
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
	move_and_slide()
	var active := state_elapsed >= _current_attack.startup \
			and state_elapsed < _current_attack.startup + _current_attack.active
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
		state = State.OBSERVE

func _on_died() -> void:
	_attack_hitbox.set_active(false)
	_current_attack = null
	_hide_telegraph()
	state = State.DEAD
	defeated.emit()

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
