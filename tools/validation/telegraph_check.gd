extends SceneTree
## Sprint 11 automated telegraph verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/telegraph_check.gd
## The boss AI runs (like boss_check). Asserts the roadmap checklist: a
## telegraph state precedes every attack and the hit lands only after it,
## per-attack warning durations are measurable and different (light 0.4 s,
## heavy 0.7 s), and a target leaving range cancels the telegraph into its
## cooldown. Sprint 12: the player holds the 1.3-1.7 m band — the boss
## lunges, and the heavy's 1.2 m minimum needs the spacing. Exits 0 on PASS.

const SETTLE_FRAMES := 30
const LIGHT_TELEGRAPH_TICKS := 24  # 0.4 s
const HEAVY_TELEGRAPH_TICKS := 42  # 0.7 s

func _initialize() -> void:
	_run()

func _run() -> void:
	# D-065 save isolation: checks never touch the user's real save.
	OS.set_environment("FIRSTBLOOD_CHECK_SAVE", "1")
	if FileAccess.file_exists("user://check_save.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://check_save.json"))
	var failures: PackedStringArray = []
	var arena_scene: PackedScene = load("res://game/scenes/arena/arena.tscn")
	if arena_scene == null:
		printerr("TELEGRAPH CHECK FAILURE: arena scene missing")
		quit(1)
		return
	var arena := arena_scene.instantiate()
	root.add_child(arena)
	await _wait(2)  # deferred tree entry: ready + group index flush
	var player = get_first_node_in_group("player")
	var boss = get_first_node_in_group("boss")
	if player == null or boss == null:
		printerr("TELEGRAPH CHECK FAILURE: player or boss not found")
		quit(1)
		return
	var player_taken: Array[DamageEvent] = []
	var taken_frames: Array[int] = []
	# "Landed" = the attack connected, blocked or not — the probe holds guard.
	player.hit_taken.connect(func(event: DamageEvent) -> void:
		player_taken.append(event)
		taken_frames.append(Engine.get_physics_frames()))
	player.hit_blocked.connect(func(event: DamageEvent) -> void:
		player_taken.append(event)
		taken_frames.append(Engine.get_physics_frames()))
	player.hit_mitigated.connect(func(event: DamageEvent) -> void:
		player_taken.append(event)
		taken_frames.append(Engine.get_physics_frames()))

	# Stand where BOTH attacks can reach the player (light 1.0-2.5, heavy 1.2-2.4).
	player.global_position = Vector3(2.6, 0.5, 0.0)
	player.velocity = Vector3.ZERO
	await _wait(SETTLE_FRAMES)

	# --- 1. A telegraph precedes the impact: state sequence + timing. ---
	# Leave any in-progress telegraph first so the measurement starts at the
	# entry edge, never mid-window.
	await _spacing_wait_while_state(boss, player, boss.State.TELEGRAPH, 120)
	if not await _spacing_wait_for_state(boss, player, boss.State.TELEGRAPH, 400):
		failures.append("boss never entered the TELEGRAPH state in range")
	else:
		# The observed telegraph may be any string step — assert against the
		# attack's OWN data. A cancel (target left range) re-arms the
		# measurement instead of failing: the cancel itself is Sprint 11
		# behavior and is asserted separately in phase 3.
		var measured := false
		for _attempt in 3:
			var expected_ticks := int(round(float(boss._current_attack.telegraph_duration) * 60.0))
			var telegraph_start: int = Engine.get_physics_frames()
			# Discard hits from any swing already in flight before this window.
			player_taken.clear()
			taken_frames.clear()
			var canceled := false
			while true:
				_apply_spacing(boss, player)
				await physics_frame
				if boss.state == boss.State.TELEGRAPH:
					continue  # still warning
				if boss.state == boss.State.ATTACK:
					break  # hit window reached
				canceled = true  # interrupted/reselected: re-arm
				break
			if canceled:
				continue
			var attack_start: int = Engine.get_physics_frames()
			if attack_start - telegraph_start < expected_ticks - 3:
				failures.append("attack began before its telegraph finished (gap %d < %d ticks)" % [
					attack_start - telegraph_start, expected_ticks,
				])
			var hit_after_warning := false
			for _i in 200:
				_apply_spacing(boss, player)
				await physics_frame
				if not player_taken.is_empty():
					hit_after_warning = taken_frames[0] - telegraph_start >= expected_ticks - 3
					break
			if player_taken.is_empty():
				failures.append("no attack landed after the telegraph")
			elif not hit_after_warning:
				failures.append("impact landed before the telegraph window had elapsed")
			measured = true
			break
		if not measured:
			failures.append("no clean telegraph-to-attack sequence in 3 attempts")

	# --- 2. Per-attack telegraph durations are measurable and distinct. ---
	var light_durations: Array[int] = []
	var heavy_durations: Array[int] = []
	var current_id: StringName = &""
	var current_start := 0
	var in_telegraph := false
	for _i in 2000:
		_apply_spacing(boss, player)
		await physics_frame
		if _i == 1000 or _i == 1800:
			# Guarantee a heavy selection: put the light string on cooldown so
			# the heavy (weight 1 vs light 3) is the only candidate.
			boss._cooldowns.clear()
			boss._cooldowns[&"boss_light"] = 3.0
			boss._cooldowns[&"boss_light_2"] = 3.0
		if boss.state == boss.State.TELEGRAPH:
			if not in_telegraph:
				in_telegraph = true
				current_start = Engine.get_physics_frames()
				current_id = boss._current_attack.attack_id
		elif in_telegraph:
			in_telegraph = false
			var duration: int = Engine.get_physics_frames() - current_start
			if current_id == &"boss_light":
				light_durations.append(duration)
			elif current_id == &"boss_heavy":
				heavy_durations.append(duration)
		if not light_durations.is_empty() and not heavy_durations.is_empty():
			break
	if light_durations.is_empty():
		failures.append("no light-attack telegraph observed in 2000 ticks")
	else:
		var duration: int = light_durations[0]
		if duration < LIGHT_TELEGRAPH_TICKS - 4 or duration > LIGHT_TELEGRAPH_TICKS + 4:
			failures.append("light telegraph measured %d ticks (expected ~%d)" % [duration, LIGHT_TELEGRAPH_TICKS])
	if heavy_durations.is_empty():
		failures.append("no heavy-attack telegraph observed in 2000 ticks")
	else:
		var duration: int = heavy_durations[0]
		if duration < HEAVY_TELEGRAPH_TICKS - 4 or duration > HEAVY_TELEGRAPH_TICKS + 4:
			failures.append("heavy telegraph measured %d ticks (expected ~%d)" % [duration, HEAVY_TELEGRAPH_TICKS])

	# --- 3. Leaving range during the warning cancels it, with a cooldown. ---
	var player_health = player.get_node_or_null("Health")
	if player_health != null and player_health.is_dead():
		player.reset_for_retry()
		await _wait(SETTLE_FRAMES)
	await _spacing_wait_for_state(boss, player, boss.State.TELEGRAPH, 400)
	player.global_position = Vector3(-14.0, 0.5, 0.0)  # far outside every range
	player.velocity = Vector3.ZERO
	var cancelled := false
	var reattacked := false
	for _i in 15:
		await physics_frame
		if boss.state == boss.State.OBSERVE:
			cancelled = true
			break
	if not cancelled:
		failures.append("telegraph did not cancel when the target left range (state %s)" % boss.state)
	for _i in 120:
		await physics_frame
		if boss.state == boss.State.ATTACK or boss.state == boss.State.TELEGRAPH:
			reattacked = true
			break
	if reattacked:
		failures.append("canceled attack did not respect its cooldown")

	player_taken.clear()
	taken_frames.clear()
	arena.free()

	if failures.is_empty():
		print("TELEGRAPH CHECK: PASS (warning precedes impact, light ~%d ticks, heavy ~%d ticks, range cancel + cooldown)" % [
			LIGHT_TELEGRAPH_TICKS, HEAVY_TELEGRAPH_TICKS,
		])
		quit(0)
	else:
		for failure in failures:
			printerr("TELEGRAPH CHECK FAILURE: " + failure)
		quit(1)

