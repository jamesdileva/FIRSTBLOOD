extends SceneTree
## Sprint 04 automated combat verification (headless). Run from the project root:
##   cmd //c godot --headless --path . -s res://tools/validation/combat_check.gd
## Builds a sandbox with player-faction hitboxes and a boss-faction target and
## asserts the roadmap checklist: a player hit damages a test target, self/team
## hits are ignored, overlapping hitboxes behave predictably, dodge i-frames
## block damage, and debug mode shows active areas. Exits 0 on PASS, 1 on FAIL.

const SETTLE_FRAMES := 5

func _initialize() -> void:
	_run()

func _run() -> void:
	var failures: PackedStringArray = []
	var world := Node3D.new()
	root.add_child(world)

	# Player-faction attacker at (1,0,0) with a 1x1x1 hitbox (x spans 0.5..1.5).
	var player_actor := Node3D.new()
	player_actor.name = "PlayerActor"
	player_actor.position = Vector3(1.0, 0.0, 0.0)
	world.add_child(player_actor)
	var hitbox := HitboxComponent.new()
	hitbox.faction = CombatTypes.Faction.PLAYER
	hitbox.damage = 10.0
	hitbox.stagger_damage = 5.0
	hitbox.knockback = Vector3(0.0, 0.0, 2.0)
	hitbox.attack_id = &"test_slash"
	player_actor.add_child(hitbox)
	_add_box_shape(hitbox)

	# Boss-faction test target at (1.2,0,0), sphere r=0.5 — overlapping.
	var target_actor := Node3D.new()
	target_actor.name = "TargetActor"
	target_actor.position = Vector3(1.2, 0.0, 0.0)
	world.add_child(target_actor)
	var hurtbox := HurtboxComponent.new()
	hurtbox.faction = CombatTypes.Faction.BOSS
	target_actor.add_child(hurtbox)
	_add_sphere_shape(hurtbox)

	var events: Array[DamageEvent] = []
	var blocked: Array[DamageEvent] = []
	hurtbox.damaged.connect(func(event: DamageEvent) -> void: events.append(event))
	hurtbox.damage_blocked.connect(func(event: DamageEvent) -> void: blocked.append(event))

	await _wait(SETTLE_FRAMES)

	# --- 1. A player-faction hit damages the test target, once, with the full payload. ---
	hitbox.set_active(true)
	await _wait(SETTLE_FRAMES)
	hitbox.set_active(false)
	await _wait(2)
	if events.size() != 1:
		failures.append("expected exactly 1 damage event, got %d" % events.size())
	else:
		var event := events[0]
		if event.amount != 10.0:
			failures.append("damage payload wrong: %.1f" % event.amount)
		if event.stagger_damage != 5.0:
			failures.append("stagger payload wrong: %.1f" % event.stagger_damage)
		if event.knockback != Vector3(0.0, 0.0, 2.0):
			failures.append("knockback payload wrong: %s" % event.knockback)
		if event.attack_id != &"test_slash":
			failures.append("attack_id wrong: %s" % event.attack_id)
		if event.source != player_actor:
			failures.append("event source is not the attacker")
		if event.hit_type != CombatTypes.HitType.NORMAL:
			failures.append("hit_type wrong")

	# --- 2. A second activation hits again exactly once (dedup resets per activation). ---
	events.clear()
	hitbox.set_active(true)
	await _wait(SETTLE_FRAMES)
	hitbox.set_active(false)
	await _wait(2)
	if events.size() != 1:
		failures.append("second activation produced %d events (expected 1)" % events.size())

	# --- 3. Same-faction (self) hits are ignored: layers and code both refuse. ---
	var friendly_hurtbox := HurtboxComponent.new()
	friendly_hurtbox.faction = CombatTypes.Faction.PLAYER
	player_actor.add_child(friendly_hurtbox)
	_add_sphere_shape(friendly_hurtbox)
	var friendly_events: Array[DamageEvent] = []
	friendly_hurtbox.damaged.connect(func(event: DamageEvent) -> void: friendly_events.append(event))
	await _wait(SETTLE_FRAMES)
	hitbox.set_active(true)
	await _wait(SETTLE_FRAMES)
	hitbox.set_active(false)
	await _wait(2)
	if not friendly_events.is_empty():
		failures.append("team filter failed: friendly hurtbox received %d events" % friendly_events.size())

	# --- 4. Multiple overlapping hitboxes behave predictably: one event each. ---
	var hitbox2 := HitboxComponent.new()
	hitbox2.faction = CombatTypes.Faction.PLAYER
	hitbox2.damage = 3.0
	player_actor.add_child(hitbox2)
	_add_box_shape(hitbox2)
	events.clear()
	hitbox.set_active(true)
	hitbox2.set_active(true)
	await _wait(SETTLE_FRAMES)
	hitbox.set_active(false)
	hitbox2.set_active(false)
	await _wait(2)
	if events.size() != 2:
		failures.append("two overlapping hitboxes produced %d events (expected 2, one each)" % events.size())
	else:
		var total := 0.0
		for event in events:
			total += event.amount
		if not is_equal_approx(total, 13.0):
			failures.append("combined damage wrong: %.1f (expected 13.0)" % total)

	# --- 5. Dodge-style immunity: an invulnerable owner blocks the hit. ---
	var immune_actor := InvulnerableTarget.new()
	immune_actor.position = Vector3(1.2, 0.0, 0.0)
	world.add_child(immune_actor)
	var immune_hurtbox := HurtboxComponent.new()
	immune_hurtbox.faction = CombatTypes.Faction.BOSS
	immune_actor.add_child(immune_hurtbox)
	_add_sphere_shape(immune_hurtbox)
	var immune_events: Array[DamageEvent] = []
	var immune_blocked: Array[DamageEvent] = []
	immune_hurtbox.damaged.connect(func(event: DamageEvent) -> void: immune_events.append(event))
	immune_hurtbox.damage_blocked.connect(func(event: DamageEvent) -> void: immune_blocked.append(event))
	await _wait(SETTLE_FRAMES)

	hitbox.set_active(true)
	await _wait(SETTLE_FRAMES)
	hitbox.set_active(false)
	await _wait(2)
	if not immune_events.is_empty():
		failures.append("i-frames failed: invulnerable target received %d events" % immune_events.size())
	if immune_blocked.is_empty():
		failures.append("blocked hit was not reported via damage_blocked")

	events.clear()
	immune_actor.invulnerable = false
	hitbox.set_active(true)
	await _wait(SETTLE_FRAMES)
	hitbox.set_active(false)
	await _wait(2)
	if events.size() != 1:
		failures.append("vulnerable target did not receive exactly 1 event (got %d)" % events.size())

	# --- 6. Debug mode shows active areas. ---
	CombatDebug.combat_shapes_visible = true
	hitbox.set_active(true)
	await _wait(2)
	var hit_debug := hitbox.get_node_or_null("DebugShape") as MeshInstance3D
	var hurt_debug := hurtbox.get_node_or_null("DebugShape") as MeshInstance3D
	if hit_debug == null:
		failures.append("hitbox debug shape missing")
	elif not hit_debug.visible:
		failures.append("hitbox debug shape not visible while active")
	if hurt_debug == null:
		failures.append("hurtbox debug shape missing")
	hitbox.set_active(false)
	await _wait(1)
	if hit_debug != null and hit_debug.visible:
		failures.append("hitbox debug shape still visible while inactive")
	CombatDebug.combat_shapes_visible = false

	# Release signal-captured refs before exit so ObjectDB stays clean.
	events.clear()
	blocked.clear()
	friendly_events.clear()
	immune_events.clear()
	immune_blocked.clear()
	world.free()

	if failures.is_empty():
		print("COMBAT CHECK: PASS (payload, dedup, team filter, overlapping hitboxes, i-frames, debug shapes)")
		quit(0)
	else:
		for failure in failures:
			printerr("COMBAT CHECK FAILURE: " + failure)
		quit(1)

class InvulnerableTarget extends Node3D:
	var invulnerable := true

	func is_invulnerable() -> bool:
		return invulnerable

func _add_box_shape(area: Area3D) -> void:
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	shape_node.shape = box
	area.add_child(shape_node)

func _add_sphere_shape(area: Area3D) -> void:
	var shape_node := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.5
	shape_node.shape = sphere
	area.add_child(shape_node)

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
