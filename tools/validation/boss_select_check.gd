extends SceneTree
## Sprint 25 boss-selection verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/boss_select_check.gd
## Asserts the roadmap checklist: the roster data integrity (multiple boss
## data entries, scenes resolve), the real path title -> boss select ->
## cycle -> confirm -> the arena spawns the CHOSEN boss (title + health
## override), back navigation to the title, and the no-selection default
## keeps the arena scene's own New Gladiator. Exits 0 on PASS, 1 on FAIL.

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

	# --- A. Roster data integrity: multiple entries, every scene resolves. ---
	var roster := MatchSetup.roster()
	if roster == null:
		failures.append("the roster resource failed to load")
	elif roster.entries.size() < 2:
		failures.append("the roster holds fewer than two entries (%d)" % roster.entries.size())
	else:
		var scenes: Array = []
		for i in roster.entries.size():
			var entry: BossEntry = roster.entries[i]
			if entry.scene == null:
				failures.append("roster entry %d has no scene" % i)
			elif entry.display_name.is_empty():
				failures.append("roster entry %d has no display name" % i)
			scenes.append(entry.scene)
		if scenes.size() >= 2 and scenes[0] == scenes[1]:
			failures.append("roster entries 0 and 1 point at the same scene (the variant must differ)")

	# --- B. Real path: title -> start_fight -> the boss select screen. ---
	MatchSetup.selected = null
	var title_scene: PackedScene = load(TITLE_SCENE)
	var title: Control = title_scene.instantiate()
	root.add_child(title)
	current_scene = title
	await _wait(5)
	title.start_fight()
	var select: Control = null
	for _i in 120:
		await physics_frame
		if current_scene != null and current_scene.name == "BossSelect":
			select = current_scene
			break
	if select == null:
		failures.append("start_fight did not swap to the boss select screen")

	# --- C. The screen + cycling: one card per entry, ui_right moves it. ---
	if select != null:
		if select._cards.size() != roster.entries.size():
			failures.append("the select screen built %d cards for %d entries" % [
				select._cards.size(), roster.entries.size(),
			])
		if select._index != 0:
			failures.append("the select screen did not start at the first entry")
		Input.parse_input_event(_key(KEY_RIGHT, true))
		await _wait(2)
		Input.parse_input_event(_key(KEY_RIGHT, false))
		await _wait(2)
		if select._index != 1:
			failures.append("ui_right did not move the selection (index %d)" % select._index)

		# --- D. Confirm -> the arena spawns the CHOSEN boss. ---
		var chosen: BossEntry = roster.entries[select._index]
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
			failures.append("confirm did not swap to the arena")
		else:
			await _wait(SETTLE_FRAMES)
			var boss = get_first_node_in_group("boss")
			if boss == null:
				failures.append("no boss spawned for the selected entry")
			elif boss.boss_title != chosen.display_name:
				failures.append("the arena spawned '%s' but '%s' was selected" % [
					boss.boss_title, chosen.display_name,
				])
			elif chosen.display_name == "SPARRING GLADIATOR" \
					and not is_equal_approx(float(boss.get_node("Health").max_health), 60.0):
				failures.append("the sparring variant lost its data override (max %.0f)" % [
					float(boss.get_node("Health").max_health),
				])
			if get_first_node_in_group("player") == null:
				failures.append("the player went missing after the boss swap")
			# free the scene-changed arena before the direct instantiation below
			current_scene.free()
			current_scene = null

	# --- E. Back navigation: boss select -> ui_cancel -> title. ---
	MatchSetup.selected = null
	var title2: Control = title_scene.instantiate()
	root.add_child(title2)
	current_scene = title2
	await _wait(5)
	title2.start_fight()
	var select2 := false
	for _i in 120:
		await physics_frame
		if current_scene != null and current_scene.name == "BossSelect":
			select2 = true
			break
	if not select2:
		failures.append("the second start_fight did not reach the boss select screen")
	else:
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

	# --- F. No selection: the arena keeps its scene-default New Gladiator. ---
	MatchSetup.selected = null
	var arena_scene: PackedScene = load("res://game/scenes/arena/arena.tscn")
	if arena_scene == null:
		failures.append("the arena scene failed to load")
	else:
		var arena := arena_scene.instantiate()
		root.add_child(arena)
		current_scene = arena
		await _wait(SETTLE_FRAMES)
		var default_boss = get_first_node_in_group("boss")
		if default_boss == null:
			failures.append("the default arena has no boss")
		elif default_boss.boss_title != "NEW GLADIATOR":
			failures.append("the no-selection default is '%s', not the scene's New Gladiator" % [
				default_boss.boss_title,
			])
		arena.free()

	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)

	if failures.is_empty():
		print("BOSS SELECT CHECK: PASS (roster data, title -> select -> cycle -> chosen boss spawns, back to title, no-selection default)")
		quit(0)
	else:
		for failure in failures:
			printerr("BOSS SELECT CHECK FAILURE: " + failure)
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
