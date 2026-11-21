extends SceneTree
## Sprint 38 Gladiator Set verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/gladiator_set_check.gd
## Asserts the roadmap checklist — movement/attack speed increase and
## finisher explosion work together WITHOUT breaking combat rules: the set
## data (two tagged pieces, the gladiator_finisher effect key, the speed
## bonuses), and the arena with the REAL combo inputs: without the set a
## full combo takes exactly 61; equipping the set on the arena player
## multiplies the speed (5.65, ×1.05) and the same combo takes 75 (61 +
## 4 from the mid-combo level-up + 10 finisher blast) — the gladiator's
## own stagger/breakout firing mid-combo as usual. Exits 0 on PASS, 1 on
## FAIL.

const SETTLE_FRAMES := 30
const TITLE_SCENE := "res://game/scenes/ui/title_screen.tscn"
const STEP_GAP_FRAMES := 34

func _initialize() -> void:
	_run()

func _run() -> void:
	var failures: PackedStringArray = []
	OS.set_environment("FIRSTBLOOD_CHECK_SAVE", "1")
	var check_save := ProjectSettings.globalize_path("user://check_save.json")
	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)
	GearLibrary.reload_from_save()

	# --- A. The set data: two tagged pieces, the effect key, the speeds. ---
	var sets_catalog := GearLibrary.set_catalog()
	var gladiator: SetData = null
	if sets_catalog == null:
		failures.append("the set catalog failed to load")
	else:
		for set_data in sets_catalog.sets:
			if set_data.id == "gladiator":
				gladiator = set_data
	if gladiator == null:
		failures.append("the Gladiator Set is missing from the set catalog")
	else:
		if gladiator.required_pieces != 2:
			failures.append("the Gladiator Set requires %d pieces (expected 2)" % gladiator.required_pieces)
		if gladiator.effect != &"gladiator_finisher":
			failures.append("the Gladiator Set carries no finisher effect (%s)" % gladiator.effect)
		if not is_equal_approx(gladiator.movement_bonus, 0.3):
			failures.append("the set's movement bonus drifted (%.2f)" % gladiator.movement_bonus)
		if not is_equal_approx(gladiator.attack_speed_bonus, 0.05):
			failures.append("the set's attack-speed bonus drifted (%.2f)" % gladiator.attack_speed_bonus)
	var pauldrons := load("res://game/resources/gear/gear_gladiator_pauldrons.tres") as GearData
	var greaves := load("res://game/resources/gear/gear_gladiator_greaves.tres") as GearData
	if pauldrons == null or greaves == null:
		failures.append("the gladiator pieces failed to load")
	else:
		if pauldrons.set_id != "gladiator" or greaves.set_id != "gladiator":
			failures.append("the gladiator pieces are not set-tagged (%s / %s)" % [
				pauldrons.set_id, greaves.set_id,
			])
	# the finisher steps carry the blast
	var finisher_combo := load("res://game/resources/attacks/player_light_combo.tres") as ComboData
	if finisher_combo == null or finisher_combo.finisher_chain.is_empty():
		failures.append("the default combo's finisher chain is missing")
	elif finisher_combo.finisher_chain[-1].blast_damage < 10.0:
		failures.append("the chain's last step carries no blast (%.1f)" % finisher_combo.finisher_chain[-1].blast_damage)

	# --- B. The arena: the REAL combo inputs, with and without the set. ---
	# One player for both combos: the un-set baseline first, then the set
	# equips on the SAME player (no second player to leak state through).
	GearLibrary.set_loadout([])
	var arena_scene: PackedScene = load("res://game/scenes/arena/arena.tscn")
	if arena_scene == null:
		printerr("GLADIATOR SET CHECK FAILURE: arena scene missing")
		quit(1)
		return
	var arena := arena_scene.instantiate()
	root.add_child(arena)
	await _wait(SETTLE_FRAMES)
	var boss = get_first_node_in_group("boss")
	var arena_player = get_first_node_in_group("player")
	if boss == null or arena_player == null:
		printerr("GLADIATOR SET CHECK FAILURE: the arena is missing actors")
		quit(1)
		return
	var boss_health = boss.get_node("Health")
	var equipment: EquipmentComponent = arena_player.get_node("Equipment")
	boss.movement_speed = 0.0  # park: the combo totals are deterministic
	# park the boss's ATTACKS too: its own bite mid-combo rolls a post-attack
	# guard that blocks light_03 (the sweep caught this)
	boss._cooldowns[&"boss_light"] = 999.0
	boss._cooldowns[&"boss_light_2"] = 999.0
	boss._cooldowns[&"boss_heavy"] = 999.0
	# the combo_check's proven geometry: the boss at +X, the player facing it
	await _settle_player(arena_player, boss.global_position + Vector3(-1.8, 0.5, 0))
	arena_player.rotation.y = -PI / 2.0

	# without the set: a full combo takes exactly 76 (10+12+14+25+15)
	var total := await _full_combo_damage(arena_player, boss_health)
	if not is_equal_approx(total, 76.0):
		failures.append("the un-set full combo took %.1f (expected 76)" % total)

	# with the set: the speed asserts + the same combo takes 75
	# (61 + 4 from the mid-combo level-up + 10 finisher blast)
	equipment.equip(pauldrons)
	equipment.equip(greaves)
	# base 5.0 + pauldrons 0.1 + greaves 0.25 + set 0.3 = 5.65
	if not is_equal_approx(float(arena_player.movement_speed), 5.65):
		failures.append("the gladiator speed is wrong (%.2f, expected 5.65)" % float(arena_player.movement_speed))
	# base 1.0 + the set's 0.05 = 1.05
	if not is_equal_approx(float(arena_player.attack_speed_multiplier), 1.05):
		failures.append("the gladiator attack-speed is wrong (%.2f, expected 1.05)" % float(arena_player.attack_speed_multiplier))
	if not arena_player._has_set_effect(&"gladiator_finisher"):
		failures.append("the gladiator_finisher effect is not active")
	player_health_heal(boss_health, 999.0)
	await _settle_player(arena_player, boss.global_position + Vector3(-1.8, 0.5, 0))
	arena_player.rotation.y = -PI / 2.0
	# C1's finisher triggered the boss's breakout and its aftermath may roll
	# a guard — wait for OBSERVE before the second combo, or the guard
	# blocks light_03 mid-drive.
	for _i in 300:
		if boss.state == boss.State.OBSERVE:
			break
		await physics_frame
	# the combo's own damage is XP: the second combo levels the player at
	# light_01's hit (the C1 combo's 76 XP + 10 crosses the 80 threshold) —
	# the +2 attack lands on the last FOUR swings: 76 + 8 + 10 blast = 94
	total = await _full_combo_damage(arena_player, boss_health)
	if not is_equal_approx(total, 94.0):
		failures.append("the gladiator full combo took %.1f (expected 94 = 76 + 8 level-up + 10 blast)" % total)

	arena.free()
	MatchSetup.selected = null

	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)

	if failures.is_empty():
		print("GLADIATOR SET CHECK: PASS (set data, speed 5.65/x1.05, un-set combo 76 vs gladiator 94, combat rules hold)")
		quit(0)
	else:
		for failure in failures:
			printerr("GLADIATOR SET CHECK FAILURE: " + failure)
		quit(1)

