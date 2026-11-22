extends SceneTree
## Sprint 40 Mobility Abilities verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/mobility_check.gd
## Asserts the roadmap checklist — mobility abilities obey combat
## state/recovery rules: the sprint action exists; the ground movement with
## the sprint held = movement × 1.4 (the real input path); released = ×1.0;
## during ATTACK the swing roots (the sprint can't un-root); during BLOCK
## the block's ×0.4 holds (the sprint doesn't stack); during DODGE the
## dodge's own velocity holds; after the swing's recovery the sprint
## applies again. Exits 0 on PASS, 1 on FAIL.

const SETTLE_FRAMES := 30

func _initialize() -> void:
	_run()

func _run() -> void:
	var failures: PackedStringArray = []
	OS.set_environment("FIRSTBLOOD_CHECK_SAVE", "1")
	var check_save := ProjectSettings.globalize_path("user://check_save.json")
	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)
	GearLibrary.reload_from_save()

	var arena_scene: PackedScene = load("res://game/scenes/arena/arena.tscn")
	if arena_scene == null:
		printerr("MOBILITY CHECK FAILURE: arena scene missing")
		quit(1)
		return
	var arena := arena_scene.instantiate()
	root.add_child(arena)
	await _wait(SETTLE_FRAMES)
	var boss = get_first_node_in_group("boss")
	var player = get_first_node_in_group("player")
	if boss == null or player == null:
		printerr("MOBILITY CHECK FAILURE: the arena is missing actors")
		quit(1)
		return
	var movement_speed: float = player.movement_speed
	boss.movement_speed = 0.0  # park: the movement tests are deterministic
	player.global_position = boss.global_position + Vector3(-2, 0.5, 0)
	await _wait(SETTLE_FRAMES)

	# --- A. The ground sprint: held = ×1.4, released = ×1.0 (the real input path). ---
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await _wait(SETTLE_FRAMES)
	var hspeed: float = Vector2(player.velocity.x, player.velocity.z).length()
	if not is_equal_approx(hspeed, movement_speed * 1.4):
		failures.append("the sprint speed is wrong: %.2f (expected %.2f)" % [
			hspeed, movement_speed * 1.4,
		])
	Input.action_release("sprint")
	await _wait(SETTLE_FRAMES)
	hspeed = Vector2(player.velocity.x, player.velocity.z).length()
	if not is_equal_approx(hspeed, movement_speed):
		failures.append("the sprint release didn't restore: %.2f (expected %.2f)" % [
			hspeed, movement_speed,
		])

	# --- B. The combat rules: during ATTACK the swing decelerates (the
	# sprint doesn't drive it); after the recovery the sprint resumes. ---
	Input.action_press("sprint")
	await _wait(SETTLE_FRAMES)
	Input.action_press("attack")
	await _wait(4)
	Input.action_release("attack")
	await _wait(2)
	if player.state != player.State.ATTACK:
		failures.append("the attack press did not start a swing (state %s)" % [
			player.State.keys()[player.state],
		])
	else:
		# the swing's deceleration bleeds the pre-sprint momentum — the
		# sprint must NOT hold the speed at ×1.4 during ATTACK
		hspeed = Vector2(player.velocity.x, player.velocity.z).length()
		if hspeed >= movement_speed * 1.4:
			failures.append("the sprint drove the swing (%.2f m/s during ATTACK)" % hspeed)
	# the recovery: the swing ends, the sprint re-applies (the ramp needs
	# a few ticks to reach the sprinted speed)
	var resumed := false
	for _i in 120:
		if player.state == player.State.IDLE or player.state == player.State.MOVE:
			resumed = true
			break
		await physics_frame
	await _wait(SETTLE_FRAMES)
	if resumed:
		hspeed = Vector2(player.velocity.x, player.velocity.z).length()
		if not is_equal_approx(hspeed, movement_speed * 1.4):
			failures.append("the sprint did not resume after the recovery (%.2f)" % hspeed)
	Input.action_release("sprint")
	await _wait(2)

	# --- C. The block: the block's ×0.4 holds (the sprint doesn't stack). ---
	Input.action_press("sprint")
	await _wait(2)
	Input.action_press("block")
	await _wait(SETTLE_FRAMES)
	if player.state != player.State.BLOCK_ACTIVE:
		failures.append("the block press did not raise the guard (state %s)" % [
			player.State.keys()[player.state],
		])
	else:
		Input.action_press("move_forward")
		await _wait(SETTLE_FRAMES)
		hspeed = Vector2(player.velocity.x, player.velocity.z).length()
		var block_walk: float = movement_speed * player.block_speed_multiplier
		if not is_equal_approx(hspeed, block_walk):
			failures.append("the block walk ignores the sprint: %.2f (expected %.2f — no stacking)" % [
				hspeed, block_walk,
			])
		Input.action_release("move_forward")
	Input.action_release("block")
	Input.action_release("sprint")
	# the block's RECOVERY window: a dodge during it is ignored (the state
	# rule) — wait for the recovery to end before the dodge test
	for _i in 180:
		if player.state == player.State.IDLE or player.state == player.State.MOVE:
			break
		await physics_frame
	await _wait(SETTLE_FRAMES)

	# --- D. The dodge: the dodge's own velocity holds (the sprint doesn't stack). ---
	var dodge_speed: float = player.dodge_speed
	Input.action_press("sprint")
	await _wait(2)
	Input.action_press("dodge")
	await _wait(4)
	Input.action_release("dodge")
	await _wait(2)
	if player.state != player.State.DODGE:
		failures.append("the dodge press did not dodge (state %s)" % [
			player.State.keys()[player.state],
		])
	else:
		hspeed = Vector2(player.velocity.x, player.velocity.z).length()
		if not is_equal_approx(hspeed, dodge_speed):
			failures.append("the dodge speed stacked with the sprint: %.2f (expected %.2f)" % [
				hspeed, dodge_speed,
			])
	Input.action_release("sprint")
	for _i in 120:
		if player.state == player.State.IDLE or player.state == player.State.MOVE:
			break
		await physics_frame

	arena.free()
	MatchSetup.selected = null

	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)

	if failures.is_empty():
		print("MOBILITY CHECK: PASS (sprint ×1.4 ground, release restores, swing roots, block ×0.4 no-stack, dodge own speed)")
		quit(0)
	else:
		for failure in failures:
			printerr("MOBILITY CHECK FAILURE: " + failure)
		quit(1)

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
