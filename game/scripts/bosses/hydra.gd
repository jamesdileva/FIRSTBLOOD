extends BossController
## Sprint 41 (D-113/114): the Hydra — a multi-head/regeneration encounter.
## Three heads, each its own targetable HurtboxComponent with a LOCAL
## health gate (HEAD_HP). A head's damage drains BOTH the local gate and
## the main health (whose max = the sum of the heads — the boss dies
## NATURALLY when the total head damage crosses it). A head at 0: dead
## (its hurtbox collision disables, the head tints dark) with a timed
## regeneration (REGEN_DELAY → the gate restores, the hurtbox re-enables).
## The attack payload scales with the alive heads (D-114): fewer heads,
## weaker bites — `_push_payload` overrides to ×alive/total.

const HEAD_COUNT := 3
const HEAD_HP := 35.0
const REGEN_DELAY := 5.0

var _head_hp: Array[float] = [HEAD_HP, HEAD_HP, HEAD_HP]
var _head_dead: Array[bool] = [false, false, false]
var _head_regen_left: Array[float] = [0.0, 0.0, 0.0]

func _ready() -> void:
	super._ready()
	# the body's hurtbox: the heads are the ONLY targets — its collision
	# disables (the node stays: the BossController's connect needs it)
	var body_shape := get_node_or_null("Hurtbox/CollisionShape3D") as CollisionShape3D
	if body_shape != null:
		body_shape.disabled = true
	for i in HEAD_COUNT:
		var head := get_node_or_null("Head%d" % (i + 1)) as Node3D
		if head == null:
			push_warning("Hydra head %d missing — the encounter degrades to a single target." % (i + 1))
			continue
		var hurtbox := head.get_node_or_null("Hurtbox") as HurtboxComponent
		if hurtbox != null:
			hurtbox.damaged.connect(_on_head_damaged.bind(i))

## The head's damage: the local gate drains AND the main health drains
## (the main's max = the sum — the progress persists through regeneration).
func _on_head_damaged(event: DamageEvent, head_index: int) -> void:
	if _head_dead[head_index]:
		return
	_head_hp[head_index] -= event.amount
	_stagger.add_stagger(event)
	_health.apply_damage(event)
	if _head_hp[head_index] <= 0.0:
		_kill_head(head_index)

func _kill_head(head_index: int) -> void:
	_head_dead[head_index] = true
	_head_hp[head_index] = 0.0
	_head_regen_left[head_index] = REGEN_DELAY
	var head := get_node_or_null("Head%d" % (head_index + 1)) as Node3D
	if head == null:
		return
	var hurtbox := head.get_node_or_null("Hurtbox") as HurtboxComponent
	if hurtbox != null:
		hurtbox.monitorable = false
	var shape := head.get_node_or_null("Hurtbox/CollisionShape3D") as CollisionShape3D
	if shape != null:
		shape.disabled = true
	var mesh := head.get_node_or_null("Mesh") as MeshInstance3D
	if mesh != null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.3, 0.3, 0.3)
		mesh.material_override = material

## The regeneration: a dead head's gate restores and its hurtbox
## re-enables after REGEN_DELAY — the main health does NOT regenerate.
func alive_heads() -> int:
	var count := 0
	for dead in _head_dead:
		if not dead:
			count += 1
	return count

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	for i in HEAD_COUNT:
		if _head_dead[i]:
			_head_regen_left[i] -= delta
			if _head_regen_left[i] <= 0.0:
				_revive_head(i)

func _revive_head(head_index: int) -> void:
	_head_dead[head_index] = false
	_head_hp[head_index] = HEAD_HP
	_head_regen_left[head_index] = 0.0
	var head := get_node_or_null("Head%d" % (head_index + 1)) as Node3D
	if head == null:
		return
	var hurtbox := head.get_node_or_null("Hurtbox") as HurtboxComponent
	if hurtbox != null:
		hurtbox.monitorable = true
	var shape := head.get_node_or_null("Hurtbox/CollisionShape3D") as CollisionShape3D
	if shape != null:
		shape.disabled = false
	var mesh := head.get_node_or_null("Mesh") as MeshInstance3D
	if mesh != null:
		mesh.material_override = null

## D-114: the payload scales with the alive heads — fewer heads, weaker
## bites. The head/state change affects combat behavior verifiably.
func _push_payload(attack: BossAttackData) -> void:
	super._push_payload(attack)
	var alive := alive_heads()
	if alive < HEAD_COUNT:
		_attack_hitbox.damage = attack.damage * float(alive) / float(HEAD_COUNT)

func reset() -> void:
	super.reset()
	for i in HEAD_COUNT:
		_head_dead[i] = false
		_head_hp[i] = HEAD_HP
		_head_regen_left[i] = 0.0
		_revive_head(i)
