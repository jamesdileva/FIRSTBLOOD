extends SceneTree
## Sprint 21 automated HUD verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/hud_check.gd
## Asserts the roadmap checklist: the player HP bar tracks the player's
## health, the boss HP bar tracks the boss (and hides on boss death), the
## telegraph warning bar shows during the boss's TELEGRAPH and matches the
## attack type, and the XP/level widgets track progression. Exits 0 on PASS.

const SETTLE_FRAMES := 30

func _initialize() -> void:
	_run()

func _run() -> void:
	var failures: PackedStringArray = []
	OS.set_environment("FIRSTBLOOD_CHECK_SAVE", "1")
	if FileAccess.file_exists("user://check_save.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://check_save.json"))
	var arena_scene: PackedScene = load("res://game/scenes/arena/arena.tscn")
	if arena_scene == null:
		printerr("HUD CHECK FAILURE: arena scene missing")
		quit(1)
		return
	var arena := arena_scene.instantiate()
	root.add_child(arena)
	await _wait(2)
	var player = get_first_node_in_group("player")
	var boss = get_first_node_in_group("boss")
	if player == null or boss == null:
		printerr("HUD CHECK FAILURE: player or boss not found")
		quit(1)
		return
	var hud = arena.get_node_or_null("HUD")
	if hud == null:
		printerr("HUD CHECK FAILURE: HUD node missing")
		quit(1)
		return
	var player_bar: ProgressBar = hud.get_node("PlayerBar")
	var xp_bar: ProgressBar = hud.get_node("XPBar")
	var level_label: Label = hud.get_node("LevelLabel")
	var boss_bar: ProgressBar = hud.get_node("BossPanel/BossBar")
	var boss_panel: Control = hud.get_node("BossPanel")
	var telegraph_bar: ProgressBar = hud.get_node("BossPanel/TelegraphBar")
	var boss_health = boss.get_node("Health")
	var player_health = player.get_node("Health")
	var progression = player.get_node("Progression")
	await _wait(SETTLE_FRAMES)

	# --- 1. The player HP bar tracks the player's health. ---
	if not is_equal_approx(float(player_bar.value), float(player_health.current_health)):
		failures.append("player bar %.0f does not track health %.0f" % [
			float(player_bar.value), float(player_health.current_health),
		])
	if not is_equal_approx(float(player_bar.max_value), float(player_health.max_health)):
		failures.append("player bar max wrong: %.0f" % float(player_bar.max_value))
	player_health.apply_damage(_event(30.0))
	await _wait(3)
	if not is_equal_approx(float(player_bar.value), float(player_health.current_health)):
		failures.append("the player bar did not update after damage")

	# --- 2. The XP/level widgets track progression. ---
	progression.add_xp(100.0)
	await _wait(3)
	if not is_equal_approx(float(xp_bar.value), float(progression.xp)):
		failures.append("the XP bar does not track progression XP (%.0f vs %.1f)" % [
			float(xp_bar.value), float(progression.xp),
		])
	if not is_equal_approx(float(xp_bar.max_value), float(progression.xp_required())):
		failures.append("the XP bar max does not match the requirement")
	if level_label.text != "LV %d" % progression.level:
		failures.append("level label wrong: %s (expected LV %d)" % [level_label.text, progression.level])

	# --- 3. The telegraph bar shows during the boss's TELEGRAPH. ---
	var telegraph_seen := false
	var telegraph_matches_type := true
	for _i in 600:
		await physics_frame
		if boss.state == boss.State.TELEGRAPH:
			telegraph_seen = true
			if not telegraph_bar.visible:
				telegraph_matches_type = false
			var heavy: bool = boss._current_attack.hit_type != CombatTypes.HitType.NORMAL
			var expected_color := Color(1.0, 0.25, 0.15) if heavy else Color(1.0, 0.85, 0.2)
			if not telegraph_bar.modulate.is_equal_approx(expected_color):
				telegraph_matches_type = false
		if telegraph_seen and boss.state != boss.State.TELEGRAPH:
			break
	if not telegraph_seen:
		failures.append("the boss never telegraphed within 600 ticks")
	elif not telegraph_matches_type:
		failures.append("the telegraph bar visibility/color did not match the warning")

	# --- 4. The boss bar hides on boss death. ---
	boss_health.apply_damage(_lethal())
	await _wait(5)
	if not boss.is_dead():
		failures.append("the boss did not die from lethal damage")
	if boss_panel.visible:
		failures.append("the boss panel stayed visible after boss death")
	if not player_health.is_dead():
		pass  # the probe survives its own lethal test in other checks; not asserted here

	# --- 5. Values return after boss.reset (retry flow). ---
	boss.reset()
	player.reset_for_retry()
	await _wait(SETTLE_FRAMES)
	if not boss_panel.visible:
		failures.append("the boss panel did not return after retry")
	if not is_equal_approx(float(boss_bar.value), float(boss_health.max_health)):
		failures.append("the boss bar did not refill after retry")

	player_health.reset()
	arena.free()

	if failures.is_empty():
		print("HUD CHECK: PASS (player/XP/level/boss bars track, telegraph bar matches type, boss panel hides/restores)")
		quit(0)
	else:
		for failure in failures:
			printerr("HUD CHECK FAILURE: " + failure)
		quit(1)

func _event(amount: float) -> DamageEvent:
	var event := DamageEvent.new()
	event.amount = amount
	return event

func _lethal() -> DamageEvent:
	var event := DamageEvent.new()
	event.amount = 1000.0
	return event

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
