extends SceneTree
## Sprint 20 automated level-stat verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/level_check.gd
## Asserts the roadmap checklist: leveling changes stats (movement, max HP,
## swing damage, attack-speed multiplier), stats persist (a fresh player
## instance with the saved level derives the same stats — no double-apply
## after scene reload), and the boss takes the boosted damage.
## Exits 0 on PASS, 1 on FAIL.

const SETTLE_FRAMES := 30

func _initialize() -> void:
	_run()

func _run() -> void:
	var failures: PackedStringArray = []
	# D-065 save isolation + a clean progression baseline.
	OS.set_environment("FIRSTBLOOD_CHECK_SAVE", "1")
	if FileAccess.file_exists("user://check_save.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://check_save.json"))
	var arena_scene: PackedScene = load("res://game/scenes/arena/arena.tscn")
	if arena_scene == null:
		printerr("LEVEL CHECK FAILURE: arena scene missing")
		quit(1)
		return
	var arena := arena_scene.instantiate()
	root.add_child(arena)
	await _wait(2)
	var player = get_first_node_in_group("player")
	var boss = get_first_node_in_group("boss")
	if player == null or boss == null:
		printerr("LEVEL CHECK FAILURE: player or boss not found")
		quit(1)
		return
	var progression = player.get_node("Progression")
	var boss_health = boss.get_node("Health")
	await _wait(SETTLE_FRAMES)

	# --- 1. Level 1: base stats. ---
	if not is_equal_approx(float(player.movement_speed), 5.0):
		failures.append("level 1 movement wrong: %.2f (expected 5.0)" % float(player.movement_speed))
	if not is_equal_approx(float(player.get_node("Health").max_health), 100.0):
		failures.append("level 1 max HP wrong: %.1f" % float(player.get_node("Health").max_health))
	if not is_equal_approx(float(player.attack_speed_multiplier), 1.0):
		failures.append("level 1 attack-speed multiplier wrong: %.3f" % float(player.attack_speed_multiplier))

	# --- 2. Level up to 3 (200 XP: 80 -> L2, 120 -> L3). ---
	progression.add_xp(200.0)
	await _wait(3)
	if progression.level != 3:
		failures.append("200 XP did not reach level 3 (level %d)" % progression.level)
	if not is_equal_approx(float(player.movement_speed), 5.3):  # 5.0 + 0.15 x 2
		failures.append("level 3 movement wrong: %.2f (expected 5.3)" % float(player.movement_speed))
	if not is_equal_approx(float(player.get_node("Health").max_health), 120.0):  # 100 + 10 x 2
		failures.append("level 3 max HP wrong: %.1f (expected 120)" % float(player.get_node("Health").max_health))
	if not is_equal_approx(float(player.attack_speed_multiplier), 1.08):  # 1 + 0.04 x 2
		failures.append("level 3 attack-speed multiplier wrong: %.3f (expected 1.08)" % float(player.attack_speed_multiplier))

	# --- 3. The swing payload carries the attack bonus (10 + 2 x 2 = 14). ---
	Input.action_press("attack")
	await _wait(2)
	Input.action_release("attack")
	await _wait(3)  # into the swing: the payload is pushed
	var hitbox_damage: float = float(player.get_node("AttackHitbox").damage)
	if hitbox_damage < 13.9 or hitbox_damage > 14.1:
		failures.append("level 3 light_01 damage wrong: %.1f (expected 14.0)" % hitbox_damage)
	Input.action_release("attack")
	await _wait(SETTLE_FRAMES)

	# --- 4. The boss takes the boosted damage from a landed swing. ---
	# The probe stands 1.4 m from the boss facing it (+X), guard cleared.
	player.global_position = boss.global_position + Vector3(-1.4, 0.5, 0)
	player.velocity = Vector3.ZERO
	player.rotation.y = -PI / 2.0
	await _wait(SETTLE_FRAMES)
	if boss.state == boss.State.GUARD:
		boss.state = boss.State.OBSERVE  # harness: unguard for a clean hit
	boss._cooldowns.clear()
	var boss_hp_before: float = float(boss.get_node("Health").current_health)
	player.get_node("AttackHitbox").set_active(true)
	await _wait(6)
	player.get_node("AttackHitbox").set_active(false)
	await _wait(3)
	var boss_hp_after: float = float(boss.get_node("Health").current_health)
	if not is_equal_approx(boss_hp_before - boss_hp_after, 14.0):
		failures.append("the boss took %.1f damage (expected the boosted 14.0)" % [
			boss_hp_before - boss_hp_after,
		])

	# --- 5. No double-apply after scene reload: a fresh player instance with
	# the saved level derives the same stats (a double-apply would give 5.6). ---
	player.reset_for_retry()
	var fresh_player: CharacterBody3D = (load("res://game/scenes/player/player.tscn") as PackedScene).instantiate()
	root.add_child(fresh_player)
	fresh_player.global_position = Vector3(-30.0, 0.5, -30.0)
	await _wait(3)
	if not is_equal_approx(float(fresh_player.movement_speed), 5.3):
		failures.append("fresh player movement wrong: %.2f (expected 5.3 — double-apply?)" % float(fresh_player.movement_speed))
	if not is_equal_approx(float(fresh_player.get_node("Health").max_health), 120.0):
		failures.append("fresh player max HP wrong: %.1f (expected 120 — double-apply?)" % float(fresh_player.get_node("Health").max_health))
	fresh_player.queue_free()
	await _wait(2)

	# --- 6. Persistence: the fresh instance's progression loaded the save. ---
	if progression.level != 3:
		failures.append("original progression level disturbed: %d" % progression.level)

	boss.get_node("Health").reset()
	player.get_node("Health").reset()
	arena.free()

	if failures.is_empty():
		print("LEVEL CHECK: PASS (L1 base, L3 stats 5.3/120/1.08/14, boss takes boosted damage, no double-apply)")
		quit(0)
	else:
		for failure in failures:
			printerr("LEVEL CHECK FAILURE: " + failure)
		quit(1)

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
