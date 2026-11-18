extends SceneTree
## Sprint 33 Giant Spider verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/spider_check.gd
## Asserts the roadmap checklist — mobility and status pressure create a
## distinct encounter: five distinct roster entries, the spider's data
## carries a web-status projectile, a poison-status bite, and a pounce
## lunge; behavior in the arena: the web bolt lands and the player's speed
## visibly halves (then recovers), the venom bite poisons (honest HP ticks,
## then clears), and the pounce crosses its band into a stationary player.
## The watches start at tick 0 — the spider's brain selects within ticks of
## settling (the Sprint 31 lesson), so a settle window swallows the first
## telegraph. Exits 0 on PASS, 1 on FAIL.

const SETTLE_FRAMES := 30
const TITLE_SCENE := "res://game/scenes/ui/title_screen.tscn"

func _initialize() -> void:
	_run()

func _run() -> void:
	var failures: PackedStringArray = []
	OS.set_environment("FIRSTBLOOD_CHECK_SAVE", "1")
	var check_save := ProjectSettings.globalize_path("user://check_save.json")
	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)

	# --- A. Roster: five distinct entries; the fifth is the Giant Spider. ---
	var roster := MatchSetup.roster()
	if roster == null or roster.entries.size() < 5:
		failures.append("the roster holds fewer than five entries (%s)" % [
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
	var spider_scene: PackedScene = roster.entries[4].scene
	if spider_scene == null:
		failures.append("the Giant Spider entry has no scene")
		quit(1)
		return
	var probe := spider_scene.instantiate()
	var spider_title: String = probe.boss_title
	var spider_attacks: Array = probe.attacks
	probe.free()
	if spider_title != "GIANT SPIDER":
		failures.append("the fifth boss is '%s', not the GIANT SPIDER" % spider_title)

	# --- B. Data distinctness: web / venom / pounce. ---
	var web: BossAttackData = null
	var venom: BossAttackData = null
	var pounce: BossAttackData = null
	for attack in spider_attacks:
		if attack.attack_id == &"spider_web":
			web = attack
		if attack.attack_id == &"spider_venom":
			venom = attack
		if attack.attack_id == &"spider_pounce":
			pounce = attack
	if web == null:
		failures.append("the spider has no web spit")
	else:
		if web.attack_shape != &"projectile":
			failures.append("the web is not projectile-shaped (%s)" % web.attack_shape)
		if web.status_effect != &"web":
			failures.append("the web carries no web status (%s)" % web.status_effect)
	if venom == null:
		failures.append("the spider has no venom bite")
	else:
		if venom.status_effect != &"poison":
			failures.append("the venom carries no poison status (%s)" % venom.status_effect)
	if pounce == null:
		failures.append("the spider has no pounce")
	else:
		if pounce.lunge_speed < 7.0:
			failures.append("the pounce lunges too slowly (%.1f m/s)" % pounce.lunge_speed)
		if pounce.max_range < 5.0:
			failures.append("the pounce band is not mid-range (%.1f m)" % pounce.max_range)

	# --- C. The real select path spawns the GIANT SPIDER. ---
	MatchSetup.selected = null
	var title_scene: PackedScene = load(TITLE_SCENE)
	var title: Control = title_scene.instantiate()
	root.add_child(title)
	current_scene = title
	await _wait(5)
	title.start_fight()
	var select_ready := false
	for _i in 120:
		await physics_frame
		if current_scene != null and current_scene.name == "BossSelect":
			select_ready = true
			break
	if not select_ready:
		failures.append("start_fight did not reach the boss select screen")
	else:
		for _step in 4:
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
	var boss = get_first_node_in_group("boss")
	var player = get_first_node_in_group("player")
	if boss == null or player == null:
		printerr("SPIDER CHECK FAILURE: the arena is missing actors")
		quit(1)
		return
	if boss.boss_title != "GIANT SPIDER":
		failures.append("the arena spawned '%s', not the GIANT SPIDER" % boss.boss_title)
	if not is_equal_approx(float(boss.get_node("Health").max_health), 110.0):
		failures.append("the spider's max health is %.0f (expected 110)" % float(boss.get_node("Health").max_health))
	var player_health = player.get_node("Health")

	# --- D. The web: parked far from tick 0, the bolt lands and the player
	# slows (the first telegraph fires within ticks of the arena loading —
	# no settle, or the watch misses it). ---
	boss.movement_speed = 0.0  # park: pure status pressure, no chase
	boss._cooldowns[&"spider_venom"] = 999.0
	boss._cooldowns[&"spider_pounce"] = 999.0
	player.global_position = Vector3(-2, 0.5, 0)
	boss.global_position = Vector3(4, 0, 0)
	var web_seen := false
	for _i in 900:
		if boss.state == boss.State.TELEGRAPH and boss._current_attack != null \
				and boss._current_attack.attack_id == &"spider_web":
			web_seen = true
			break
		await physics_frame
	if not web_seen:
		failures.append("the spider never webbed from range")
	else:
		var hit_seen := false
		for _i in 180:
			if not is_equal_approx(float(player_health.current_health), 100.0):
				hit_seen = true
				break
			await physics_frame
		if not hit_seen:
			failures.append("the web bolt never reached a stationary player")
		elif not is_equal_approx(float(player_health.current_health), 94.0):
			failures.append("the web bolt took %.1f (expected 6)" % [
				100.0 - float(player_health.current_health),
			])
		if not player.web_active():
			failures.append("the web did not slow the player")
		elif not is_equal_approx(float(player.effective_speed()), float(player.movement_speed) * 0.4):
			failures.append("the web slow is wrong (%.2f of full speed)" % [
				float(player.effective_speed()) / float(player.movement_speed),
			])
		for _i in 200:
			if not player.web_active():
				break
			await physics_frame
		if player.web_active():
			failures.append("the web never expired")
		elif not is_equal_approx(float(player.effective_speed()), float(player.movement_speed)):
			failures.append("the player's speed did not recover (%.1f)" % float(player.effective_speed()))

	# --- E. The venom: a clean bite poisons, the ticks drain, then it ends. ---
	player_health.heal(999.0)
	for _i in 120:
		if boss.state == boss.State.OBSERVE and boss._current_attack == null:
			break
		await physics_frame
	boss._cooldowns.clear()  # D's 999 pokes would otherwise lock the bite out
	boss._cooldowns[&"spider_web"] = 999.0
	boss._cooldowns[&"spider_pounce"] = 999.0
	# stand in the bite band (1.0-2.0 m), outside the web (3-8) and pounce (2.5-6) bands
	player.global_position = boss.global_position + Vector3(0, 0.5, -1.5)
	var bite_seen := false
	for _i in 900:
		if boss.state == boss.State.TELEGRAPH and boss._current_attack != null \
				and boss._current_attack.attack_id == &"spider_venom":
			bite_seen = true
			break
		await physics_frame
	if not bite_seen:
		failures.append("the spider never bit point-blank")
	else:
		await _wait(int(boss._current_attack.telegraph_duration * 60.0) + 60)
		if not player.poison_active():
			failures.append("the venom did not poison the player")
		var bite_damage := 100.0 - float(player_health.current_health)
		if bite_damage < 10.0:
			failures.append("the bite took only %.1f (expected at least 10)" % bite_damage)
		var post_bite_hp := float(player_health.current_health)
		boss._cooldowns[&"spider_venom"] = 999.0  # no second bite mid-drain
		for _i in 320:
			if not player.poison_active():
				break
			await physics_frame
		if player.poison_active():
			failures.append("the poison never expired")
		var drained := post_bite_hp - float(player_health.current_health)
		if drained < 18.0:
			failures.append("the poison ticks drained only %.1f (expected 24 over 4 s)" % drained)

	# --- F. The pounce: parked mid-band from tick 0, a stationary player
	# eats it. ---
	player_health.heal(999.0)
	for _i in 120:
		if boss.state == boss.State.OBSERVE and boss._current_attack == null:
			break
		await physics_frame
	boss._cooldowns.clear()  # D's pokes would otherwise lock the pounce out
	boss._cooldowns[&"spider_web"] = 999.0
	boss._cooldowns[&"spider_venom"] = 999.0
	# 4.5 m: inside the pounce band, and the 2.8 m lunge + 2.2 m hitbox
	# reach actually connects (at the 6 m band edge it falls just short)
	player.global_position = Vector3(-0.5, 0.5, 0)
	boss.global_position = Vector3(4, 0, 0)
	var pounce_seen := false
	var boss_before: Vector3
	for _i in 900:
		if boss.state == boss.State.TELEGRAPH and boss._current_attack != null \
				and boss._current_attack.attack_id == &"spider_pounce":
			pounce_seen = true
			boss_before = boss.global_position
			break
		await physics_frame
	if not pounce_seen:
		failures.append("the spider never pounced from mid-band")
	else:
		await _wait(int(boss._current_attack.telegraph_duration * 60.0) + 80)
		var traveled: float = (boss.global_position - boss_before).length()
		if traveled < 2.5:
			failures.append("the pounce did not carry the spider (moved %.1f m)" % traveled)
		if not is_equal_approx(float(player_health.current_health), 86.0):
			failures.append("a stationary player took %.1f from the pounce (expected 14)" % [
				100.0 - float(player_health.current_health),
			])

	# cleanup the real-path arena
	current_scene.free()
	current_scene = null

	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)

	if failures.is_empty():
		print("SPIDER CHECK: PASS (roster, distinct data, web slows + recovers, venom poisons + drains + clears, pounce crosses)")
		quit(0)
	else:
		for failure in failures:
			printerr("SPIDER CHECK FAILURE: " + failure)
		quit(1)

func _key(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = pressed
	return event

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
