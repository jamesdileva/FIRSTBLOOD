extends SceneTree
## Sprint 12 flagship verification: a complete real fight (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/gladiator_check.gd
## Phase A: a scripted player WINS using attack + block + dodge — blocks the
##   light string, dodge-cancels out of the heavy telegraph, mashes on
##   recoveries; asserts the boss dies while the player survives.
## Phase B: a passive player LOSES — the boss defeats them; no soft-locks.
## Phase C: retry resets both sides and the fight resumes.
## Also asserts attack variety (no single-attack spam). Exits 0 on PASS.

const SETTLE_FRAMES := 30

func _initialize() -> void:
	_run()

func _run() -> void:
	var failures: PackedStringArray = []
	var arena_scene: PackedScene = load("res://game/scenes/arena/arena.tscn")
	if arena_scene == null:
		printerr("GLADIATOR CHECK FAILURE: arena scene missing")
		quit(1)
		return
	var arena := arena_scene.instantiate()
	root.add_child(arena)
	await _wait(2)  # deferred tree entry
	var player = get_first_node_in_group("player")
	var boss = get_first_node_in_group("boss")
	if player == null or boss == null:
		printerr("GLADIATOR CHECK FAILURE: player or boss not found")
		quit(1)
		return
	var player_health = player.get_node("Health")
	var boss_health = boss.get_node("Health")

	# --- Phase A: the scripted player WINS. ---
	var player_blocked := [0]
	player.hit_blocked.connect(func(_event: DamageEvent) -> void: player_blocked[0] += 1)
	var seen_attacks := {}
	var phase_a_ticks := 0
	var mash_edge := false
	boss.reset()
	await _place_player(player, Vector3(2.6, 0.5, 0.0))
	while not boss.is_dead() and phase_a_ticks < 6000:
		await physics_frame
		phase_a_ticks += 1
		var distance: float = (boss.global_position - player.global_position).length()
		if boss.state == boss.State.TELEGRAPH:
			seen_attacks[boss._current_attack.attack_id] = true
			Input.action_release("attack")
			mash_edge = false
			if boss._current_attack.hit_type != CombatTypes.HitType.NORMAL:
				# Heavy incoming: dodge away (out of range -> boss cancels).
				Input.action_press("dodge")
				Input.action_press("move_left")
			else:
				Input.action_release("dodge")
				Input.action_release("move_left")
				Input.action_press("block")  # light string: negated
		elif boss.state == boss.State.ATTACK:
			seen_attacks[boss._current_attack.attack_id] = true
			Input.action_release("attack")
			mash_edge = false
			Input.action_press("block")
		else:
			# Openings: back off when the boss lunges into contact (it has a
			# 1.2 m minimum for its heavy), walk in when far, and mash in the
			# band — soft-facing (D-039) aligns every swing, so no facing
			# management is needed here.
			Input.action_release("dodge")
			Input.action_release("block")
			if distance < 1.3:  # stay where the heavy's 1.2 m minimum reaches
				Input.action_release("attack")
				mash_edge = false
				Input.action_press("move_left")
				Input.action_release("move_right")
			elif distance > 1.6:
				Input.action_release("attack")
				mash_edge = false
				Input.action_press("move_right")
				Input.action_release("move_left")
			else:
				Input.action_release("move_right")
				Input.action_release("move_left")
				if mash_edge:
					Input.action_release("attack")
				else:
					Input.action_press("attack")
				mash_edge = not mash_edge
	Input.action_release("dodge")
	Input.action_release("move_left")
	Input.action_release("block")
	Input.action_release("attack")
	if not boss.is_dead():
		failures.append("phase A: boss survived the scripted player (%d ticks, boss HP %.0f)" % [
			phase_a_ticks, float(boss_health.current_health),
		])
	if player_health.is_dead():
		failures.append("phase A: the scripted player died (HP %.0f)" % float(player_health.current_health))
	elif float(player_health.current_health) <= 0.0:
		failures.append("phase A: player HP non-positive without death state")
	if player_blocked[0] == 0:
		failures.append("phase A: the player never blocked (block unused)")
	# --- Phase B: a passive player LOSES. --- (2.0 m: light AND heavy reach)
	await _place_player(player, Vector3(2.0, 0.5, 0.0))
	boss.reset()
	var phase_b_ticks := 0
	while not player_health.is_dead() and phase_b_ticks < 6000:
		await physics_frame
		phase_b_ticks += 1
		if boss.state == boss.State.TELEGRAPH or boss.state == boss.State.ATTACK:
			seen_attacks[boss._current_attack.attack_id] = true
	if not player_health.is_dead():
		failures.append("phase B: the boss failed to defeat a passive player")
	if boss.is_dead():
		failures.append("phase B: the boss died to a passive player")
	if boss.state == boss.State.DEAD:
		failures.append("phase B: boss entered DEAD against a dead player")
	if not seen_attacks.has(&"boss_light") or not seen_attacks.has(&"boss_light_2"):
		failures.append("attack variety missing - saw %s" % [seen_attacks.keys()])

	# --- Phase C: retry resets both sides; the fight resumes. ---
	player.reset_for_retry()
	boss.reset()
	await _wait(SETTLE_FRAMES)
	if player_health.is_dead() or boss.is_dead():
		failures.append("phase C: retry left someone dead")
	var taken_after := [0]
	player.hit_taken.connect(func(_event: DamageEvent) -> void: taken_after[0] += 1)
	var boss_attacked_again := false
	for _i in 600:
		await physics_frame
		if taken_after[0] > 0:
			boss_attacked_again = true
			break
	if not boss_attacked_again:
		failures.append("phase C: the boss did not resume fighting after retry")

	arena.free()

	if failures.is_empty():
		print("GLADIATOR CHECK: PASS (win in %d ticks via attack/block/dodge, boss variety, loss, retry resumes)" % [
			phase_a_ticks,
		])
		quit(0)
	else:
		for failure in failures:
			printerr("GLADIATOR CHECK FAILURE: " + failure)
		quit(1)

func _place_player(player, pos: Vector3) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	await _wait(SETTLE_FRAMES)

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