## Wait for a state while holding the 1.3-1.7 m spacing band (the boss
## lunges; without this it closes to contact and the heavy goes unreachable).
func _spacing_wait_for_state(boss, player, target, max_frames: int) -> bool:
	for _i in max_frames:
		_apply_spacing(boss, player)
		if boss.state == target:
			return true
		await physics_frame
	return false

func _spacing_wait_while_state(boss, player, state, max_frames: int) -> void:
	for _i in max_frames:
		_apply_spacing(boss, player)
		if boss.state != state:
			return
		await physics_frame

func _apply_spacing(boss, player) -> void:
	# Direction-aware: the boss's lunge can carry it past the player, so
	# "toward"/"away" must follow the actual side, not the camera.
	var to_boss_x: float = boss.global_position.x - player.global_position.x
	var toward := "move_right" if to_boss_x > 0.0 else "move_left"
	var away := "move_left" if to_boss_x > 0.0 else "move_right"
	# Hold guard through boss offense: the probe must survive the run.
	if boss.state == boss.State.TELEGRAPH or boss.state == boss.State.ATTACK:
		Input.action_press("block")
	else:
		Input.action_release("block")
	var distance: float = (boss.global_position - player.global_position).length()
	if distance < 1.3:
		Input.action_press(away)
		Input.action_release(toward)
	elif distance > 1.7:
		Input.action_press(toward)
		Input.action_release(away)
	else:
		Input.action_release("move_right")
		Input.action_release("move_left")

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
