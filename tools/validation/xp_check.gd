extends SceneTree
## Sprint 19 automated XP verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/xp_check.gd
## Asserts the roadmap checklist with a clean save baseline:
##   damage dealt -> XP 1:1; victory bonus on boss death; level-up at the
##   threshold (with carry-over); defeat consolation on player death;
##   XP survives a restart (fresh component loads the save); XP never
##   negative; retry (boss reset) does not duplicate XP.
## Exits 0 on PASS, 1 on FAIL.

const SETTLE_FRAMES := 30
const SAVE_PATH := "user://save.json"

func _initialize() -> void:
	_run()

func _run() -> void:
	# D-065 save isolation: checks never touch the user's real save.
	OS.set_environment("FIRSTBLOOD_CHECK_SAVE", "1")
	if FileAccess.file_exists("user://check_save.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://check_save.json"))
	var failures: PackedStringArray = []
	# Clean baseline: XP persists in user://, so this check always starts fresh.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var arena_scene: PackedScene = load("res://game/scenes/arena/arena.tscn")
	if arena_scene == null:
		printerr("XP CHECK FAILURE: arena scene missing")
		quit(1)
		return
	var arena := arena_scene.instantiate()
	root.add_child(arena)
	await _wait(2)
	var player = get_first_node_in_group("player")
	var boss = get_first_node_in_group("boss")
	if player == null or boss == null:
		printerr("XP CHECK FAILURE: player or boss not found")
		quit(1)
		return
	var progression = player.get_node("Progression")
	var boss_health = boss.get_node("Health")
	var player_health = player.get_node("Health")
	await _wait(SETTLE_FRAMES)  # let the progression bind to the boss

	var level_ups := [0]
	progression.level_up.connect(func(new_level: int) -> void: level_ups[0] += 1)

	# --- 1. Damage dealt -> XP 1:1. ---
	boss_health.apply_damage(_event(20.0))
	await _wait(2)
	if not is_equal_approx(float(progression.total_earned), 20.0):
		failures.append("damage did not award XP 1:1 (total=%.1f)" % float(progression.total_earned))

	# --- 2. Negative XP is ignored. ---
	progression.add_xp(-50.0)
	if not is_equal_approx(float(progression.total_earned), 20.0):
		failures.append("negative XP was applied")

	# --- 3. Victory: lethal damage -> damage XP + victory bonus. ---
	boss_health.apply_damage(_lethal())
	await _wait(5)
	# 20 (damage) + 80 (lethal, clamped at the boss's remaining health) + 150 (victory)
	var expected_after_victory: float = 250.0
	if not is_equal_approx(float(progression.total_earned), expected_after_victory):
		failures.append("victory XP wrong: %.1f (expected %.1f)" % [float(progression.total_earned), expected_after_victory])
	if not boss.is_dead():
		failures.append("the boss did not die from lethal damage")

	# --- 4. Level-up at the threshold with carry-over (80 then 120). ---
	# 250 XP: level 2 at 80 (carry 170), level 3 at 120 (carry 50) -> level 3.
	if progression.level != 3:
		failures.append("level after 250 XP wrong: %d (expected 3)" % progression.level)
	if level_ups[0] < 2:
		failures.append("level_up signal fired %d times (expected >= 2)" % level_ups[0])

	# --- 5. XP survives restart: a fresh component loads the save. ---
	var fresh: Node = load("res://game/scripts/progression/progression_component.gd").new()
	fresh.name = "FreshProgression"
	root.add_child(fresh)
	await _wait(2)
	if not is_equal_approx(float(fresh.total_earned), float(progression.total_earned)):
		failures.append("fresh component did not load the saved XP (%.1f vs %.1f)" % [
			float(fresh.total_earned), float(progression.total_earned),
		])
	if fresh.level != progression.level:
		failures.append("fresh component did not load the saved level")
	fresh.queue_free()
	await _wait(2)

	# --- 6. Defeat consolation: the player dies -> XP. ---
	var xp_before_defeat: float = float(progression.total_earned)
	player_health.apply_damage(_lethal())
	await _wait(5)
	if not player.is_dead():
		failures.append("the player did not die from lethal damage")
	if float(progression.total_earned) != xp_before_defeat + 25.0:
		failures.append("defeat consolation wrong: %.1f (expected +25)" % float(progression.total_earned))

	# --- 7. Retry (full fight reset) does not duplicate or revoke XP. ---
	var xp_before_retry: float = float(progression.total_earned)
	player.reset_for_retry()
	boss.reset()
	await _wait(SETTLE_FRAMES)
	if float(progression.total_earned) != xp_before_retry:
		failures.append("retry changed XP (%.1f -> %.1f)" % [xp_before_retry, float(progression.total_earned)])
	if player.is_dead() or boss.is_dead():
		failures.append("retry left a side dead")

	player_health.reset()
	progression.reset_progression()  # fresh baseline for the run's end
	arena.free()

	if failures.is_empty():
		print("XP CHECK: PASS (damage 1:1, victory bonus, defeat consolation, level-up + carry-over, save/restart, retry clean)")
		quit(0)
	else:
		for failure in failures:
			printerr("XP CHECK FAILURE: " + failure)
		quit(1)

func _lethal() -> DamageEvent:
	var event := DamageEvent.new()
	event.amount = 1000.0
	return event

func _event(amount: float) -> DamageEvent:
	var event := DamageEvent.new()
	event.amount = amount
	return event

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
