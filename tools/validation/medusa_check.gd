extends SceneTree
## Sprint 32 Medusa verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/medusa_check.gd
## Asserts the roadmap checklist — the player must adapt to facing/range
## and telegraph differences: four distinct roster entries, the Medusa's
## data carries a projectile-shaped ranged spit, a petrify-status gaze, and
## a mirror shield; behavior in the arena: parked far, the spit's bolt
## crosses and lands (ranged pressure); the gaze's hit petrifies the player
## (rooted + tint, clears on timeout); with the mirror forced, damage to
## the boss is negated and returned to the player, and lands normally after
## expiry. Exits 0 on PASS, 1 on FAIL.

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

	# --- A. Roster: four distinct entries; the fourth is the Medusa. ---
	var roster := MatchSetup.roster()
	if roster == null or roster.entries.size() != 4:
		failures.append("the roster does not hold four entries (%s)" % [
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
	var med_scene: PackedScene = roster.entries[3].scene
	if med_scene == null:
		failures.append("the Medusa entry has no scene")
		quit(1)
		return
	var probe := med_scene.instantiate()
	var med_title: String = probe.boss_title
	var med_attacks: Array = probe.attacks
	probe.free()
	if med_title != "MEDUSA":
		failures.append("the fourth boss is '%s', not the MEDUSA" % med_title)

	# --- B. Data distinctness: spit / gaze / mirror. ---
	var spit: BossAttackData = null
	var gaze: BossAttackData = null
	var mirror: BossAttackData = null
	for attack in med_attacks:
		if attack.attack_id == &"med_spit":
			spit = attack
		if attack.attack_id == &"med_gaze":
			gaze = attack
		if attack.attack_id == &"med_mirror":
			mirror = attack
	if spit == null:
		failures.append("the Medusa has no spit")
	else:
		if spit.attack_shape != &"projectile":
			failures.append("the spit is not projectile-shaped (%s)" % spit.attack_shape)
		if spit.max_range < 8.0:
			failures.append("the spit band is not ranged (%.1f m)" % spit.max_range)
	if gaze == null:
		failures.append("the Medusa has no gaze")
	else:
		if gaze.status_effect != &"petrify":
			failures.append("the gaze carries no petrify status (%s)" % gaze.status_effect)
		if gaze.hit_type != CombatTypes.HitType.SPECIAL:
			failures.append("the gaze is not flagged SPECIAL")
	if mirror == null:
		failures.append("the Medusa has no mirror")
	else:
		if mirror.attack_shape != &"shield":
			failures.append("the mirror is not shield-shaped (%s)" % mirror.attack_shape)
		if mirror.duration < 3.0:
			failures.append("the mirror window is too short (%.1f s)" % mirror.duration)

	# --- C. The real select path spawns the MEDUSA. ---
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
		for _step in 3:
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
		printerr("MEDUSA CHECK FAILURE: the arena is missing actors")
		quit(1)
		return
	if boss.boss_title != "MEDUSA":
		failures.append("the arena spawned '%s', not the MEDUSA" % boss.boss_title)
	if not is_equal_approx(float(boss.get_node("Health").max_health), 120.0):
		failures.append("the Medusa's max health is %.0f (expected 120)" % float(boss.get_node("Health").max_health))
	var player_health = player.get_node("Health")

	# --- D. Ranged pressure: parked far, the spit's bolt crosses and lands. ---
	boss.movement_speed = 0.0  # park: pure ranged pressure, no chase
	boss._cooldowns[&"med_mirror"] = 999.0  # the mirror would dilute the pick
	player.global_position = Vector3(-2, 0.5, 0)
	boss.global_position = Vector3(4, 0, 0)
	var spit_seen := false
	for _i in 900:
		if boss.state == boss.State.TELEGRAPH and boss._current_attack != null \
				and boss._current_attack.attack_id == &"med_spit":
			spit_seen = true
			break
		await physics_frame
	if not spit_seen:
		failures.append("the Medusa never spat from range")
	else:
		var bolt_seen := false
		var hit_seen := false
		for _i in 180:
			if get_nodes_in_group("spell_projectile").size() > 0:
				bolt_seen = true
			if not is_equal_approx(float(player_health.current_health), 100.0):
				hit_seen = true
				break
			await physics_frame
		if not (bolt_seen or hit_seen):
			failures.append("the spit cast no projectile and landed nothing")
		elif not hit_seen:
			failures.append("the spit never reached a stationary player")
		elif not is_equal_approx(float(player_health.current_health), 88.0):
			failures.append("the spit took %.1f (expected 12)" % [
				100.0 - float(player_health.current_health),
			])

	# --- E. The gaze: a clean hit petrifies, then releases. ---
	# Wait out the spit's recovery first: its natural cooldown write would
	# otherwise overwrite the pokes below (the sweep caught this race).
	for _i in 120:
		if boss.state == boss.State.OBSERVE and boss._current_attack == null:
			break
		await physics_frame
	player_health.heal(999.0)
	boss._cooldowns[&"med_spit"] = 999.0
	boss._cooldowns[&"med_mirror"] = 999.0
	# stand in the gaze band (1.5-4 m), outside the cleave band (max 2.2)
	player.global_position = boss.global_position + Vector3(0, 0.5, -2.5)
	var gaze_seen := false
	for _i in 900:
		if boss.state == boss.State.TELEGRAPH and boss._current_attack != null \
				and boss._current_attack.attack_id == &"med_gaze":
			gaze_seen = true
			break
		await physics_frame
	if not gaze_seen:
		failures.append("the Medusa never gazed at mid-range")
	else:
		await _wait(int(boss._current_attack.telegraph_duration * 60.0) + 60)
		if not player.petrify_active():
			failures.append("the gaze did not petrify the player")
		if not is_equal_approx(float(player_health.current_health), 92.0):
			failures.append("the gaze took %.1f (expected 8)" % [
				100.0 - float(player_health.current_health),
			])
		for _i in 180:
			if not player.petrify_active():
				break
			await physics_frame
		if player.petrify_active():
			failures.append("the petrify never expired")

	# --- F. The mirror: negates and returns, then expires. ---
	for _i in 120:
		if boss.state == boss.State.OBSERVE and boss._current_attack == null:
			break
		await physics_frame
	player_health.heal(999.0)
	boss._cooldowns.clear()
	boss._cooldowns[&"med_spit"] = 999.0
	boss._cooldowns[&"med_gaze"] = 999.0
	boss._cooldowns[&"med_cleave"] = 999.0
	player.global_position = boss.global_position + Vector3(0, 0.5, -2.5)
	var mirror_cast := false
	for _i in 900:
		if boss.state == boss.State.TELEGRAPH and boss._current_attack != null \
				and boss._current_attack.attack_id == &"med_mirror":
			mirror_cast = true
			break
		await physics_frame
	if not mirror_cast:
		failures.append("the Medusa never raised the mirror")
	else:
		await _wait(int(boss._current_attack.telegraph_duration * 60.0) + 40)
		if not boss.is_mirroring():
			failures.append("the mirror window did not open")
		var boss_start := float(boss.get_node("Health").current_health)
		var strike := DamageEvent.new()
		strike.source = player
		strike.amount = 15.0
		boss._resolve_incoming_damage(strike)
		if not is_equal_approx(float(boss.get_node("Health").current_health), boss_start):
			failures.append("the mirror did not negate the hit (%.1f -> %.1f)" % [
				boss_start, float(boss.get_node("Health").current_health),
			])
		if not is_equal_approx(float(player_health.current_health), 90.0):
			failures.append("the mirror returned %.1f (expected 10)" % [
				100.0 - float(player_health.current_health),
			])
		for _i in 220:
			await physics_frame
			if not boss.is_mirroring():
				break
		if boss.is_mirroring():
			failures.append("the mirror never expired")
		else:
			var boss_start2 := float(boss.get_node("Health").current_health)
			var strike2 := DamageEvent.new()
			strike2.source = player
			strike2.amount = 15.0
			boss._resolve_incoming_damage(strike2)
			if not is_equal_approx(float(boss.get_node("Health").current_health), boss_start2 - 15.0):
				failures.append("a post-mirror hit was still negated (%.1f -> %.1f)" % [
					boss_start2, float(boss.get_node("Health").current_health),
				])

	# cleanup the real-path arena
	current_scene.free()
	current_scene = null

	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)

	if failures.is_empty():
		print("MEDUSA CHECK: PASS (roster, distinct data, ranged spit lands, gaze petrifies + releases, mirror negates/returns + expires)")
		quit(0)
	else:
		for failure in failures:
			printerr("MEDUSA CHECK FAILURE: " + failure)
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
