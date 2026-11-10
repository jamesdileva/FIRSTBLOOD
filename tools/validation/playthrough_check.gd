extends SceneTree
## Sprint 23 full-playthrough verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/playthrough_check.gd
## Drives the REAL scene flow end-to-end (change_scene paths included):
##   fresh install -> title -> start the fight -> the probe defeats the
##   gladiator (VICTORY) -> R resets -> the probe dies (DEFEAT) -> XP
##   consolation -> R -> T returns to the title. XP persists through the
##   whole loop. Exits 0 on PASS, 1 on FAIL.

const SETTLE_FRAMES := 30
const TITLE_SCENE := "res://game/scenes/ui/title_screen.tscn"

var _mash_edge := false

func _initialize() -> void:
	_run()

func _run() -> void:
	var failures: PackedStringArray = []
	# Fresh install: no check save.
	OS.set_environment("FIRSTBLOOD_CHECK_SAVE", "1")
	var check_save := ProjectSettings.globalize_path("user://check_save.json")
	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)

	# --- 1. Fresh install: the title loads as the current scene. ---
	var title_scene: PackedScene = load(TITLE_SCENE)
	var title: Control = title_scene.instantiate()
	root.add_child(title)
	current_scene = title
	await _wait(5)
	if title.get_node_or_null("Title") == null:
		failures.append("the title did not build its UI")

	# --- 2. start_fight -> the arena is the current scene. ---
	title.start_fight()
	var arena_ready := false
	for _i in 120:
		await physics_frame
		if current_scene != null and current_scene.name == "Arena":
			arena_ready = true
			break
	if not arena_ready:
		failures.append("start_fight did not swap to the arena")
	var player = get_first_node_in_group("player")
	var boss = get_first_node_in_group("boss")
	var flow = current_scene.get_node_or_null("MatchFlow") if current_scene != null else null
	if player == null or boss == null or flow == null:
		printerr("PLAYTHROUGH FAILURE: player/boss/flow missing after scene change")
		quit(1)
		return
	await _wait(SETTLE_FRAMES)
	var progression = player.get_node("Progression")

	# --- 3. The fight: the probe defeats the gladiator -> VICTORY. ---
	var xp_at_fight_start: float = float(progression.total_earned)
	var fight_ticks := 0
	while not boss.is_dead() and fight_ticks < 9000:
		_drive(boss, player)
		await physics_frame
		fight_ticks += 1
	if not boss.is_dead():
		failures.append("the probe did not defeat the gladiator in %d ticks" % fight_ticks)
	var victory_seen := await _wait_for_state(flow, flow.MatchState.VICTORY, 200)
	if not victory_seen:
		failures.append("the boss's death did not reach the VICTORY state (state %s)" % [
			flow.MatchState.keys()[flow.state],
		])
	if float(progression.total_earned) <= xp_at_fight_start:
		failures.append("the victory did not award XP")
	if progression.level < 1:
		failures.append("level regressed")
	if progression.level < 2:
		failures.append("the first victory did not reach level 2 (total %.0f)" % float(progression.total_earned))

	# --- 4. R on the victory overlay resets both sides. ---
	Input.parse_input_event(_retry_key(true))
	await _wait(2)
	Input.parse_input_event(_retry_key(false))
	var running_seen := await _wait_for_state(flow, flow.MatchState.RUNNING, 200)
	await _wait(SETTLE_FRAMES)
	if not running_seen:
		failures.append("R on the VICTORY overlay did not return to RUNNING")
	if boss.is_dead() or player.is_dead():
		failures.append("R on the overlay did not revive both sides")

	# --- 5. The probe dies -> DEFEAT + consolation XP. ---
	var xp_before_defeat: float = float(progression.total_earned)
	player.get_node("Health").apply_damage(_lethal())
	var defeat_seen := await _wait_for_state(flow, flow.MatchState.DEFEAT, 200)
	if not defeat_seen:
		failures.append("the player's death did not reach the DEFEAT state (state %s)" % [
			flow.MatchState.keys()[flow.state],
		])
	if float(progression.total_earned) != xp_before_defeat + 25.0:
		failures.append("the defeat consolation wrong: %.1f (expected +25)" % float(progression.total_earned))

	# --- 6. T returns to the title (the REAL scene-change path). ---
	var to_title_key := InputEventKey.new()
	to_title_key.physical_keycode = 84
	to_title_key.keycode = 84
	to_title_key.pressed = true
	Input.parse_input_event(to_title_key)
	await _wait(2)
	var release_t := InputEventKey.new()
	release_t.physical_keycode = 84
	release_t.keycode = 84
	release_t.pressed = false
	Input.parse_input_event(release_t)
	var title_back := false
	for _i in 120:
		await physics_frame
		if current_scene != null and current_scene.name == "TitleScreen":
			title_back = true
			break
	if not title_back:
		failures.append("T did not return to the title scene")

	# --- 7. XP persisted through the whole loop (the versioned save). ---
	var save: Dictionary = ProgressionComponent.read_save()
	if save.is_empty():
		failures.append("the save file is missing or unreadable")
	elif int(save.get("level", 1)) < 2:
		failures.append("the save did not persist the level (level %s)" % save.get("level"))

	# cleanup the check save for the next run
	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)

	if failures.is_empty():
		print("PLAYTHROUGH: PASS (fresh title -> fight %d ticks -> VICTORY+XP -> R reset -> DEFEAT+consolation -> T to title -> save persisted)" % [
			fight_ticks,
		])
		quit(0)
	else:
		for failure in failures:
			printerr("PLAYTHROUGH FAILURE: " + failure)
		quit(1)

## The batch-1 probe: block through boss offense, mash in openings, hold the
## 1.15-1.6 m band. Soft-facing aligns the swings (D-039).
func _drive(boss, player) -> void:
	var distance: float = (boss.global_position - player.global_position).length()
	if boss.state == boss.State.STAGGERED:
		Input.action_release("block")
		if _mash_edge:
			Input.action_release("attack")
		else:
			Input.action_press("attack")
		_mash_edge = not _mash_edge
		return
	if boss.state == boss.State.TELEGRAPH or boss.state == boss.State.ATTACK:
		Input.action_release("attack")
		_mash_edge = false
		Input.action_press("block")
		return
	Input.action_release("block")
	if distance > 1.6:
		Input.action_release("attack")
		_mash_edge = false
		Input.action_press("move_right")
		Input.action_release("move_left")
	elif distance < 1.15:
		Input.action_release("attack")
		_mash_edge = false
		Input.action_press("move_left")
		Input.action_release("move_right")
	else:
		Input.action_release("move_right")
		Input.action_release("move_left")
		if _mash_edge:
			Input.action_release("attack")
		else:
			Input.action_press("attack")
		_mash_edge = not _mash_edge

func _retry_key(pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = 82
	event.keycode = 82
	event.pressed = pressed
	return event

func _lethal() -> DamageEvent:
	var event := DamageEvent.new()
	event.amount = 1000.0
	return event

func _wait_for_state(flow, target, max_frames: int) -> bool:
	for _i in max_frames:
		if flow.state == target:
			return true
		await physics_frame
	return false

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
