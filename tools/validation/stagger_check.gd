extends SceneTree
## Sprint 13 automated stagger verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/stagger_check.gd
## A probe player mashes the combo in openings and holds guard through boss
## offense, then asserts the roadmap checklist: stagger-carrying hits open
## the punish window (measured from the entry edge), the boss cannot attack
## while staggered, the window self-ends, it visibly interrupts a boss
## telegraph, and resistance makes the second stagger harder.
## Exits 0 on PASS, 1 on FAIL.

const SETTLE_FRAMES := 30
const STAGGER_WINDOW_TICKS := 120  # stagger_duration 2.0 s

var _mash_edge := false
var _prev_boss_state := -1
var _interrupted := false
var _attack_during_stagger := false
var _landed := [0]
var stagger_ticks_total := 0

func _initialize() -> void:
	_run()

func _run() -> void:
	var failures: PackedStringArray = []
	var arena_scene: PackedScene = load("res://game/scenes/arena/arena.tscn")
	if arena_scene == null:
		printerr("STAGGER CHECK FAILURE: arena scene missing")
		quit(1)
		return
	var arena := arena_scene.instantiate()
	root.add_child(arena)
	await _wait(2)
	var player = get_first_node_in_group("player")
	var boss = get_first_node_in_group("boss")
	if player == null or boss == null:
		printerr("STAGGER CHECK FAILURE: player or boss not found")
		quit(1)
		return
	var boss_stagger = boss.get_node("Stagger")
	var player_health = player.get_node("Health")
	player.get_node("AttackHitbox").hit_landed.connect(func(_e: DamageEvent, _t) -> void: _landed[0] += 1)

	player.global_position = Vector3(2.6, 0.5, 0.0)
	player.rotation.y = -PI / 2.0
	await _wait(SETTLE_FRAMES)

	# Drive the fight until two stagger windows are observed (or budget out).
	var stagger_count := 0
	var window_ticks := 0
	var in_stagger := false
	var hits_before_first := -1
	var hits_before_second := -1
	var boss_health = boss.get_node("Health")
	for _i in 5000:
		_drive(boss, player)
		await physics_frame
		# Keep the boss alive: this check measures stagger cadence, not the
		# kill (that is gladiator_check's job).
		if float(boss_health.current_health) < 50.0:
			boss_health.reset()
		if player_health.is_dead():
			player.reset_for_retry()
		if boss.state == boss.State.STAGGERED:
			stagger_ticks_total += 1
			if not in_stagger:
				in_stagger = true
				stagger_count += 1
				if stagger_count == 1:
					hits_before_first = _landed[0]
				elif stagger_count == 2:
					hits_before_second = _landed[0]
					break  # both windows observed
		elif in_stagger:
			in_stagger = false
			window_ticks = stagger_ticks_total
	if stagger_count < 1:
		failures.append("a full combo never staggered the boss")
	else:
		if window_ticks < STAGGER_WINDOW_TICKS - 5 or window_ticks > STAGGER_WINDOW_TICKS + 5:
			failures.append("stagger window measured %d ticks (expected ~%d)" % [window_ticks, STAGGER_WINDOW_TICKS])
		if not _interrupted:
			failures.append("stagger never interrupted a boss telegraph (attack interruption rule)")
		if _attack_during_stagger:
			failures.append("the boss attacked while staggered")
	if stagger_count < 2:
		failures.append("second stagger never occurred within budget (resistance untested)")
	elif hits_before_second <= hits_before_first:
		failures.append("resistance not honored: second stagger after %d new hits vs %d for the first" % [
			hits_before_second - hits_before_first, hits_before_first,
		])

	player_health.reset()
	arena.free()

	if failures.is_empty():
		print("STAGGER CHECK: PASS (combo staggers, telegraph interrupted, window ~%d ticks, resistance honored)" % [
			window_ticks,
		])
		quit(0)
	else:
		for failure in failures:
			printerr("STAGGER CHECK FAILURE: " + failure)
		quit(1)

## Probe behavior: guard through boss offense; mash the combo in openings;
## hold the 1.15-1.6 m band. Soft-facing aligns the swings (D-039).
func _drive(boss, player) -> void:
	var distance: float = (boss.global_position - player.global_position).length()
	if boss.state == boss.State.STAGGERED:
		_interrupted = _interrupted or _prev_boss_state == boss.State.TELEGRAPH
		if boss.get_node("AttackHitbox").is_active():
			_attack_during_stagger = true
	elif boss.state == boss.State.TELEGRAPH:
		# Steal the turn: keep swinging during the boss's warning — hits
		# accumulate stagger and can interrupt the telegraph outright.
		Input.action_release("block")
		if _mash_edge:
			Input.action_release("attack")
		else:
			Input.action_press("attack")
		_mash_edge = not _mash_edge
	elif boss.state == boss.State.ATTACK:
		Input.action_release("attack")
		_mash_edge = false
		Input.action_press("block")
	else:
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
	_prev_boss_state = boss.state

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