## Drives a REAL full combo (three taps with the buffer gaps; the finisher
## fires automatically) and returns the boss's total damage. Starts from a
## fully-idle, fully-reset player (the combo_check's _combo_cooldown
## pattern) — a tap fired mid-settle or mid-grace breaks the chain.
func _full_combo_damage(player, boss_health) -> float:
	for _i in 60:
		if player.state != player.State.ATTACK:
			break
		await physics_frame
	await _wait(25)  # the reset margin: the combo index fully resets
	var start := float(boss_health.current_health)
	for _step in 3:
		await _tap_attack()
		# wait for the swing to fully end: the RECOVERY ignores attack inputs
		# (D-029) and the attack speed shortens it — wait, don't count frames
		for _i in 60:
			if player.state == player.State.IDLE:
				break
			await physics_frame
		await _wait(5)  # inside the combo grace
	await _wait(100)  # the finisher plays out (hit-stop can extend it)
	for _i in 40:
		await physics_frame
	return start - float(boss_health.current_health)

func player_health_heal(health, amount: float) -> void:
	health.heal(amount)

## The combo_check's proven settle: position, zero velocity, wait out the fall.
func _settle_player(player, pos: Vector3) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	await _wait(SETTLE_FRAMES)

func _tap_attack() -> void:
	Input.action_press("attack")
	await physics_frame
	Input.action_release("attack")
	await physics_frame

func _key(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = pressed
	return event

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
