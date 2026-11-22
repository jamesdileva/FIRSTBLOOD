extends SceneTree
## Sprint 41 Hydra verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/hydra_check.gd
## Asserts the roadmap checklist — head/state changes affect combat
## behavior correctly: eight distinct roster entries; the Hydra's heads
## (3 × 35, the main 105); a head's damage drains BOTH the local gate and
## the main; killing a head disables its hurtbox (hits pass through) and
## scales the attack payload ×2/3; the regeneration restores the local
## gate and the hurtbox after 5 s; killing all three crosses the main to
## 0 → the natural DEFEAT. Exits 0 on PASS, 1 on FAIL.

const SETTLE_FRAMES := 30
const TITLE_SCENE := "res://game/scenes/ui/title_screen.tscn"
const REGEN_DELAY_TICKS := 330  # 5.5 s: the 5 s regen + margin

func _initialize() -> void:
	_run()

func _run() -> void:
	var failures: PackedStringArray = []
	OS.set_environment("FIRSTBLOOD_CHECK_SAVE", "1")
	var check_save := ProjectSettings.globalize_path("user://check_save.json")
	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)
	GearLibrary.reload_from_save()

	# --- A. The roster: eight distinct entries; the eighth is the Hydra. ---
	var roster := MatchSetup.roster()
	if roster == null or roster.entries.size() < 8:
		failures.append("the roster holds fewer than eight entries (%s)" % [
			roster.entries.size() if roster != null else -1,
		])
		quit(1)
		return
	var scenes: Array = []
	for entry in roster.entries:
		scenes.append(entry.scene)
	for i in scenes.size():
		for j in range(i + 1, scenes.size()):
			if scenes[i] == scenes[j]:
				failures.append("roster entries %d and %d share a scene" % [i, j])
	var hydra_scene: PackedScene = roster.entries[7].scene
	if hydra_scene == null:
		failures.append("the Hydra entry has no scene")
		quit(1)
		return
	var probe := hydra_scene.instantiate()
	var hydra_title: String = probe.boss_title
	probe.free()
	if hydra_title != "HYDRA":
		failures.append("the eighth boss is '%s', not the HYDRA" % hydra_title)

	# --- B. The real select path spawns the Hydra. ---
	MatchSetup.selected = null
	var title_scene: PackedScene = load(TITLE_SCENE)
	var title: Control = title_scene.instantiate()
	root.add_child(title)
	current_scene = title
	await _wait(5)
	title.start_fight()
	var select_ready := false
	var arena: Node = null
	for _i in 120:
		await physics_frame
		if current_scene != null and current_scene.name == "BossSelect":
			select_ready = true
			break
	if not select_ready:
		failures.append("start_fight did not reach the boss select screen")
	else:
		for _step in 7:
			Input.parse_input_event(_key(KEY_RIGHT, true))
			await _wait(2)
			Input.parse_input_event(_key(KEY_RIGHT, false))
			await _wait(2)
		Input.parse_input_event(_key(KEY_ENTER, true))
		await _wait(2)
		Input.parse_input_event(_key(KEY_ENTER, false))
		var arena_ready := false
		for _i in 120:
			await physics_frame
			if current_scene != null and current_scene.name == "Arena":
				arena_ready = true
				break
		if not arena_ready:
			failures.append("confirm did not reach the arena")
		else:
			arena = current_scene
	var boss = get_first_node_in_group("boss")
	var player = get_first_node_in_group("player")
	if boss == null or player == null:
		printerr("HYDRA CHECK FAILURE: the arena is missing actors")
		quit(1)
		return
	if boss.boss_title != "HYDRA":
		failures.append("the arena spawned '%s', not the HYDRA" % boss.boss_title)
	if not is_equal_approx(float(boss.get_node("Health").max_health), 105.0):
		failures.append("the Hydra's max health is %.0f (expected 105)" % float(boss.get_node("Health").max_health))
	if boss.alive_heads() != 3:
		failures.append("the Hydra spawned with %d alive heads (expected 3)" % boss.alive_heads())
	boss.movement_speed = 0.0  # park: the head tests are deterministic
	boss._cooldowns[&"hydra_bite"] = 999.0
	boss._cooldowns[&"hydra_double"] = 999.0
	var hurtboxes: Array = []
	for i in 3:
		hurtboxes.append(boss.get_node("Head%d/Hurtbox" % (i + 1)))

	# --- C. A head's damage drains BOTH the local gate and the main. ---
	var main_before := float(boss.get_node("Health").current_health)
	var hit := DamageEvent.new()
	hit.source = player
	hit.amount = 10.0
	hurtboxes[0].receive_damage(hit)
	if not is_equal_approx(float(boss.get_node("Health").current_health), main_before - 10.0):
		failures.append("a head hit did not drain the main health (%.1f -> %.1f)" % [
			main_before, float(boss.get_node("Health").current_health),
		])
	if not is_equal_approx(boss._head_hp[0], 25.0):
		failures.append("the head's local gate is %.1f (expected 25)" % boss._head_hp[0])

	# --- D. Killing a head: the hurtbox disables, the payload scales ×2/3. ---
	var kill := DamageEvent.new()
	kill.source = player
	kill.amount = 25.0
	hurtboxes[0].receive_damage(kill)
	if boss.alive_heads() != 2:
		failures.append("killing head 1 left %d alive (expected 2)" % boss.alive_heads())
	if hurtboxes[0].get_node("CollisionShape3D").disabled != true:
		failures.append("the dead head's hurtbox collision is still enabled")
	# hits on the dead head: nothing
	var after := float(boss.get_node("Health").current_health)
	hurtboxes[0].receive_damage(hit)
	if not is_equal_approx(float(boss.get_node("Health").current_health), after):
		failures.append("the dead head still took damage (%.1f -> %.1f)" % [
			after, float(boss.get_node("Health").current_health),
		])
	# the payload scales: the bite's 14 × 2/3
	boss._push_payload(boss.attacks[0])
	if not is_equal_approx(float(boss._attack_hitbox.damage), 14.0 * 2.0 / 3.0):
		failures.append("the payload scaling is wrong: %.1f (expected %.2f)" % [
			float(boss._attack_hitbox.damage), 14.0 * 2.0 / 3.0,
		])

	# --- E. The regeneration: the dead head revives after ~5 s. ---
	for _i in REGEN_DELAY_TICKS:
		if boss.alive_heads() == 3:
			break
		await physics_frame
	if boss.alive_heads() != 3:
		failures.append("the dead head never regenerated")
	elif not is_equal_approx(boss._head_hp[0], 35.0):
		failures.append("the regenerated head's gate is %.1f (expected 35)" % boss._head_hp[0])
	elif hurtboxes[0].get_node("CollisionShape3D").disabled:
		failures.append("the regenerated head's hurtbox stayed disabled")

	# --- F. Kill all three: the main crosses 0 → the natural DEFEAT. ---
	var match_flow = current_scene.get_node_or_null("MatchFlow")
	if match_flow == null:
		printerr("HYDRA CHECK FAILURE: MatchFlow missing")
		quit(1)
		return
	player_health_heal(boss.get_node("Health"), 999.0)
	# the head damage drains the main: each head's 35 + the earlier 35 = 140 total
	for i in 3:
		var lethal := DamageEvent.new()
		lethal.source = player
		lethal.amount = 40.0
		hurtboxes[i].receive_damage(lethal)
	if not boss.is_dead():
		failures.append("the Hydra did not die when all three heads fell (hp %.1f, state %s)" % [
			float(boss.get_node("Health").current_health), boss.State.keys()[boss.state],
		])
	else:
		var victory_seen := false
		for _i in 150:
			if match_flow.state == match_flow.MatchState.VICTORY:
				victory_seen = true
				break
			await physics_frame
		if not victory_seen:
			failures.append("the all-heads kill did not reach VICTORY")

	arena.free()
	MatchSetup.selected = null

	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)

	if failures.is_empty():
		print("HYDRA CHECK: PASS (roster, 3 heads drain local+main, kill disables+rescales, regen restores, all-heads natural defeat)")
		quit(0)
	else:
		for failure in failures:
			printerr("HYDRA CHECK FAILURE: " + failure)
		quit(1)

func player_health_heal(health, amount: float) -> void:
	health.heal(amount)

func _key(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = pressed
	return event

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
