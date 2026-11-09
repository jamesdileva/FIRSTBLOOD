extends SceneTree
## Sprint 10 automated boss-framework verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/boss_check.gd
## The ONLY check that lets the boss AI run. Asserts the roadmap checklist:
## the boss follows/approaches the player, enters and exits states, attacks
## the player when in range, is defeated without special-case code, cannot
## attack while dead, and resets cleanly. Exits 0 on PASS, 1 on FAIL.

const SETTLE_FRAMES := 30

func _initialize() -> void:
	_run()

func _run() -> void:
	# D-065 save isolation: checks never touch the user's real save.
	OS.set_environment("FIRSTBLOOD_CHECK_SAVE", "1")
	if FileAccess.file_exists("user://check_save.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://check_save.json"))
	var failures: PackedStringArray = []
	var arena_scene: PackedScene = load("res://game/scenes/arena/arena.tscn")
	if arena_scene == null:
		printerr("BOSS CHECK FAILURE: arena scene missing")
		quit(1)
		return
	var arena := arena_scene.instantiate()
	root.add_child(arena)
	await _wait(SETTLE_FRAMES)
	# Untyped on purpose: reads script members Godot's base classes lack.
	var player = get_first_node_in_group("player")
	var boss = get_first_node_in_group("boss")
	if player == null or boss == null:
		printerr("BOSS CHECK FAILURE: player or boss not found")
		quit(1)
		return
	var boss_health = boss.get_node_or_null("Health")
	var boss_hitbox = boss.get_node_or_null("AttackHitbox")
	if boss_health == null or boss_hitbox == null:
		printerr("BOSS CHECK FAILURE: boss health/hitbox missing")
		quit(1)
		return
	var player_taken: Array[DamageEvent] = []
	player.hit_taken.connect(func(event: DamageEvent) -> void: player_taken.append(event))
	var deaths := [0]  # array: lambdas capture locals by value
	boss_health.died.connect(func() -> void: deaths[0] += 1)

	# --- 1. The boss follows/approaches the player. ---
	var start_dist: float = _flat_dist(player, boss)
	await _wait(60)
	var moved_dist: float = _flat_dist(player, boss)
	if moved_dist > start_dist - 1.0:
		failures.append("boss did not approach the player (dist %.2f -> %.2f)" % [start_dist, moved_dist])

	# --- 2. In range: the boss attacks the player, cycling states. ---
	var attacked := false
	for _i in 500:
		await physics_frame
		if not player_taken.is_empty():
			attacked = true
			break
	if not attacked:
		failures.append("boss never attacked the player in range")
	var saw_attack_state := false
	var returned_from_attack := false
	for _i in 300:
		await physics_frame
		if boss.state == boss.State.ATTACK:
			saw_attack_state = true
		elif saw_attack_state and boss.state == boss.State.OBSERVE:
			returned_from_attack = true
			break
	if not saw_attack_state:
		failures.append("boss never entered the ATTACK state")
	if not returned_from_attack:
		failures.append("boss never exited the ATTACK state")

	# --- 3. Defeated without special-case code: lethal damage -> DEAD. ---
	boss_health.apply_damage(_lethal_event())
	if not await _wait_for_state(boss, boss.State.DEAD, 10):
		failures.append("boss did not die from lethal damage (state %s)" % boss.state)
	if deaths[0] != 1:
		failures.append("died signal emitted %d times (expected 1)" % deaths[0])

	# --- 4. The boss cannot attack while dead. ---
	await _wait(120)
	if boss.state != boss.State.DEAD:
		failures.append("boss left the DEAD state")
	if boss_hitbox.is_active():
		failures.append("dead boss hitbox was active")
	var taken_before_reset := player_taken.size()

	# --- 5. Clean reset: revives and resumes fighting. ---
	boss_health.reset()
	boss.reset()
	await _wait(5)
	if boss.state == boss.State.DEAD:
		failures.append("reset boss is still dead")
	if not is_equal_approx(float(boss_health.current_health), float(boss_health.max_health)):
		failures.append("reset boss health was not restored")
	var attacked_again := false
	for _i in 500:
		await physics_frame
		if player_taken.size() > taken_before_reset:
			attacked_again = true
			break
	if not attacked_again:
		failures.append("reset boss did not resume fighting")

	player_taken.clear()
	arena.free()

	if failures.is_empty():
		print("BOSS CHECK: PASS (approach %.1f->%.1f m, attack cycles, death, dead-idle, reset+resume)" % [
			start_dist, moved_dist,
		])
		quit(0)
	else:
		for failure in failures:
			printerr("BOSS CHECK FAILURE: " + failure)
		quit(1)

func _lethal_event() -> DamageEvent:
	var event := DamageEvent.new()
	event.amount = 99999.0
	return event

func _flat_dist(player, boss) -> float:
	var offset: Vector3 = boss.global_position - player.global_position
	offset.y = 0.0
	return offset.length()

func _wait_for_state(boss, target, max_frames: int) -> bool:
	for _i in max_frames:
		if boss.state == target:
			return true
		await physics_frame
	return false

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
