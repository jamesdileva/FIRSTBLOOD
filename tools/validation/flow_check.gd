extends SceneTree
## Sprint 22 automated match-flow verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/flow_check.gd
## Asserts the roadmap checklist: the player's death leads to the DEFEAT
## overlay, the boss's death to VICTORY, R resets both sides (the real
## physical key path), the overlays hide, pause freezes combat without
## breaking state, and to_title exists for the overlay path. Exits 0 on
## PASS, 1 on FAIL.

const SETTLE_FRAMES := 30
const DEFEAT_DELAY_TICKS := 72  # defeat_delay 1.2 s

var failures: PackedStringArray = []

func _initialize() -> void:
	_run()

func _run() -> void:
	OS.set_environment("FIRSTBLOOD_CHECK_SAVE", "1")
	if FileAccess.file_exists("user://check_save.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://check_save.json"))
	var arena_scene: PackedScene = load("res://game/scenes/arena/arena.tscn")
	if arena_scene == null:
		printerr("FLOW CHECK FAILURE: arena scene missing")
		quit(1)
		return
	var arena := arena_scene.instantiate()
	root.add_child(arena)
	await _wait(2)
	var player = get_first_node_in_group("player")
	var boss = get_first_node_in_group("boss")
	if player == null or boss == null:
		printerr("FLOW CHECK FAILURE: player or boss not found")
		quit(1)
		return
	var flow = arena.get_node_or_null("MatchFlow")
	if flow == null:
		printerr("FLOW CHECK FAILURE: MatchFlow missing")
		quit(1)
		return
	var player_health = player.get_node("Health")
	var boss_health = boss.get_node("Health")
	var defeat_panel: Control = flow.get_node("MatchOver/DefeatPanel")
	var victory_panel: Control = flow.get_node("MatchOver/VictoryPanel")
	var pause_panel: Control = flow.get_node("MatchOver/PausePanel")
	player.global_position = boss.global_position + Vector3(-1.4, 0.5, 0)
	await _wait(SETTLE_FRAMES)

	# --- A. The player's death leads to the DEFEAT overlay. ---
	player_health.apply_damage(_lethal())
	var defeat_seen := await _wait_for_state(flow, flow.MatchState.DEFEAT, 200)
	if not defeat_seen:
		failures.append("the player's death did not reach the DEFEAT state")
	elif not defeat_panel.visible:
		failures.append("the DEFEAT state reached but the panel is hidden")

	# --- B. R resets both sides (the real physical key path). ---
	Input.parse_input_event(_retry_key(true))
	await _wait(2)
	Input.parse_input_event(_retry_key(false))
	await _wait(SETTLE_FRAMES)
	if flow.state != flow.MatchState.RUNNING:
		failures.append("R on the DEFEAT overlay did not return to RUNNING")
	if defeat_panel.visible:
		failures.append("the DEFEAT panel stayed visible after R")
	if player.is_dead() or boss.is_dead():
		failures.append("R on the overlay did not revive both sides")
	if not is_equal_approx(float(player_health.current_health), float(player.get_node("Health").max_health)):
		failures.append("the player's health was not restored by R")

	# --- C. The boss's death leads to the VICTORY overlay. ---
	boss_health.apply_damage(_lethal())
	var victory_seen := await _wait_for_state(flow, flow.MatchState.VICTORY, 200)
	if not victory_seen:
		failures.append("the boss's death did not reach the VICTORY state")
	elif not victory_panel.visible:
		failures.append("the VICTORY state reached but the panel is hidden")

	# --- D. R resets again. ---
	Input.parse_input_event(_retry_key(true))
	await _wait(2)
	Input.parse_input_event(_retry_key(false))
	await _wait(SETTLE_FRAMES)
	if flow.state != flow.MatchState.RUNNING:
		failures.append("R on the VICTORY overlay did not return to RUNNING")
	if victory_panel.visible:
		failures.append("the VICTORY panel stayed visible after R")
	if boss.is_dead():
		failures.append("R on the VICTORY overlay did not revive the boss")

	# --- E. Pause freezes combat without breaking state. ---
	Input.action_press("pause")
	await _wait(2)
	Input.action_release("pause")
	await _wait(2)
	if not paused:
		failures.append("the pause action did not pause the tree")
	elif not pause_panel.visible:
		failures.append("the pause panel is not visible while paused")
	var boss_elapsed_frozen: float = float(boss.state_elapsed)
	await _wait(SETTLE_FRAMES)
	if float(boss.state_elapsed) != boss_elapsed_frozen:
		failures.append("combat state kept ticking while paused (pause cannot break combat state)")
	Input.action_press("pause")
	await _wait(2)
	Input.action_release("pause")
	await _wait(2)
	if paused:
		failures.append("the tree stayed paused after the resume press")

	# --- F. to_title exists for the overlay path (not scene-changed in -s). ---
	if not flow.has_method("to_title"):
		failures.append("MatchFlow lacks to_title")

	player.reset_for_retry()
	boss.reset()
	arena.free()

	if failures.is_empty():
		print("FLOW CHECK: PASS (defeat, victory, R resets both, pause freezes and resumes cleanly)")
		quit(0)
	else:
		for failure in failures:
			printerr("FLOW CHECK FAILURE: " + failure)
		quit(1)

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
