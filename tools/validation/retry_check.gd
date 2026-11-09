extends SceneTree
## Sprint 16 automated retry-universality verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/retry_check.gd
## The playtest caught that retry only existed in the player's death branch
## (D-059). Asserts BOTH playtest cases now reset the fight:
##   A: the player dies -> R -> both sides reset to spawn;
##   B: the boss dies  -> R -> both sides reset to spawn.
## Exits 0 on PASS, 1 on FAIL.

const SETTLE_FRAMES := 30

func _initialize() -> void:
	_run()

func _run() -> void:
	var failures: PackedStringArray = []
	var arena_scene: PackedScene = load("res://game/scenes/arena/arena.tscn")
	if arena_scene == null:
		printerr("RETRY CHECK FAILURE: arena scene missing")
		quit(1)
		return
	var arena := arena_scene.instantiate()
	root.add_child(arena)
	await _wait(2)
	var player = get_first_node_in_group("player")
	var boss = get_first_node_in_group("boss")
	if player == null or boss == null:
		printerr("RETRY CHECK FAILURE: player or boss not found")
		quit(1)
		return
	var player_spawn: Vector3 = player.global_position
	var boss_spawn: Vector3 = boss.global_position
	var player_health = player.get_node("Health")
	var boss_health = boss.get_node("Health")

	# --- A: the player dies -> R resets both sides. ---
	player.global_position = Vector3(2.6, 0.5, 0.0)
	player_health.apply_damage(_lethal())
	await _wait(5)
	if not player.is_dead():
		failures.append("case A: the player did not die from lethal damage")
	var key := _retry_key(true)
	Input.parse_input_event(key)
	await _wait(2)
	Input.parse_input_event(_retry_key(false))
	await _wait(3)  # measure immediately: a live boss walks toward the player
	if player.is_dead():
		failures.append("case A: retry did not revive the player")
	if player_health.is_dead():
		failures.append("case A: player health not restored")
	var player_back: float = (player.global_position - player_spawn).length()
	if player_back > 1.0:
		failures.append("case A: the player was not returned to spawn (%.2f m off)" % player_back)
	var boss_back: float = (boss.global_position - boss_spawn).length()
	if boss_back > 1.0:
		failures.append("case A: the boss was not returned to spawn (%.2f m off)" % boss_back)
	if not is_equal_approx(float(boss_health.current_health), float(boss_health.max_health)):
		failures.append("case A: boss health not restored")

	# --- B: the boss dies -> R resets both sides. ---
	boss_health.apply_damage(_lethal())
	await _wait(5)
	if not boss.is_dead():
		failures.append("case B: the boss did not die from lethal damage")
	var key2 := _retry_key(true)
	Input.parse_input_event(key2)
	await _wait(2)
	Input.parse_input_event(_retry_key(false))
	await _wait(3)
	if boss.is_dead():
		failures.append("case B: retry did not revive the boss")
	if not is_equal_approx(float(boss_health.current_health), float(boss_health.max_health)):
		failures.append("case B: boss health not restored")
	if player.is_dead():
		failures.append("case B: the living player was killed by retry")
	var boss_back2: float = (boss.global_position - boss_spawn).length()
	if boss_back2 > 1.0:
		failures.append("case B: the boss was not returned to spawn (%.2f m off)" % boss_back2)

	# --- C: a stray R mid-fight does NOT reset an ongoing duel (D-059 arming) ---
	player.global_position = Vector3(2.6, 0.5, 0.0)
	await _wait(SETTLE_FRAMES)
	boss_health.apply_damage(_event(20.0))
	var hp_before: float = float(boss_health.current_health)
	var key3 := _retry_key(true)
	Input.parse_input_event(key3)
	await _wait(2)
	Input.parse_input_event(_retry_key(false))
	await _wait(SETTLE_FRAMES)
	if float(boss_health.current_health) != hp_before:
		failures.append("a stray R mid-fight reset the fight (D-059 arming violated)")
	if player.is_dead() or boss.is_dead():
		failures.append("a stray R mid-fight killed a side")

	player_health.reset()
	arena.free()

	if failures.is_empty():
		print("RETRY CHECK: PASS (player-death retry, boss-death retry, stray R armed out)")
		quit(0)
	else:
		for failure in failures:
			printerr("RETRY CHECK FAILURE: " + failure)
		quit(1)

func _lethal() -> DamageEvent:
	var event := DamageEvent.new()
	event.amount = 1000.0
	return event

func _event(amount: float) -> DamageEvent:
	var event := DamageEvent.new()
	event.amount = amount
	return event

func _retry_key(pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = 82
	event.keycode = 82
	event.pressed = pressed
	return event

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
