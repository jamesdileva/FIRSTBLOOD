extends SceneTree
## Sprint 35 Mutated Lion verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/lion_check.gd
## Asserts the roadmap checklist — the fight has noticeably higher movement
## pressure without relying only on HP: seven distinct roster entries, the
## lion's data carries a bleed-status attack, a pounce lunge, the pursuit
## speed, and the enrage exports; behavior in the arena: the real select
## path spawns the MUTATED LION (115 HP), the rending claws' hit bleeds the
## player (ticks drain, then clear), the pounce crosses its band into a
## stationary player (−15), and damaging the lion past 50% enrages it —
## speed visibly multiplies and it closes distance on a stationary player.
## Exits 0 on PASS, 1 on FAIL.

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

	# --- A. Roster: seven distinct entries; the seventh is the lion. ---
	var roster := MatchSetup.roster()
	if roster == null or roster.entries.size() < 7:
		failures.append("the roster holds fewer than seven entries (%s)" % [
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
	var lion_scene: PackedScene = roster.entries[6].scene
	if lion_scene == null:
		failures.append("the Mutated Lion entry has no scene")
		quit(1)
		return
	var probe := lion_scene.instantiate()
	var lion_title: String = probe.boss_title
	var lion_speed: float = probe.movement_speed
	var lion_enrage_threshold: float = probe.enrage_threshold
	var lion_attacks: Array = probe.attacks
	probe.free()
	if lion_title != "MUTATED LION":
		failures.append("the seventh boss is '%s', not the MUTATED LION" % lion_title)
	if lion_speed < 3.4:
		failures.append("the lion's pursuit speed is too low (%.1f m/s)" % lion_speed)
	if lion_enrage_threshold <= 0.0 or lion_enrage_threshold > 0.6:
		failures.append("the enrage threshold is off (%.2f)" % lion_enrage_threshold)

	# --- B. Data distinctness: bleed / pounce / enrage. ---
	var claws: BossAttackData = null
	var pounce: BossAttackData = null
	for attack in lion_attacks:
		if attack.attack_id == &"lion_claws":
			claws = attack
		if attack.attack_id == &"lion_pounce":
			pounce = attack
	if claws == null:
		failures.append("the lion has no rending claws")
	else:
		if claws.status_effect != &"bleed":
			failures.append("the claws carry no bleed status (%s)" % claws.status_effect)
	if pounce == null:
		failures.append("the lion has no pounce")
	else:
		if pounce.lunge_speed < 8.0:
			failures.append("the pounce lunges too slowly (%.1f m/s)" % pounce.lunge_speed)
		if pounce.max_range < 6.0:
			failures.append("the pounce band is not mid-range (%.1f m)" % pounce.max_range)

	# --- C. The real select path spawns the MUTATED LION. ---
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
		for _step in 6:
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
		printerr("LION CHECK FAILURE: the arena is missing actors")
		quit(1)
		return
	if boss.boss_title != "MUTATED LION":
		failures.append("the arena spawned '%s', not the MUTATED LION" % boss.boss_title)
	if not is_equal_approx(float(boss.get_node("Health").max_health), 115.0):
		failures.append("the lion's max health is %.0f (expected 115)" % float(boss.get_node("Health").max_health))
	var player_health = player.get_node("Health")

	# --- D. The bleed: parked, the claws land and the player bleeds. ---
	boss.movement_speed = 0.0  # park: the status test is deterministic
	boss._cooldowns[&"lion_bite"] = 999.0
	boss._cooldowns[&"lion_pounce"] = 999.0
	player.global_position = boss.global_position + Vector3(0, 0.5, -1.5)
	var claws_seen := false
	for _i in 900:
		if boss.state == boss.State.TELEGRAPH and boss._current_attack != null \
				and boss._current_attack.attack_id == &"lion_claws":
			claws_seen = true
			break
		await physics_frame
	if not claws_seen:
		failures.append("the lion never rended point-blank")
	else:
		await _wait(int(boss._current_attack.telegraph_duration * 60.0) + 60)
		if not player.bleed_active():
			failures.append("the claws did not bleed the player")
		var post_claws_hp := float(player_health.current_health)
		if post_claws_hp >= 100.0:
			failures.append("the claws took no damage (%.1f)" % post_claws_hp)
		boss._cooldowns[&"lion_claws"] = 999.0  # no second rending mid-drain
		for _i in 260:
			if not player.bleed_active():
				break
			await physics_frame
		if player.bleed_active():
			failures.append("the bleed never expired")
		var drained := post_claws_hp - float(player_health.current_health)
		if drained < 20.0:
			failures.append("the bleed ticks drained only %.1f (expected 30 over 3 s)" % drained)

	# --- E. The pounce: parked mid-band from tick 0, a stationary player
	# eats it. ---
	player_health.heal(999.0)
	for _i in 120:
		if boss.state == boss.State.OBSERVE and boss._current_attack == null:
			break
		await physics_frame
	boss._cooldowns.clear()  # D's pokes would otherwise lock the pounce out
	boss._cooldowns[&"lion_bite"] = 999.0
	boss._cooldowns[&"lion_claws"] = 999.0
	# 4.5 m: inside the pounce band, close enough for the 9 m/s lunge to connect
	player.global_position = Vector3(4.0 - 4.5, 0.5, 0)
	boss.global_position = Vector3(4, 0, 0)
	var pounce_seen := false
	for _i in 900:
		if boss.state == boss.State.TELEGRAPH and boss._current_attack != null \
				and boss._current_attack.attack_id == &"lion_pounce":
			pounce_seen = true
			break
		await physics_frame
	if not pounce_seen:
		failures.append("the lion never pounced from mid-band")
	else:
		await _wait(int(boss._current_attack.telegraph_duration * 60.0) + 80)
		if not is_equal_approx(float(player_health.current_health), 85.0):
			failures.append("a stationary player took %.1f from the pounce (expected 15)" % [
				100.0 - float(player_health.current_health),
			])

	# --- F. The enrage: past 50%, the speed multiplies and it PURSUES. ---
	player_health.heal(999.0)
	boss.get_node("Health").heal(999.0)
	for _i in 120:
		if boss.state == boss.State.OBSERVE and boss._current_attack == null:
			break
		await physics_frame
	# un-park and wound the lion: the enrage poll crosses at <= 57.5 HP
	boss.movement_speed = 3.6
	var wound := DamageEvent.new()
	wound.source = player
	wound.amount = 60.0
	boss._resolve_incoming_damage(wound)
	await _wait(3)
	if not boss.is_enraged():
		failures.append("the lion did not enrage past the threshold")
	elif boss.movement_speed < 5.0:
		failures.append("the enrage speed did not multiply (%.1f m/s)" % float(boss.movement_speed))
	else:
		# the pursuit: a stationary player 7 m out — past every attack band,
		# so the only thing the enraged lion can do is CLOSE. Measure the
		# closest approach over 2 s: the lion interleaves pounces with the
		# run, so path length alone under-measures the pursuit.
		player.global_position = boss.global_position + Vector3(0, 0.5, -7.0)
		var start_dist: float = (boss.global_position - player.global_position).length()
		var min_dist := start_dist
		for _i in 240:
			await physics_frame
			min_dist = minf(min_dist, (boss.global_position - player.global_position).length())
		var closed := start_dist - min_dist
		if closed < 2.0:
			failures.append("the enraged lion did not pursue (closed %.1f m of %.1f in 4 s)" % [
				closed, start_dist,
			])

	# cleanup the real-path arena
	current_scene.free()
	current_scene = null

	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)

	if failures.is_empty():
		print("LION CHECK: PASS (roster, bleed drains + clears, pounce crosses, enrage multiplies speed and pursues)")
		quit(0)
	else:
		for failure in failures:
			printerr("LION CHECK FAILURE: " + failure)
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
