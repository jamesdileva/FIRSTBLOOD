extends SceneTree
## Sprint 36 set-framework verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/set_check.gd
## Asserts the roadmap checklist — equipping a set changes configured
## gameplay effects: the set catalog loads, the Trainee pieces are tagged,
## one piece grants nothing, both pieces grant the +4 attack through the
## equipment totals, the real player composition carries it into the
## attack payload, unequipping drops it, and the real armory path (equip
## both -> fight) spawns a player with the set-boosted stats. Exits 0 on
## PASS, 1 on FAIL.

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
	GearLibrary.reload_from_save()

	# --- A. The set catalog: the Trainee Set, 2 pieces. ---
	var sets_catalog := GearLibrary.set_catalog()
	if sets_catalog == null:
		printerr("SET CHECK FAILURE: the set catalog failed to load")
		quit(1)
		return
	if sets_catalog.sets.is_empty():
		failures.append("the set catalog is empty")
	var trainee: SetData = null
	for set_data in sets_catalog.sets:
		if set_data.id == "trainee":
			trainee = set_data
	if trainee == null:
		failures.append("the Trainee Set is missing from the catalog")
	elif trainee.required_pieces != 2:
		failures.append("the Trainee Set requires %d pieces (expected 2)" % trainee.required_pieces)
	elif not is_equal_approx(trainee.attack_bonus, 4.0):
		failures.append("the Trainee Set bonus drifted (%.1f, expected 4)" % trainee.attack_bonus)
	# the pieces are tagged
	var cap := (load("res://game/resources/gear/gear_trainees_cap.tres") as Resource) as GearData
	var wraps := (load("res://game/resources/gear/gear_wrist_wraps.tres") as Resource) as GearData
	if cap == null or wraps == null:
		failures.append("the trainee pieces failed to load")
	else:
		if cap.set_id != "trainee" or wraps.set_id != "trainee":
			failures.append("the trainee pieces are not set-tagged (%s / %s)" % [cap.set_id, wraps.set_id])

	# --- B. Aggregation: one piece grants nothing, two grant the bonus. ---
	var staging := EquipmentComponent.new()
	staging.equip(cap)
	if not is_equal_approx(staging.attack_bonus(), 0.0):
		failures.append("a lone set piece granted a bonus (attack %.1f)" % staging.attack_bonus())
	staging.equip(wraps)
	if not is_equal_approx(staging.attack_bonus(), 6.0):
		failures.append("the set bonus is missing from the totals (attack %.1f, expected 2 item + 4 set)" % staging.attack_bonus())
	if not is_equal_approx(staging.hp_bonus(), 6.0):
		failures.append("the set bonus polluted the hp total (%.1f, expected 6)" % staging.hp_bonus())
	# unequip one -> the bonus drops
	staging.unequip_slot(&"HEAD")
	if not is_equal_approx(staging.attack_bonus(), 2.0):
		failures.append("unequipping did not drop the set bonus (attack %.1f)" % staging.attack_bonus())
	staging.free()

	# --- C. The real player composition carries the set into the payload. ---
	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)
	GearLibrary.reload_from_save()
	var player_scene: PackedScene = load("res://game/scenes/player/player.tscn")
	var player = player_scene.instantiate()
	root.add_child(player)
	await _wait(SETTLE_FRAMES)
	var equipment: EquipmentComponent = player.get_node("Equipment")
	equipment.equip(cap)
	equipment.equip(wraps)
	if not is_equal_approx(float(player.attack_stat_bonus), 6.0):
		failures.append("the set bonus is missing from the player's attack composition (%.1f, expected 6)" % float(player.attack_stat_bonus))
	if not is_equal_approx(float(player.get_node("Health").max_health), 106.0):
		failures.append("the cap's hp bonus is wrong with the set active (%.0f, expected 106)" % float(player.get_node("Health").max_health))
	player.free()
	GearLibrary.reload_from_save()

	# --- D. The real path: title -> armory -> equip both -> fight. ---
	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)
	GearLibrary.reload_from_save()
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
		# rows: cap(0) cuirass(1) wraps(2) ... — wear the cap and the wraps
		Input.parse_input_event(_key(KEY_ENTER, true))
		await _wait(2)
		Input.parse_input_event(_key(KEY_ENTER, false))
		await _wait(2)
		Input.parse_input_event(_key(KEY_DOWN, true))
		await _wait(2)
		Input.parse_input_event(_key(KEY_DOWN, false))
		await _wait(2)
		Input.parse_input_event(_key(KEY_DOWN, true))
		await _wait(2)
		Input.parse_input_event(_key(KEY_DOWN, false))
		await _wait(2)
		Input.parse_input_event(_key(KEY_ENTER, true))
		await _wait(2)
		Input.parse_input_event(_key(KEY_ENTER, false))
		await _wait(2)
		var loadout := GearLibrary.loadout
		if loadout.size() != 2 or not loadout.has(StringName("trainees_cap")) \
				or not loadout.has(StringName("wrist_wraps")):
			failures.append("the armory toggles did not assemble the trainee set (%s)" % [loadout])
		else:
			var totals := (armory.get_node("Layout/Totals") as Label).text
			if "TRAINEE SET" not in totals:
				failures.append("the armory totals line does not name the active set (%s)" % totals)
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
					var fight_player = get_first_node_in_group("player")
					if fight_player == null:
						failures.append("no player spawned for the set fight")
					elif not is_equal_approx(float(fight_player.attack_stat_bonus), 6.0):
						failures.append("the spawned player lost the set bonus (%.1f, expected 6)" % float(fight_player.attack_stat_bonus))
				current_scene.free()
				current_scene = null

	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)

	if failures.is_empty():
		print("SET CHECK: PASS (catalog, one-piece inert, both-piece +4 through totals, player payload, armory names the set, real-path fight)")
		quit(0)
	else:
		for failure in failures:
			printerr("SET CHECK FAILURE: " + failure)
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
