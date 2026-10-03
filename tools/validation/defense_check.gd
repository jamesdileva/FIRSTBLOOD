extends SceneTree
## Sprint 09 automated defense-integration verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/defense_check.gd
## Walks the Sprint 09 combination matrix — idle→block, block→attack,
## attack→dodge, dodge→attack, dodge→block, block→dodge, recovery→attack,
## recovery→dodge — plus the immunity rules (D-030): cancel windows open only
## after a swing's hit lands, recovery windows stay committed, block is
## negation (never invulnerability). Exits 0 on PASS, 1 on FAIL.

const SETTLE_FRAMES := 30
const RECOVERY_TICKS := 45      # block_recovery 0.75 s
const DODGE_TRAVEL_TICKS := 15  # dodge_duration 0.25 s
const DODGE_RECOVERY_TICKS := 9 # dodge_recovery 0.15 s

func _initialize() -> void:
	_run()

func _run() -> void:
	var failures: PackedStringArray = []
	var arena_scene: PackedScene = load("res://game/scenes/arena/arena.tscn")
	if arena_scene == null:
		printerr("DEFENSE CHECK FAILURE: arena scene missing")
		quit(1)
		return
	var arena := arena_scene.instantiate()
	root.add_child(arena)
	await _wait(SETTLE_FRAMES)
	# Untyped on purpose: reads script members Godot's base classes lack.
	var player = get_first_node_in_group("player")
	var boss = get_first_node_in_group("boss")
	if player == null or boss == null:
		printerr("DEFENSE CHECK FAILURE: player or boss not found")
		quit(1)
		return
	var boss_hurtbox = boss.get_node_or_null("Hurtbox")
	if boss_hurtbox == null:
		printerr("DEFENSE CHECK FAILURE: boss hurtbox missing")
		quit(1)
		return
	var combo_ids: Array[StringName] = []
	boss_hurtbox.damaged.connect(func(event: DamageEvent) -> void: combo_ids.append(event.attack_id))

	await _place_player(player)

	# --- 1. attack recovery -> dodge cancels; the chain resets. ---
	await _tap_attack()
	await _wait(16)  # swing recovery (active window ended at ~tick 13)
	Input.action_press("dodge")
	var cancelled := await _wait_for_state(player, player.State.DODGE, 5)
	Input.action_release("dodge")
	if not cancelled:
		failures.append("dodge did not cancel attack recovery (state %s)" % player.state)
	await _wait(DODGE_TRAVEL_TICKS + DODGE_RECOVERY_TICKS + 6)
	await _place_player(player)
	combo_ids.clear()
	await _tap_attack()
	await _wait(30)
	if combo_ids.size() != 1 or combo_ids[0] != &"light_01":
		failures.append("attack-recovery dodge did not reset the chain: %s" % combo_ids)
	await _cooldown(player)

	# --- 2. attack startup/active: dodge is ignored (committed window). ---
	await _tap_attack()
	await _wait(8)  # active window (ticks 6-13)
	Input.action_press("dodge")
	await _wait(3)
	var still_attacking: bool = player.state == player.State.ATTACK
	Input.action_release("dodge")
	if not still_attacking:
		failures.append("dodge canceled an attack during startup/active — committed window broken")
	await _cooldown(player)

	# --- 3. attack recovery -> block cancels. ---
	await _tap_attack()
	await _wait(16)
	Input.action_press("block")
	var blocked_in := await _wait_for_state(player, player.State.BLOCK_ACTIVE, 12)
	if not blocked_in:
		failures.append("block did not cancel attack recovery (state %s)" % player.state)
	Input.action_release("block")
	await _wait(RECOVERY_TICKS + 5)
	await _place_player(player)

	# --- 4. block active -> dodge cancels. ---
	Input.action_press("block")
	await _wait(9)  # startup (6) + margin -> active
	Input.action_press("dodge")
	var dodge_cancel := await _wait_for_state(player, player.State.DODGE, 5)
	Input.action_release("dodge")
	if not dodge_cancel:
		failures.append("dodge did not cancel an active block")
	await _wait(DODGE_TRAVEL_TICKS + DODGE_RECOVERY_TICKS + 6)
	await _place_player(player)

	# --- 5. block active -> attack cancels, as a fresh light_01. ---
	Input.action_press("block")
	await _wait(9)
	combo_ids.clear()
	await _tap_attack()
	var attack_cancel := await _wait_for_state(player, player.State.ATTACK, 5)
	Input.action_release("block")
	if not attack_cancel:
		failures.append("attack did not cancel an active block (state %s)" % player.state)
	await _wait(30)
	if combo_ids.size() != 1 or combo_ids[0] != &"light_01":
		failures.append("attack out of block was not a fresh light_01: %s" % combo_ids)
	await _cooldown(player)

	# --- 6. block recovery -> dodge ignored until recovery completes. ---
	Input.action_press("block")
	await _wait(9)
	Input.action_release("block")
	await _wait(2)
	Input.action_press("dodge")
	await _wait(3)
	if player.state != player.State.BLOCK_RECOVERY:
		failures.append("dodge bypassed block recovery (state %s)" % player.state)
	Input.action_release("dodge")
	await _wait(RECOVERY_TICKS)
	Input.action_press("dodge")
	var dodge_after := await _wait_for_state(player, player.State.DODGE, 5)
	Input.action_release("dodge")
	if not dodge_after:
		failures.append("dodge did not work after block recovery completed")
	await _wait(DODGE_TRAVEL_TICKS + DODGE_RECOVERY_TICKS + 6)
	await _place_player(player)

	# --- 7. dodge recovery -> attack ignored until recovery completes. ---
	Input.action_press("dodge")
	await _wait(DODGE_TRAVEL_TICKS + 3)  # a few ticks into dodge recovery
	await _tap_attack()
	if player.state != player.State.DODGE_RECOVERY:
		failures.append("attack bypassed dodge recovery (state %s)" % player.state)
	await _wait(DODGE_RECOVERY_TICKS)
	await _place_player(player)
	combo_ids.clear()
	await _tap_attack()
	await _wait(30)
	if combo_ids.size() != 1 or combo_ids[0] != &"light_01":
		failures.append("attack after dodge recovery did not work: %s" % combo_ids)
	await _cooldown(player)

	# --- 8. block is negation, never invulnerability (D-030). ---
	Input.action_press("block")
	await _wait(9)
	if player.is_invulnerable():
		failures.append("active block granted dodge-style invulnerability")
	Input.action_release("block")
	await _wait(RECOVERY_TICKS + 5)

	combo_ids.clear()
	arena.free()

	if failures.is_empty():
		print("DEFENSE CHECK: PASS (cancel matrix, committed recoveries, block != immunity)")
		quit(0)
	else:
		for failure in failures:
			printerr("DEFENSE CHECK FAILURE: " + failure)
		quit(1)

func _place_player(player) -> void:
	player.global_position = Vector3(3.0, 0.5, 0.0)
	player.velocity = Vector3.ZERO
	player.rotation.y = -PI / 2.0
	await _wait(SETTLE_FRAMES)

func _cooldown(player) -> void:
	await _wait_until_idle(player, 60)
	await _wait(25)  # combo reset_timeout (21 ticks) + margin

func _wait_until_idle(player, max_frames: int) -> void:
	for _i in max_frames:
		if player.state != player.State.ATTACK:
			return
		await physics_frame

func _tap_attack() -> void:
	Input.action_press("attack")
	await _wait(2)
	Input.action_release("attack")

func _wait_for_state(player, target, max_frames: int) -> bool:
	for _i in max_frames:
		if player.state == target:
			return true
		await physics_frame
	return false

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
