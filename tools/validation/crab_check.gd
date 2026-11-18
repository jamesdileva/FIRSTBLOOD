extends SceneTree
## Sprint 34 Giant Crab verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/crab_check.gd
## Asserts the roadmap checklist — positioning and punish timing differ
## from other bosses: six distinct roster entries, the crab's data carries
## armor, wide sweep footprints, a followup string, and short recoveries;
## behavior in the arena: the real select path spawns the GIANT CRAB (130
## HP, armor 3), a strike lands soaked (15 -> 12), the shell cracks during
## the stagger (the next strike lands FULL) and re-hardens after, and the
## sweep's scaled footprint lands its 12 point-blank. Exits 0 on PASS, 1
## on FAIL.

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

	# --- A. Roster: six distinct entries; the sixth is the Giant Crab. ---
	var roster := MatchSetup.roster()
	if roster == null or roster.entries.size() < 6:
		failures.append("the roster holds fewer than six entries (%s)" % [
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
	var crab_scene: PackedScene = roster.entries[5].scene
	if crab_scene == null:
		failures.append("the Giant Crab entry has no scene")
		quit(1)
		return
	var probe := crab_scene.instantiate()
	var crab_title: String = probe.boss_title
	var crab_armor: float = probe.armor
	var crab_attacks: Array = probe.attacks
	probe.free()
	if crab_title != "GIANT CRAB":
		failures.append("the sixth boss is '%s', not the GIANT CRAB" % crab_title)
	if not is_equal_approx(crab_armor, 3.0):
		failures.append("the crab's armor is %.1f (expected 3)" % crab_armor)

	# --- B. Data distinctness: wide sweeps, a string, short openings. ---
	var sweep_1: BossAttackData = null
	var snap: BossAttackData = null
	for attack in crab_attacks:
		if attack.attack_id == &"crab_sweep_1":
			sweep_1 = attack
		if attack.attack_id == &"crab_snap":
			snap = attack
	if sweep_1 == null:
		failures.append("the crab has no claw sweep")
	else:
		if sweep_1.hitbox_size_scale.x < 1.8:
			failures.append("the sweep footprint is not wide (%s)" % [sweep_1.hitbox_size_scale])
		if sweep_1.followup != &"crab_sweep_2":
			failures.append("the sweep does not chain into a second sweep")
		if sweep_1.recovery > 0.4:
			failures.append("the sweep's opening is not short (%.2f s)" % sweep_1.recovery)
	if snap == null:
		failures.append("the crab has no snap")
	else:
		if snap.telegraph_duration > 0.4:
			failures.append("the snap telegraph is not short (%.2f s)" % snap.telegraph_duration)
	# the gladiator must have no armor (the export defaults to 0)
	var gladiator := (load("res://game/scenes/bosses/new_gladiator.tscn") as PackedScene).instantiate()
	if not is_equal_approx(float(gladiator.armor), 0.0):
		failures.append("the gladiator gained armor it should not have")
	gladiator.free()

	# --- C. The real select path spawns the GIANT CRAB. ---
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
		for _step in 5:
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
		printerr("CRAB CHECK FAILURE: the arena is missing actors")
		quit(1)
		return
	if boss.boss_title != "GIANT CRAB":
		failures.append("the arena spawned '%s', not the GIANT CRAB" % boss.boss_title)
	if not is_equal_approx(float(boss.get_node("Health").max_health), 130.0):
		failures.append("the crab's max health is %.0f (expected 130)" % float(boss.get_node("Health").max_health))
	var player_health = player.get_node("Health")

	# --- D. The shell: a strike lands soaked; it cracks during the stagger. ---
	boss.movement_speed = 0.0  # park: the shell tests are deterministic
	player.global_position = boss.global_position + Vector3(0, 0.5, -1.8)
	var shell_hp := float(boss.get_node("Health").current_health)
	var soaked := DamageEvent.new()
	soaked.source = player
	soaked.amount = 15.0
	boss._resolve_incoming_damage(soaked)
	var soak_taken := shell_hp - float(boss.get_node("Health").current_health)
	if not is_equal_approx(soak_taken, 12.0):
		failures.append("the shell soak is wrong: a 15 strike took %.1f (expected 12)" % soak_taken)
	# crack it: a stagger-heavy strike triggers the punish window
	var crack := DamageEvent.new()
	crack.source = player
	crack.amount = 5.0
	crack.stagger_damage = 25.0
	boss._resolve_incoming_damage(crack)
	if boss.state != boss.State.STAGGERED:
		failures.append("the stagger-heavy strike did not crack the shell (state %s)" % [
			boss.State.keys()[boss.state],
		])
	else:
		var cracked_hp := float(boss.get_node("Health").current_health)
		var full := DamageEvent.new()
		full.source = player
		full.amount = 15.0
		boss._resolve_incoming_damage(full)
		var full_taken := cracked_hp - float(boss.get_node("Health").current_health)
		if not is_equal_approx(full_taken, 15.0):
			failures.append("the cracked shell still soaked: a 15 strike took %.1f (expected 15)" % full_taken)
		# let the window close, then the shell re-hardens
		for _i in 220:
			await physics_frame
			if boss.state != boss.State.STAGGERED:
				break
		if boss.state == boss.State.STAGGERED:
			failures.append("the stagger never ended")
		else:
			var re_hp := float(boss.get_node("Health").current_health)
			var re_soak := DamageEvent.new()
			re_soak.source = player
			re_soak.amount = 10.0
			boss._resolve_incoming_damage(re_soak)
			var re_taken := re_hp - float(boss.get_node("Health").current_health)
			if not is_equal_approx(re_taken, 7.0):
				failures.append("the shell did not re-harden: a 10 strike took %.1f (expected 7)" % re_taken)

	# --- E. The sweep: a scaled footprint lands point-blank. ---
	player_health.heal(999.0)
	for _i in 120:
		if boss.state == boss.State.OBSERVE and boss._current_attack == null:
			break
		await physics_frame
	boss._cooldowns.clear()
	boss._cooldowns[&"crab_snap"] = 999.0
	player.global_position = boss.global_position + Vector3(0, 0.5, -1.8)
	var sweep_seen := false
	var scaled_size := Vector3.ZERO
	for _i in 900:
		if boss.state == boss.State.TELEGRAPH and boss._current_attack != null \
				and boss._current_attack.attack_id == &"crab_sweep_1":
			sweep_seen = true
			var shape := (boss.get_node("AttackHitbox/CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
			scaled_size = shape.size
			break
		await physics_frame
	if not sweep_seen:
		failures.append("the crab never swept point-blank")
	else:
		if scaled_size.x < 1.8 * 1.9 - 0.01:
			failures.append("the sweep footprint did not scale (%s)" % [scaled_size])
		await _wait(int(boss._current_attack.telegraph_duration * 60.0) + 60)
		if not is_equal_approx(float(player_health.current_health), 88.0):
			failures.append("the sweep took %.1f point-blank (expected 12)" % [
				100.0 - float(player_health.current_health),
			])

	# cleanup the real-path arena
	current_scene.free()
	current_scene = null

	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)

	if failures.is_empty():
		print("CRAB CHECK: PASS (roster, armored soak 15->12, shell cracks on stagger, re-hardens, scaled sweep lands)")
		quit(0)
	else:
		for failure in failures:
			printerr("CRAB CHECK FAILURE: " + failure)
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
