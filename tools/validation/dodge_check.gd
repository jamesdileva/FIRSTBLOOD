extends SceneTree
## Sprint 03 automated dodge verification (headless). Run from the project root:
##   cmd //c godot --headless --path . -s res://tools/validation/dodge_check.gd
## Drives the real arena scene with synthesized input and asserts the roadmap's
## dodge checklist: faster than walking, intended direction, i-frames bounded
## to travel, commitment not bypassable by input spam, recovery observable and
## vulnerable, slides around the boss, no boundary tunneling. Exits 0 on PASS.

const SETTLE_FRAMES := 30
const TRAVEL_POLL_FRAMES := 25     # travel is 15 ticks at 60 Hz
const SPAM_ITERATIONS := 110       # 2 ticks per iteration ≈ 3.7 s of mashing
const COMMITMENT_MIN_TICKS := 22   # travel (15) + recovery (9) = 24 nominal (D-018)

func _initialize() -> void:
	_run()

func _run() -> void:
	var failures: PackedStringArray = []
	var arena_scene: PackedScene = load("res://game/scenes/arena/arena.tscn")
	if arena_scene == null:
		printerr("DODGE CHECK FAILURE: arena scene missing")
		quit(1)
		return
	var arena := arena_scene.instantiate()
	root.add_child(arena)
	await _wait(SETTLE_FRAMES)
	# Untyped on purpose: reads script members Godot's CharacterBody3D lacks.
	var player = get_first_node_in_group("player")
	if player == null:
		printerr("DODGE CHECK FAILURE: player not found")
		quit(1)
		return

	# --- 1. Neutral dodge: backward, faster than walk, i-frames bounded. ---
	var start: Vector3 = player.global_position
	await _dodge_tap()
	var peak_speed := 0.0
	var saw_dodge := false
	var invuln_early := false
	var invuln_cleared := false
	for _i in TRAVEL_POLL_FRAMES:
		await physics_frame
		peak_speed = maxf(peak_speed, Vector3(player.velocity.x, 0.0, player.velocity.z).length())
		if player.state == player.State.DODGE:
			saw_dodge = true
			if player.is_invulnerable():
				invuln_early = true
			if player.state_elapsed > player.dodge_invulnerability and not player.is_invulnerable():
				invuln_cleared = true
	if not saw_dodge:
		failures.append("dodge input never entered DODGE state")
	else:
		if peak_speed <= player.movement_speed:
			failures.append("dodge peak %.2f m/s not faster than walk %.2f" % [peak_speed, player.movement_speed])
		if not invuln_early:
			failures.append("no i-frames at dodge start")
		if not invuln_cleared:
			failures.append("i-frames did not clear before travel ended")
	var travel: Vector3 = player.global_position - start
	var flat := Vector3(travel.x, 0.0, travel.z)
	if flat.length() < 2.5:
		failures.append("neutral dodge traveled only %.2f m" % flat.length())
	elif flat.normalized().dot(Vector3(0.0, 0.0, 1.0)) < 0.8:
		failures.append("neutral dodge not backward relative to camera: %s" % flat)
	await _settle_player(player, Vector3(-4.0, 0.5, 0.0))

	# --- 2. Spamming dodge cannot bypass travel+recovery commitment. ---
	var entry_frames: Array[int] = []
	var in_dodge := false
	var tick := 0
	for _i in SPAM_ITERATIONS:
		Input.action_press("dodge")
		await physics_frame
		tick += 1
		Input.action_release("dodge")
		await physics_frame
		tick += 1
		if player.state == player.State.DODGE and not in_dodge:
			entry_frames.append(tick)
			in_dodge = true
		elif player.state != player.State.DODGE:
			in_dodge = false
	if entry_frames.is_empty():
		failures.append("spam run never dodged")
	for i in range(1, entry_frames.size()):
		var gap: int = entry_frames[i] - entry_frames[i - 1]
		if gap < COMMITMENT_MIN_TICKS:
			failures.append("re-dodge entered after only %d ticks (commitment violated)" % gap)
	await _settle_player(player, Vector3(-4.0, 0.5, 0.0))

	# --- 3. Recovery observable and vulnerable. ---
	await _dodge_tap()
	var saw_recovery := false
	var recovery_vulnerable := true
	for _i in 45:
		await physics_frame
		if player.state == player.State.DODGE_RECOVERY:
			saw_recovery = true
			if player.is_invulnerable():
				recovery_vulnerable = false
	if not saw_recovery:
		failures.append("DODGE_RECOVERY never observed (debug output gap)")
	if not recovery_vulnerable:
		failures.append("player invulnerable during recovery")
	await _settle_player(player, Vector3(4.0, 0.5, -1.0))

	# --- 4. Dodge slides around the boss placeholder. ---
	var side_start: Vector3 = player.global_position
	Input.action_press("move_right")
	await _wait(1)
	Input.action_press("dodge")
	await _wait(1)
	Input.action_release("dodge")
	await _wait(30)
	Input.action_release("move_right")
	var side_travel: Vector3 = player.global_position - side_start
	if side_travel.x < 2.0:
		failures.append("dodge past boss blocked: lateral %.2f m" % side_travel.x)
	await _settle_player(player, Vector3(17.0, 0.5, 0.0))

	# --- 5. Dodge cannot tunnel through the arena boundary. ---
	Input.action_press("move_right")
	await _wait(1)
	Input.action_press("dodge")
	await _wait(1)
	Input.action_release("dodge")
	await _wait(30)
	Input.action_release("move_right")
	if absf(player.global_position.x) > player.arena_half_extent + 0.5:
		failures.append("dodge tunneled the arena boundary: %s" % player.global_position)

	arena.free()

	if failures.is_empty():
		print("DODGE CHECK: PASS (peak %.1f m/s, spam entries %d, lateral past boss %.2f m)" % [
			peak_speed, entry_frames.size(), side_travel.x,
		])
		quit(0)
	else:
		for failure in failures:
			printerr("DODGE CHECK FAILURE: " + failure)
		quit(1)

func _dodge_tap() -> void:
	Input.action_press("dodge")
	await _wait(2)
	Input.action_release("dodge")

func _settle_player(player, pos: Vector3) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	await _wait(SETTLE_FRAMES)

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
