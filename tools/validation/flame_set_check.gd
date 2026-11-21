extends SceneTree
## Sprint 37 Flame Set verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/flame_set_check.gd
## Asserts the roadmap checklist — fire magic gains major area/effect
## changes when equipped: the Flame Set data (two tagged pieces, the
## flame_bolt effect key) and the fire spell's blast fields; the arena
## mechanics with the REAL LB+B cast: without the set the firebolt deals
## 16, with the Flame Set pieces equipped the same cast deals 24 (the
## direct hit plus the blast catching the boss in its radius); and the
## real armory path (equip both -> fight -> cast) spawns the explosive
## firebolt. Exits 0 on PASS, 1 on FAIL.

const SETTLE_FRAMES := 30
const TITLE_SCENE := "res://game/scenes/ui/title_screen.tscn"
const BTN_LB := 9
const BTN_B := 1

func _initialize() -> void:
	_run()

func _run() -> void:
	var failures: PackedStringArray = []
	OS.set_environment("FIRSTBLOOD_CHECK_SAVE", "1")
	var check_save := ProjectSettings.globalize_path("user://check_save.json")
	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)
	GearLibrary.reload_from_save()

	# --- A. The Flame Set data: two tagged pieces, the effect key. ---
	var sets_catalog := GearLibrary.set_catalog()
	var flame: SetData = null
	if sets_catalog == null:
		failures.append("the set catalog failed to load")
	else:
		for set_data in sets_catalog.sets:
			if set_data.id == "flame":
				flame = set_data
	if flame == null:
		failures.append("the Flame Set is missing from the set catalog")
	else:
		if flame.required_pieces != 2:
			failures.append("the Flame Set requires %d pieces (expected 2)" % flame.required_pieces)
		if flame.effect != &"flame_bolt":
			failures.append("the Flame Set carries no flame_bolt effect (%s)" % flame.effect)
	var crown := load("res://game/resources/gear/gear_ember_crown.tres") as GearData
	var bracers := load("res://game/resources/gear/gear_flame_bracers.tres") as GearData
	if crown == null or bracers == null:
		failures.append("the flame pieces failed to load")
	else:
		if crown.set_id != "flame" or bracers.set_id != "flame":
			failures.append("the flame pieces are not set-tagged (%s / %s)" % [crown.set_id, bracers.set_id])
	var fire: SpellData = load("res://game/resources/magic/spell_fire.tres") as SpellData
	if fire == null:
		failures.append("the fire spell failed to load")
	elif not is_equal_approx(fire.blast_damage, 8.0) or not is_equal_approx(fire.blast_radius, 2.5):
		failures.append("the fire spell's blast fields drifted (%.1f / %.1f)" % [
			fire.blast_damage, fire.blast_radius,
		])

	# --- B. The arena mechanics: the REAL LB+B cast, without then with the set. ---
	var arena_scene: PackedScene = load("res://game/scenes/arena/arena.tscn")
	if arena_scene == null:
		printerr("FLAME SET CHECK FAILURE: arena scene missing")
		quit(1)
		return
	var arena := arena_scene.instantiate()
	root.add_child(arena)
	await _wait(SETTLE_FRAMES)
	var boss = get_first_node_in_group("boss")
	var player = get_first_node_in_group("player")
	if boss == null or player == null:
		printerr("FLAME SET CHECK FAILURE: the arena is missing actors")
		quit(1)
		return
	var boss_health = boss.get_node("Health")
	var equipment: EquipmentComponent = player.get_node("Equipment")
	player.global_position = Vector3(-2, 0.5, 0)
	boss.global_position = Vector3(4, 0, 0)
	boss.movement_speed = 0.0  # park: the cast tests are deterministic

	# without the set: the firebolt deals exactly 16
	var cast_ok := await _cast_fire(player)
	if not cast_ok:
		failures.append("the LB+B cast did not fire")
	else:
		var landed := false
		for _i in 120:
			if float(boss_health.current_health) < 100.0:
				landed = true
				break
			await physics_frame
		if not landed:
			failures.append("the un-set firebolt never landed")
		elif not is_equal_approx(float(boss_health.current_health), 84.0):
			failures.append("the un-set firebolt took %.1f (expected 16)" % [
				100.0 - float(boss_health.current_health),
			])

	# with the Flame Set: the same cast deals 24 (16 direct + 8 blast)
	equipment.equip(crown)
	equipment.equip(bracers)
	boss_health.heal(999.0)
	if not await _cast_fire(player):
		failures.append("the set-boosted cast did not fire")
	else:
		var landed := false
		for _i in 120:
			if float(boss_health.current_health) < 100.0:
				landed = true
				break
			await physics_frame
		if not landed:
			failures.append("the explosive firebolt never landed")
		elif not is_equal_approx(float(boss_health.current_health), 76.0):
			failures.append("the explosive firebolt took %.1f (expected 24 = 16 + 8 blast)" % [
				100.0 - float(boss_health.current_health),
			])
	arena.free()
	MatchSetup.selected = null

	# --- C. The real armory path: title -> armory -> equip both -> fight. ---
	var title_scene: PackedScene = load(TITLE_SCENE)
	var title: Control = title_scene.instantiate()
	root.add_child(title)
	current_scene = title
	await _wait(5)
	Input.parse_input_event(_key(KEY_G, true))
	await _wait(2)
	Input.parse_input_event(_key(KEY_G, false))
	var armory: Control = null
	for _i in 120:
		await physics_frame
		if current_scene != null and current_scene.name == "Armory":
			armory = current_scene
			break
	if armory == null:
		failures.append("the armory action did not open the armory")
	else:
		GearLibrary.set_loadout([])  # B's live-player equips polluted the loadout
		# rows: cap(0) cuirass(1) wraps(2) sandals(3) crown(4) bracers(5) ...
		for _step in 4:
			Input.parse_input_event(_key(KEY_DOWN, true))
			await _wait(2)
			Input.parse_input_event(_key(KEY_DOWN, false))
			await _wait(2)
		print("[ARM] index=", armory._index)
		Input.parse_input_event(_key(KEY_ENTER, true))
		await _wait(2)
		Input.parse_input_event(_key(KEY_ENTER, false))
		await _wait(2)
		print("[ARM] after wear1: loadout=", GearLibrary.loadout)
		Input.parse_input_event(_key(KEY_DOWN, true))
		await _wait(2)
		Input.parse_input_event(_key(KEY_DOWN, false))
		await _wait(2)
		Input.parse_input_event(_key(KEY_ENTER, true))
		await _wait(2)
		Input.parse_input_event(_key(KEY_ENTER, false))
		await _wait(2)
		print("[ARM] after wear2: loadout=", GearLibrary.loadout)
		var loadout := GearLibrary.loadout
		if not loadout.has(StringName("ember_crown")) or not loadout.has(StringName("flame_bracers")):
			failures.append("the armory toggles did not assemble the Flame Set (%s)" % [loadout])
		Input.parse_input_event(_key(KEY_ESCAPE, true))
		await _wait(2)
		Input.parse_input_event(_key(KEY_ESCAPE, false))
		var back := false
		for _i in 120:
			await physics_frame
			if current_scene != null and current_scene.name == "TitleScreen":
				back = true
				break
		if not back:
			failures.append("ui_cancel did not return to the title")
		else:
			current_scene.start_fight()
			var select_ready := false
			for _i in 120:
				await physics_frame
				if current_scene != null and current_scene.name == "BossSelect":
					select_ready = true
					break
			if not select_ready:
				failures.append("start_fight did not reach the boss select screen")
			else:
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
					await _wait(SETTLE_FRAMES)
					var fight_boss = get_first_node_in_group("boss")
					var fight_player = get_first_node_in_group("player")
					fight_boss.global_position = fight_player.global_position + Vector3(6, 0, 0)
					boss_health = fight_boss.get_node("Health")
					if not await _cast_fire(fight_player):
						failures.append("the real-path cast did not fire")
					else:
						var landed := false
						for _i in 120:
							if float(boss_health.current_health) < 100.0:
								landed = true
								break
							await physics_frame
						if not landed:
							failures.append("the real-path firebolt never landed")
						elif not is_equal_approx(float(boss_health.current_health), 76.0):
							failures.append("the real-path firebolt took %.1f (expected 24 = 16 + 8 blast)" % [
								100.0 - float(boss_health.current_health),
							])
				current_scene.free()
				current_scene = null

	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)

	if failures.is_empty():
		print("FLAME SET CHECK: PASS (set data, blast fields, un-set 16 vs set 24, armory equips the identity)")
		quit(0)
	else:
		for failure in failures:
			printerr("FLAME SET CHECK FAILURE: " + failure)
		quit(1)

## The REAL spell cast: hold LB, tap B (the fire slot), release.
func _cast_fire(player) -> bool:
	player.global_position = Vector3(-2, 0.5, 0)
	await _wait(SETTLE_FRAMES)  # land first: the cast gate is ground-neutral
	var mana: ManaComponent = player.get_node("Mana")
	mana.reset()
	Input.parse_input_event(_pad(BTN_LB, true))
	await _wait(2)
	Input.parse_input_event(_pad(BTN_B, true))
	await _wait(2)
	Input.parse_input_event(_pad(BTN_B, false))
	await _wait(2)
	Input.parse_input_event(_pad(BTN_LB, false))
	await _wait(2)
	return float(mana.current_mana) < float(mana.max_mana)

func _pad(button: int, pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	return event

func _key(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = pressed
	return event

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
