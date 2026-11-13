extends SceneTree
## Sprint 26 gear-framework verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/gear_check.gd
## Asserts the roadmap checklist — equipment changes player stats and
## persists correctly: catalog integrity, aggregation math + the
## one-piece-per-slot swap, player stat composition (max health, attack
## payload, armor soak), persistence round-trips (the gear key survives a
## progression save; unknown ids resolve harmlessly), and the real path
## title -> armory (G) -> equip -> back -> title -> fight with the loadout
## applied on the spawned player. Exits 0 on PASS, 1 on FAIL.

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

	# --- A. Catalog integrity: unique ids/slots, sane modifiers. ---
	var gear_catalog := GearLibrary.catalog()
	if gear_catalog == null:
		printerr("GEAR CHECK FAILURE: the gear catalog failed to load")
		quit(1)
		return
	var slots := {}
	for item in gear_catalog.items:
		if item.id.is_empty():
			failures.append("a catalog piece has no id")
		if item.display_name.is_empty():
			failures.append("gear piece %s has no display name" % item.id)
		if slots.has(item.slot) and item.slot != &"WEAPON":
			failures.append("duplicate slot %s in the catalog" % item.slot)
		slots[item.slot] = true
		for value in [item.hp_bonus, item.armor, item.attack_bonus, item.movement_bonus, item.attack_speed_bonus]:
			if value < 0.0:
				failures.append("gear piece %s has a negative modifier" % item.id)
	if gear_catalog.items.size() < 4:
		failures.append("the starter catalog holds fewer than four pieces (%d)" % gear_catalog.items.size())

	# --- B. Aggregation + the one-piece-per-slot swap. ---
	var cuirass := _by_id(gear_catalog, "legion_cuirass")
	var wraps := _by_id(gear_catalog, "wrist_wraps")
	var cap := _by_id(gear_catalog, "trainees_cap")
	if cuirass == null or wraps == null or cap == null:
		printerr("GEAR CHECK FAILURE: expected starter pieces missing from the catalog")
		quit(1)
		return
	var staging := EquipmentComponent.new()
	staging.equip(cuirass)
	staging.equip(wraps)
	if not is_equal_approx(staging.hp_bonus(), 12.0):
		failures.append("hp aggregation wrong: %.1f (expected 12)" % staging.hp_bonus())
	if not is_equal_approx(staging.attack_bonus(), 2.0):
		failures.append("attack aggregation wrong: %.1f (expected 2)" % staging.attack_bonus())
	if not is_equal_approx(staging.armor_total(), 1.0):
		failures.append("armor aggregation wrong: %.1f (expected 1)" % staging.armor_total())
	var check_cap := GearData.new()
	check_cap.id = "check_cap"
	check_cap.display_name = "CHECK CAP"
	check_cap.slot = &"HEAD"
	check_cap.hp_bonus = 20.0
	staging.equip(cap)
	staging.equip(check_cap)
	if not is_equal_approx(staging.hp_bonus(), 32.0):
		failures.append("the slot swap did not replace the HEAD piece (hp %.1f, expected 32)" % staging.hp_bonus())
	if not is_equal_approx(staging.attack_bonus(), 2.0):
		failures.append("the swap disturbed the HANDS piece (attack %.1f, expected 2)" % staging.attack_bonus())
	if staging.is_equipped(cap):
		failures.append("the swapped-out cap is still marked equipped")
	staging.free()

	# --- C. Player stat composition (a real player scene, empty loadout). ---
	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)
	GearLibrary.reload_from_save()
	var player_scene: PackedScene = load("res://game/scenes/player/player.tscn")
	var player = player_scene.instantiate()
	root.add_child(player)
	await _wait(SETTLE_FRAMES)
	var health = player.get_node("Health")
	if not is_equal_approx(float(health.max_health), 100.0):
		failures.append("a fresh player with an empty loadout is not at 100 HP (%.0f)" % float(health.max_health))
	var equipment: EquipmentComponent = player.get_node("Equipment")
	equipment.equip(cuirass)
	equipment.equip(wraps)
	if not is_equal_approx(float(health.max_health), 112.0):
		failures.append("equipping gear did not raise max health to 112 (%.0f)" % float(health.max_health))
	if not is_equal_approx(float(player.attack_stat_bonus), 2.0):
		failures.append("the gear attack bonus is missing from the stat composition (%.1f)" % float(player.attack_stat_bonus))
	var event := DamageEvent.new()
	event.amount = 10.0
	player._resolve_incoming_damage(event)
	if not is_equal_approx(float(event.amount), 9.0):
		failures.append("the armor soak is wrong: %.1f (expected 9)" % float(event.amount))
	var chip := DamageEvent.new()
	chip.amount = 1.0
	player._resolve_incoming_damage(chip)
	if not is_equal_approx(float(chip.amount), 1.0):
		failures.append("the armor floor is wrong: %.1f (expected 1)" % float(chip.amount))
	# a level-up must re-apply gear, not wipe it (level 3: 2*2 level + 2 gear)
	player.get_node("Progression").level = 3
	player._on_level_up(3)
	if not is_equal_approx(float(player.attack_stat_bonus), 6.0):
		failures.append("a level-up wiped the gear bonuses (%.1f, expected 6)" % float(player.attack_stat_bonus))
	player.free()
	GearLibrary.reload_from_save()

	# --- D. Persistence round-trips (the check save). ---
	GearLibrary.set_loadout([StringName("legion_cuirass"), StringName("wrist_wraps")])
	GearLibrary.reload_from_save()
	if GearLibrary.loadout.size() != 2:
		failures.append("the loadout did not round-trip the save (%d)" % GearLibrary.loadout.size())
	# the D-080 read-merge: a progression save must keep the equipment key
	var progression := ProgressionComponent.new()
	root.add_child(progression)
	await _wait(2)
	progression.level = 4
	progression.xp = 10.0
	progression.save()
	progression.free()
	GearLibrary.reload_from_save()
	if GearLibrary.loadout.size() != 2:
		failures.append("a progression save wiped the equipment key")
	var resolved := GearLibrary.resolve(["legion_cuirass", "gone_item"])
	if resolved.size() != 1:
		failures.append("unknown gear ids did not resolve harmlessly (%d)" % resolved.size())

	# --- E. Real path: title -> armory (G) -> equip -> back -> fight. ---
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
		if armory._rows.size() != gear_catalog.items.size():
			failures.append("the armory built %d rows for %d pieces" % [
				armory._rows.size(), gear_catalog.items.size(),
			])
		# row 1 (cuirass) then row 2 (wraps): down, wear, down, wear
		for _step in 2:
			Input.parse_input_event(_key(KEY_DOWN, true))
			await _wait(2)
			Input.parse_input_event(_key(KEY_DOWN, false))
			await _wait(2)
			Input.parse_input_event(_key(KEY_ENTER, true))
			await _wait(2)
			Input.parse_input_event(_key(KEY_ENTER, false))
			await _wait(2)
		if GearLibrary.loadout.size() != 2 or not GearLibrary.loadout.has(StringName("legion_cuirass")):
			failures.append("the armory toggles did not wear the expected loadout (%s)" % [GearLibrary.loadout])
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
			failures.append("ui_cancel did not return to the title from the armory")
		else:
			# the fight: the spawned player wears the armory loadout
			var active_title: Control = current_scene
			active_title.start_fight()
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
						failures.append("no player spawned for the gear fight")
					else:
						var worn: Array[StringName] = fight_player.get_node("Equipment").id_list()
						if worn.size() != 2:
							failures.append("the spawned player did not wear the armory loadout (%s)" % [worn])
						var fight_health = fight_player.get_node("Health")
						if not is_equal_approx(float(fight_health.max_health), 112.0):
							failures.append("the spawned player's max health ignored the gear (%.0f)" % float(fight_health.max_health))
				current_scene.free()
				current_scene = null

	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)

	if failures.is_empty():
		print("GEAR CHECK: PASS (catalog, aggregation+swap, stat composition, armor soak, persistence, title->armory->fight with the loadout)")
		quit(0)
	else:
		for failure in failures:
			printerr("GEAR CHECK FAILURE: " + failure)
		quit(1)

func _by_id(gear_catalog: GearCatalog, id: String) -> GearData:
	for item in gear_catalog.items:
		if item.id == id:
			return item
	return null

func _key(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = pressed
	return event

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
