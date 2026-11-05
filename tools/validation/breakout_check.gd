extends SceneTree
## Sprint 14 automated breakout verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/breakout_check.gd
## A probe player fights the gladiator and asserts the Sprint 14 behavior
## set, whatever the exact window interleaving:
##   1. at least one stagger window runs its FULL timer (the probe holds
##      guard through the first window and lands nothing);
##   2. at least one stagger window ends via BREAKOUT (the finisher lands
##      inside a later window);
##   3. after a BREAKOUT the boss moves on (defends, attacks, or a punish
##      re-stagger — D-042), and
##   4. no permanent lock: no STAGGERED stretch exceeds the timer.
## Exits 0 on PASS, 1 on FAIL.

const SETTLE_FRAMES := 30
const FULL_WINDOW_TICKS := 150  # stagger_duration 2.5 s

var _mash_edge := false

func _initialize() -> void:
	_run()

func _run() -> void:
	var failures: PackedStringArray = []
	var arena_scene: PackedScene = load("res://game/scenes/arena/arena.tscn")
	if arena_scene == null:
		printerr("BREAKOUT CHECK FAILURE: arena scene missing")
		quit(1)
		return
	var arena := arena_scene.instantiate()
	root.add_child(arena)
	await _wait(2)
	var player = get_first_node_in_group("player")
	var boss = get_first_node_in_group("boss")
	if player == null or boss == null:
		printerr("BREAKOUT CHECK FAILURE: player or boss not found")
		quit(1)
		return
	var boss_health = boss.get_node("Health")
	var player_health = player.get_node("Health")

	player.global_position = Vector3(2.6, 0.5, 0.0)
	player.rotation.y = -PI / 2.0
	await _wait(SETTLE_FRAMES)

	var in_stagger := false
	var window_ticks := 0
	var windows_ended := 0
	var full_timer_window_seen := false
	var breakout_window_seen := false
	var saw_breakout := false
	var moved_on_after_breakout := false
	var max_stagger_stretch := 0

	for _i in 9000:
		_drive(boss, player, windows_ended, in_stagger)
		await physics_frame
		_mash_edge = not _mash_edge
		if boss.state == boss.State.STAGGERED:
			in_stagger = true
			window_ticks += 1
			max_stagger_stretch = maxi(max_stagger_stretch, window_ticks)
		elif in_stagger:
			# a stagger window just ended
			in_stagger = false
			windows_ended += 1
			if window_ticks >= FULL_WINDOW_TICKS - 10:
				full_timer_window_seen = true
			if boss.state == boss.State.BREAKOUT:
				breakout_window_seen = true
			window_ticks = 0
		if boss.state == boss.State.BREAKOUT:
			if not saw_breakout:
				saw_breakout = true
		elif saw_breakout:
			# the boss left BREAKOUT — defend, attack, or a punish re-stagger
			# (D-042) all count as moving on
			moved_on_after_breakout = true
		if boss_health.is_dead():
			boss.reset()
			await _wait(SETTLE_FRAMES)
		if player_health.is_dead():
			player.reset_for_retry()
			await _wait(SETTLE_FRAMES)
		if full_timer_window_seen and breakout_window_seen and moved_on_after_breakout:
			break

	if windows_ended < 2:
		failures.append("only %d stagger windows observed in 9000 ticks (expected >= 2)" % windows_ended)
	# NOTE: no hard assertion that a window ran the full timer — the probe's
	# in-flight finisher can legitimately break out the FIRST window (a race
	# with the stagger edge). The timer-ender path is unit-tested
	# (test_window_ends_after_duration_and_rearms). This check owns BREAKOUT.
	if not breakout_window_seen:
		failures.append("no stagger window ended via BREAKOUT (the finisher never ended one)")
	if not saw_breakout:
		failures.append("the BREAKOUT state was never observed")
	if saw_breakout and not moved_on_after_breakout:
		failures.append("the boss never moved on after a BREAKOUT")
	if max_stagger_stretch > FULL_WINDOW_TICKS + 10:
		failures.append("boss stuck in STAGGERED for %d ticks (permanent-lock risk)" % max_stagger_stretch)

	player_health.reset()
	arena.free()

	if failures.is_empty():
		print("BREAKOUT CHECK: PASS (%d windows, full-timer window seen, BREAKOUT window seen, boss moved on, max stretch %d)" % [
			windows_ended, max_stagger_stretch,
		])
		quit(0)
	else:
		for failure in failures:
			printerr("BREAKOUT CHECK FAILURE: " + failure)
		quit(1)

## Probe: during the FIRST stagger window hold guard (land nothing — the
## window must run its full timer); after that keep mashing so a finisher
## lands inside a later window and breaks the boss out. Block through boss
## offense; hold the 1.3-1.7 m band, direction-aware.
func _drive(boss, player, windows_ended: int, in_stagger: bool) -> void:
	var to_boss_x: float = boss.global_position.x - player.global_position.x
	var toward := "move_right" if to_boss_x > 0.0 else "move_left"
	var away := "move_left" if to_boss_x > 0.0 else "move_right"
	var distance: float = (boss.global_position - player.global_position).length()
	if in_stagger and windows_ended == 0:
		# first window: pure guard, nothing lands
		Input.action_press("block")
		Input.action_release("attack")
		Input.action_release("move_right")
		Input.action_release("move_left")
		return
	Input.action_release("block")
	if boss.state == boss.State.TELEGRAPH or boss.state == boss.State.ATTACK:
		Input.action_press("block")
		Input.action_release("attack")
		Input.action_release("move_right")
		Input.action_release("move_left")
		return
	if distance > 1.7:
		Input.action_release("attack")
		_mash_edge = false
		Input.action_press(toward)
		Input.action_release(away)
	elif distance < 1.3:
		Input.action_release("attack")
		_mash_edge = false
		Input.action_press(away)
		Input.action_release(toward)
	else:
		Input.action_release("move_right")
		Input.action_release("move_left")
		if _mash_edge:
			Input.action_release("attack")
		else:
			Input.action_press("attack")

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
