extends SceneTree
## Sprint 06 automated combo-chain verification (headless). Run from the root:
##   cmd //c godot --headless --path . -s res://tools/validation/combo_check.gd
## Drives the real arena scene with synthesized input against the boss
## hurtbox and asserts the roadmap checklist: the correct step sequence
## (including the wrap to a fresh combo), mashing chains responsively while
## every swing respects its full recovery and the combo never deadlocks,
## a dropped input resets after the grace window, and a late press (past
## buffer_close) is ignored rather than chaining accidentally.
## Exits 0 on PASS, 1 on FAIL.

const SETTLE_FRAMES := 30
const STEP_GAP_FRAMES := 34      # longest step (light_03) is 33.6 ticks
const GRACE_FRAMES := 21         # reset_timeout 0.35 s
const RESET_MARGIN_FRAMES := 25  # grace + margin -> combo index fully reset
const MASH_ITERATIONS := 100     # 2 ticks per press -> ~7 swings

func _initialize() -> void:
	_run()

func _run() -> void:
	var failures: PackedStringArray = []
	var arena_scene: PackedScene = load("res://game/scenes/arena/arena.tscn")
	if arena_scene == null:
		printerr("COMBO CHECK FAILURE: arena scene missing")
		quit(1)
		return
	var arena := arena_scene.instantiate()
	root.add_child(arena)
	await _wait(SETTLE_FRAMES)
	# Untyped on purpose: reads script members Godot's base classes lack.
	var player = get_first_node_in_group("player")
	var boss = get_first_node_in_group("boss")
	if player == null or boss == null:
		printerr("COMBO CHECK FAILURE: player or boss not found")
		quit(1)
		return
	var boss_hurtbox = boss.get_node_or_null("Hurtbox")
	var attack_hitbox = player.get_node_or_null("AttackHitbox")
	if boss_hurtbox == null or attack_hitbox == null:
		printerr("COMBO CHECK FAILURE: hurtbox/hitbox nodes missing")
		quit(1)
		return

	var combo_ids: Array[StringName] = []
	var combo_frames: Array[int] = []
	boss_hurtbox.damaged.connect(func(event: DamageEvent) -> void:
		combo_ids.append(event.attack_id)
		combo_frames.append(Engine.get_physics_frames()))

	# Stand in reach of the boss, facing it (+X); yaw snapped directly.
	await _settle_player(player, Vector3(3.0, 0.5, 0.0))
	player.rotation.y = -PI / 2.0

	# --- 1. Correct sequence: chain 1-2-3 then wrap to a fresh combo. ---
	for _i in 4:
		await _tap_attack()
		await _wait(STEP_GAP_FRAMES)
	var expected: Array[StringName] = [&"light_01", &"light_02", &"light_03", &"light_01"]
	if combo_ids.size() != expected.size():
		failures.append("expected %d swings, got %d (%s)" % [expected.size(), combo_ids.size(), combo_ids])
	for i in mini(expected.size(), combo_ids.size()):
		if combo_ids[i] != expected[i]:
			failures.append("swing %d was %s, expected %s" % [i, combo_ids[i], expected[i]])
	await _combo_cooldown(player)

	# --- 2. Mashing: buffered chaining, recovery respected, no deadlock. ---
	combo_ids.clear()
	combo_frames.clear()
	for _i in MASH_ITERATIONS:
		Input.action_press("attack")
		await physics_frame
		Input.action_release("attack")
		await physics_frame
	if combo_ids.size() < 6:
		failures.append("mash produced only %d swings" % combo_ids.size())
	var cycle: Array[StringName] = [&"light_01", &"light_02", &"light_03"]
	for i in combo_ids.size():
		if combo_ids[i] != cycle[i % 3]:
			failures.append("mash swing %d was %s, expected %s" % [i, combo_ids[i], cycle[i % 3]])
			break
	for i in range(1, combo_frames.size()):
		var gap: int = combo_frames[i] - combo_frames[i - 1]
		if gap < 24 or gap > 38:
			failures.append("mash gap %d ticks between hits %d->%d (full recovery not respected)" % [gap, i - 1, i])
	await _wait_until_idle(player, 60)
	if player.state == player.State.ATTACK:
		failures.append("combo stuck in ATTACK after mashing stopped")
	if attack_hitbox.is_active():
		failures.append("hitbox active after combo ended")
	await _combo_cooldown(player)

	# --- 3. Dropped input: chain continues inside the grace, resets after. ---
	combo_ids.clear()
	await _tap_attack()          # light_01
	await _wait(30)              # step ends unbuffered; grace starts
	await _wait(8)               # still inside grace
	await _tap_attack()          # continues the chain -> light_02
	await _wait(STEP_GAP_FRAMES)
	await _wait(RESET_MARGIN_FRAMES + 15)  # light_02 ends; grace expires -> reset
	combo_ids.clear()
	await _tap_attack()
	await _wait(STEP_GAP_FRAMES)
	if combo_ids.size() != 1 or combo_ids[0] != &"light_01":
		failures.append("dropped input did not reset the combo: %s" % combo_ids)
	await _combo_cooldown(player)

	# --- 4. Late input past buffer_close is ignored, not buffered. ---
	combo_ids.clear()
	await _tap_attack()          # light_01 starts
	await _wait(20)              # past buffer_close (18 ticks), still in recovery
	await _tap_attack()          # late press: must be ignored
	await _wait(12)              # step ends; grace runs
	await _wait(RESET_MARGIN_FRAMES + 15)  # grace expires -> full reset
	await _tap_attack()          # must be light_01, not light_02
	await _wait(STEP_GAP_FRAMES)
	if combo_ids.size() != 2 or combo_ids[0] != &"light_01" or combo_ids[1] != &"light_01":
		failures.append("late input created an accidental combo step: %s" % combo_ids)

	combo_ids.clear()
	combo_frames.clear()
	arena.free()

	if failures.is_empty():
		print("COMBO CHECK: PASS (sequence, buffered chaining, %d mash presses, grace reset, late-input ignored)" % [
			MASH_ITERATIONS,
		])
		quit(0)
	else:
		for failure in failures:
			printerr("COMBO CHECK FAILURE: " + failure)
		quit(1)

func _tap_attack() -> void:
	Input.action_press("attack")
	await _wait(2)
	Input.action_release("attack")

func _combo_cooldown(player) -> void:
	await _wait_until_idle(player, 60)
	await _wait(RESET_MARGIN_FRAMES)

func _wait_until_idle(player, max_frames: int) -> void:
	for _i in max_frames:
		if player.state != player.State.ATTACK:
			return
		await physics_frame

func _settle_player(player, pos: Vector3) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	await _wait(SETTLE_FRAMES)

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
