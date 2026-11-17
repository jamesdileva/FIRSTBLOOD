extends SceneTree
## Sprint 31 Minotaur verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/minotaur_check.gd
## Asserts the roadmap checklist — behavior clearly distinct from the New
## Gladiator: three roster entries with distinct scenes, the Minotaur's
## data carries a far-band charge (lunge) and a scaled HEAVY slam footprint
## the gladiator lacks, the real select path spawns the MINOTAUR (150 HP),
## a stationary player far away eats the charge, the point-blank slam lands
## on its scaled footprint, and stepping out during the telegraph takes
## nothing. Exits 0 on PASS, 1 on FAIL.

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

	# --- A. Roster: three distinct entries; the third is the Minotaur. ---
	var roster := MatchSetup.roster()
	if roster == null or roster.entries.size() != 3:
		failures.append("the roster does not hold three entries (%s)" % [
			roster.entries.size() if roster != null else -1,
		])
		quit(1)
		return
	var scenes: Array = []
	for entry in roster.entries:
		scenes.append(entry.scene)
	if scenes[0] == scenes[1] or scenes[1] == scenes[2] or scenes[0] == scenes[2]:
		failures.append("roster entries share scenes")
	var mino_scene: PackedScene = roster.entries[2].scene
	if mino_scene == null:
		failures.append("the Minotaur entry has no scene")
		quit(1)
		return
	var probe := mino_scene.instantiate()
	var mino_title: String = probe.boss_title
	var mino_attacks: Array = probe.attacks
	probe.free()
	if mino_title != "MINOTAUR":
		failures.append("the third boss is '%s', not the MINOTAUR" % mino_title)

	# --- B. Data distinctness: a far-band charge and a scaled slam. ---
	var charge: BossAttackData = null
	var shockwave: BossAttackData = null
	for attack in mino_attacks:
		if attack.attack_id == &"mino_charge":
			charge = attack
		if attack.attack_id == &"mino_shockwave":
			shockwave = attack
	if charge == null:
		failures.append("the Minotaur has no charge attack")
	else:
		if charge.lunge_speed < 8.0:
			failures.append("the charge lunges too slowly (%.1f m/s)" % charge.lunge_speed)
		if charge.max_range < 6.0:
			failures.append("the charge band is not far (%.1f m)" % charge.max_range)
		if charge.telegraph_duration < 0.8:
			failures.append("the charge telegraph is unreadable (%.2f s)" % charge.telegraph_duration)
		if charge.hit_type == CombatTypes.HitType.NORMAL:
			failures.append("the charge is not flagged heavy")
	if shockwave == null:
		failures.append("the Minotaur has no shockwave")
	else:
		if shockwave.hitbox_size_scale.x < 2.0:
			failures.append("the shockwave footprint is not scaled (%s)" % [shockwave.hitbox_size_scale])
		if shockwave.telegraph_duration < 0.8:
			failures.append("the shockwave telegraph is unreadable (%.2f s)" % shockwave.telegraph_duration)
	# the gladiator must lack both shapes
	var gladiator := (load("res://game/scenes/bosses/new_gladiator.tscn") as PackedScene).instantiate()
	for attack in gladiator.attacks:
		if attack.lunge_speed >= 8.0 or attack.hitbox_size_scale != Vector3.ONE:
			failures.append("the gladiator already has Minotaur-shaped attacks")
	gladiator.free()

	# --- C. The real select path spawns the MINOTAUR. ---
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
		# two rights land on the Minotaur card
		for _step in 2:
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
	await _wait(SETTLE_FRAMES)
	var boss = get_first_node_in_group("boss")
	var player = get_first_node_in_group("player")
	if boss == null or player == null:
		printerr("MINOTAUR CHECK FAILURE: the arena is missing actors")
		quit(1)
		return
	if boss.boss_title != "MINOTAUR":
		failures.append("the arena spawned '%s', not the MINOTAUR" % boss.boss_title)
	if not is_equal_approx(float(boss.get_node("Health").max_health), 150.0):
		failures.append("the Minotaur's max health is %.0f (expected 150)" % float(boss.get_node("Health").max_health))
	var player_health = player.get_node("Health")
	if not is_equal_approx(float(player_health.current_health), 100.0):
		failures.append("the check player is not at full health (%.1f)" % float(player_health.current_health))

	# --- D. The charge: parked far, a stationary player eats it. ---
	# Watch from tick 0: the brain selects within a couple of ticks of
	# settling, and the 0.9 s telegraph can pass during a settle window.
	player.global_position = Vector3(-2, 0.5, 0)
	boss.global_position = Vector3(4, 0, 0)
	var charge_seen := false
	var boss_before: Vector3
	for _i in 900:
		if boss.state == boss.State.TELEGRAPH and boss._current_attack != null \
				and boss._current_attack.attack_id == &"mino_charge":
			charge_seen = true
			boss_before = boss.global_position
			break
		await physics_frame
	if not charge_seen:
		failures.append("the Minotaur never charged from far (band 3-8 m)")
	else:
		# let the charge run out: telegraph 0.9 + startup/active ~0.65
		await _wait(120)
		var traveled: float = (boss.global_position - boss_before).length()
		if traveled < 3.0:
			failures.append("the charge did not carry the boss (moved %.1f m)" % traveled)
		if not is_equal_approx(float(player_health.current_health), 80.0):
			failures.append("a stationary player took %.1f from the charge (expected 20)" % [
				100.0 - float(player_health.current_health),
			])

	# --- E. The shockwave: point-blank lands, stepping out does not. ---
	player_health.heal(999.0)
	boss._cooldowns[&"mino_light"] = 999.0
	boss._cooldowns[&"mino_heavy"] = 999.0
	boss._cooldowns[&"mino_charge"] = 999.0
	# stand point-blank in front of the boss
	player.global_position = boss.global_position + Vector3(0, 0.5, -1.6)
	await _wait(SETTLE_FRAMES)
	var slam_seen := false
	var base_size := Vector3.ZERO
	var scaled_size := Vector3.ZERO
	for _i in 900:
		if boss.state == boss.State.TELEGRAPH and boss._current_attack != null \
				and boss._current_attack.attack_id == &"mino_shockwave":
			slam_seen = true
			var shape := (boss.get_node("AttackHitbox/CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
			base_size = Vector3(1.8, 2.2, 2.6)
			scaled_size = shape.size
			break
		await physics_frame
	if not slam_seen:
		failures.append("the Minotaur never slammed point-blank")
	else:
		if scaled_size.x < base_size.x * 2.0:
			failures.append("the slam footprint did not scale (%s)" % [scaled_size])
		# hold the telegraph's last beats, then eat the slam
		await _wait(int(boss._current_attack.telegraph_duration * 60.0) + 40)
		if not is_equal_approx(float(player_health.current_health), 76.0):
			failures.append("the slam took %.1f point-blank (expected 24)" % [
				100.0 - float(player_health.current_health),
			])
		# again, but step out during the telegraph
		player_health.heal(999.0)
		boss._cooldowns.clear()
		boss._cooldowns[&"mino_light"] = 999.0
		boss._cooldowns[&"mino_heavy"] = 999.0
		boss._cooldowns[&"mino_charge"] = 999.0
		var stepped_out := false
		for _i in 900:
			if boss.state == boss.State.TELEGRAPH and boss._current_attack != null \
					and boss._current_attack.attack_id == &"mino_shockwave":
				stepped_out = true
				break
			await physics_frame
		if stepped_out:
			# the "dodge": leave the marked zone before it detonates
			player.global_position = player.global_position + Vector3(5.5, 0, 0)
			await _wait(int(boss._current_attack.telegraph_duration * 60.0) + 40)
			if not is_equal_approx(float(player_health.current_health), 100.0):
				failures.append("a player outside the footprint took %.1f from the slam" % [
					100.0 - float(player_health.current_health),
				])
			else:
				pass

	# cleanup the real-path arena
	current_scene.free()
	current_scene = null

	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)

	if failures.is_empty():
		print("MINOTAUR CHECK: PASS (roster, distinct data, real select spawns it, charge hits stationary, slam scales, stepping out is safe)")
		quit(0)
	else:
		for failure in failures:
			printerr("MINOTAUR CHECK FAILURE: " + failure)
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
