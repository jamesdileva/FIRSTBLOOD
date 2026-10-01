extends SceneTree
## Sprint 08 automated block verification (headless). Run from the root:
##   cmd //c godot --headless --path . -s res://tools/validation/block_check.gd
## Drives the real player with synthesized input and a controlled test
## hitbox, asserting the roadmap checklist: normal attacks fully blocked,
## heavy attacks reduced not negated, recovery leaves the player vulnerable,
## immediate re-block cannot bypass recovery, and the block cannot be held
## forever. Also asserts blocking resets the combo chain. Exits 0 on PASS.

const SETTLE_FRAMES := 30
const STARTUP_TICKS := 6    # block_startup 0.10 s
const ACTIVE_TICKS := 150   # block_active 2.5 s
const RECOVERY_TICKS := 45  # block_recovery 0.75 s

func _initialize() -> void:
	_run()

func _run() -> void:
	var failures: PackedStringArray = []
	var arena_scene: PackedScene = load("res://game/scenes/arena/arena.tscn")
	if arena_scene == null:
		printerr("BLOCK CHECK FAILURE: arena scene missing")
		quit(1)
		return
	var arena := arena_scene.instantiate()
	root.add_child(arena)
	await _wait(SETTLE_FRAMES)
	# Untyped on purpose: reads script members Godot's base classes lack.
	var player = get_first_node_in_group("player")
	if player == null:
		printerr("BLOCK CHECK FAILURE: player not found")
		quit(1)
		return
	var player_hurtbox = player.get_node_or_null("Hurtbox")
	if player_hurtbox == null:
		printerr("BLOCK CHECK FAILURE: player hurtbox missing")
		quit(1)
		return

	var blocked_events: Array[DamageEvent] = []
	var mitigated_events: Array[DamageEvent] = []
	var taken_events: Array[DamageEvent] = []
	player.hit_blocked.connect(func(event: DamageEvent) -> void: blocked_events.append(event))
	player.hit_mitigated.connect(func(event: DamageEvent) -> void: mitigated_events.append(event))
	player.hit_taken.connect(func(event: DamageEvent) -> void: taken_events.append(event))

	# Test hitbox: boss-faction, parked on the player, fired by the test.
	var holder := Node3D.new()
	holder.position = Vector3(-4.0, 0.9, 0.0)
	arena.add_child(holder)
	var hitbox := HitboxComponent.new()
	hitbox.faction = CombatTypes.Faction.BOSS
	hitbox.damage = 20.0
	hitbox.stagger_damage = 4.0
	hitbox.attack_id = &"test_strike"
	holder.add_child(hitbox)
	_add_box_shape(hitbox)
	await _wait(SETTLE_FRAMES)

	# --- 1. A normal attack during active block is fully negated. ---
	hitbox.hit_type = CombatTypes.HitType.NORMAL
	Input.action_press("block")
	await _wait(STARTUP_TICKS + 3)
	if player.state != player.State.BLOCK_ACTIVE:
		failures.append("block not active after startup (state %s)" % player.state)
	hitbox.set_active(true)
	await _wait(5)
	hitbox.set_active(false)
	Input.action_release("block")
	await _wait(3)
	if blocked_events.size() != 1:
		failures.append("normal attack produced %d blocked events (expected 1)" % blocked_events.size())
	if taken_events.size() != 0:
		failures.append("damage leaked through a full block: %d events" % taken_events.size())
	if mitigated_events.size() != 0:
		failures.append("normal attack was mitigated instead of fully blocked")

	# --- 2. A heavy attack during active block is reduced, not negated. ---
	await _wait(RECOVERY_TICKS + 5)
	blocked_events.clear()
	mitigated_events.clear()
	taken_events.clear()
	Input.action_press("block")
	await _wait(STARTUP_TICKS + 3)
	hitbox.hit_type = CombatTypes.HitType.HEAVY
	hitbox.set_active(true)
	await _wait(5)
	hitbox.set_active(false)
	Input.action_release("block")
	await _wait(3)
	if mitigated_events.size() != 1:
		failures.append("heavy attack produced %d mitigated events (expected 1)" % mitigated_events.size())
	elif not is_equal_approx(mitigated_events[0].amount, 20.0 * player.block_heavy_multiplier):
		failures.append("mitigated damage wrong: %.2f (expected %.2f)" % [
			mitigated_events[0].amount, 20.0 * player.block_heavy_multiplier,
		])
	if taken_events.size() != 0:
		failures.append("blocked heavy attack still dealt full damage: %d events" % taken_events.size())

	# --- 3. Recovery leaves the player vulnerable; re-block cannot bypass it. ---
	await _wait(RECOVERY_TICKS + 5)
	blocked_events.clear()
	mitigated_events.clear()
	taken_events.clear()
	Input.action_press("block")
	await _wait(STARTUP_TICKS + 3)
	Input.action_release("block")  # drop the guard into recovery
	await _wait(2)
	if player.state != player.State.BLOCK_RECOVERY:
		failures.append("early release did not enter recovery (state %s)" % player.state)
	# Hit during recovery: must be taken in full.
	hitbox.hit_type = CombatTypes.HitType.NORMAL
	hitbox.set_active(true)
	await _wait(5)
	hitbox.set_active(false)
	if taken_events.size() != 1:
		failures.append("recovery hit was not taken in full (%d taken)" % taken_events.size())
	if blocked_events.size() != 0 or mitigated_events.size() != 0:
		failures.append("recovery incorrectly blocked/mitigated damage")
	# Hold block through the remaining recovery: no guard re-entry allowed.
	Input.action_press("block")
	var bypassed := false
	for _i in RECOVERY_TICKS - 12:
		await physics_frame
		if player.state == player.State.BLOCK_STARTUP or player.state == player.State.BLOCK_ACTIVE:
			bypassed = true
	if bypassed:
		failures.append("re-block bypassed the recovery window")
	Input.action_release("block")
	await _wait(RECOVERY_TICKS)

	# --- 4. The block cannot be held forever: expiry and generous re-cycle. ---
	blocked_events.clear()
	mitigated_events.clear()
	taken_events.clear()
	Input.action_press("block")
	var saw_active := false
	var saw_recovery_while_held := false
	var saw_recycle := false
	for _i in STARTUP_TICKS + ACTIVE_TICKS + RECOVERY_TICKS + 15:
		await physics_frame
		if player.state == player.State.BLOCK_ACTIVE:
			saw_active = true
		elif player.state == player.State.BLOCK_RECOVERY:
			saw_recovery_while_held = true
		elif player.state == player.State.BLOCK_STARTUP and saw_recovery_while_held:
			saw_recycle = true
	Input.action_release("block")
	if not saw_active:
		failures.append("block never became active while held")
	if not saw_recovery_while_held:
		failures.append("active block never expired while held (held forever)")
	if not saw_recycle:
		failures.append("block did not re-engage after recovery while held")
	await _wait(RECOVERY_TICKS + 5)

	# --- 5. Blocking resets the combo chain. ---
	await _settle_player(player, Vector3(3.0, 0.5, 0.0))
	player.rotation.y = -PI / 2.0
	var boss = get_first_node_in_group("boss")
	var boss_hurtbox = boss.get_node_or_null("Hurtbox")
	if boss_hurtbox == null:
		printerr("BLOCK CHECK FAILURE: boss hurtbox missing")
		quit(1)
		return
	var combo_ids: Array[StringName] = []
	boss_hurtbox.damaged.connect(func(event: DamageEvent) -> void: combo_ids.append(event.attack_id))
	await _wait(SETTLE_FRAMES)  # any leftover combo grace expires
	await _tap_attack()         # light_01
	await _wait(30)             # swing ends; combo grace still alive
	await _tap_block()          # block resets the chain
	await _wait(55)             # block cycle plays out fully
	await _tap_attack()         # must be light_01, not light_02
	await _wait(30)
	if combo_ids.size() != 2 or combo_ids[0] != &"light_01" or combo_ids[1] != &"light_01":
		failures.append("blocking did not reset the combo: %s" % combo_ids)

	hitbox.set_active(false)
	blocked_events.clear()
	mitigated_events.clear()
	taken_events.clear()
	combo_ids.clear()
	# Capture exports before teardown: `player` dies with the arena.
	var heavy_multiplier: float = player.block_heavy_multiplier
	arena.free()

	if failures.is_empty():
		print("BLOCK CHECK: PASS (normal negated, heavy x%.1f, recovery vulnerable, no bypass, expiry+recycle, combo reset)" % [
			heavy_multiplier,
		])
		quit(0)
	else:
		for failure in failures:
			printerr("BLOCK CHECK FAILURE: " + failure)
		quit(1)

func _tap_attack() -> void:
	Input.action_press("attack")
	await _wait(2)
	Input.action_release("attack")

func _tap_block() -> void:
	Input.action_press("block")
	await _wait(2)
	Input.action_release("block")

func _settle_player(player, pos: Vector3) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	await _wait(SETTLE_FRAMES)

func _add_box_shape(area: Area3D) -> void:
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	shape_node.shape = box
	area.add_child(shape_node)

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
