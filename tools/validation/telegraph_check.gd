extends SceneTree
## Sprint 11 automated telegraph verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/telegraph_check.gd
## The boss AI runs (like boss_check). Asserts the roadmap checklist: a
## telegraph state precedes every attack and the hit lands only after it,
## per-attack warning durations are measurable and different (light 0.35 s,
## heavy 0.6 s), and a target leaving range cancels the telegraph into its
## cooldown. Exits 0 on PASS, 1 on FAIL.

const SETTLE_FRAMES := 30
const LIGHT_TELEGRAPH_TICKS := 21  # 0.35 s
const HEAVY_TELEGRAPH_TICKS := 36  # 0.6 s

func _initialize() -> void:
	_run()

func _run() -> void:
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
	player.hit_taken.connect(func(event: DamageEvent) -> void:
		player_taken.append(event)
		taken_frames.append(Engine.get_physics_frames()))

	# Stand where BOTH attacks can reach the player (light 1.0-2.5, heavy 1.2-2.2).
	player.global_position = Vector3(2.6, 0.5, 0.0)
	player.velocity = Vector3.ZERO
	await _wait(SETTLE_FRAMES)

	# --- 1. A telegraph precedes the impact: state sequence + timing. ---
	var telegraph_started := await _wait_for_state(boss, boss.State.TELEGRAPH, 400)
	if not telegraph_started:
		failures.append("boss never entered the TELEGRAPH state in range")
	else:
		var telegraph_start: int = Engine.get_physics_frames()
		# Discard hits from any swing that was already in flight before this
		# observation window opened.
		player_taken.clear()
		taken_frames.clear()
		await _wait_for_state(boss, boss.State.ATTACK, 40)
		var attack_start: int = Engine.get_physics_frames()
		if attack_start - telegraph_start < LIGHT_TELEGRAPH_TICKS - 3:
			failures.append("attack began before its telegraph finished (gap %d ticks)" % [
				attack_start - telegraph_start,
			])
		var hit_after_warning := false
		for _i in 200:
			await physics_frame
			if not player_taken.is_empty():
				hit_after_warning = taken_frames[0] - telegraph_start >= LIGHT_TELEGRAPH_TICKS - 3
				break
		if player_taken.is_empty():
			failures.append("no attack landed after the telegraph")
		elif not hit_after_warning:
			failures.append("impact landed before the telegraph window had elapsed")

	# --- 2. Per-attack telegraph durations are measurable and distinct. ---
	var light_durations: Array[int] = []
	var heavy_durations: Array[int] = []
	var current_id: StringName = &""
	var current_start := 0
	var in_telegraph := false
	for _i in 1500:
		await physics_frame
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
		failures.append("no light-attack telegraph observed in 1500 ticks")
	else:
		var duration: int = light_durations[0]
		if duration < LIGHT_TELEGRAPH_TICKS - 4 or duration > LIGHT_TELEGRAPH_TICKS + 4:
			failures.append("light telegraph measured %d ticks (expected ~%d)" % [duration, LIGHT_TELEGRAPH_TICKS])
	if heavy_durations.is_empty():
		failures.append("no heavy-attack telegraph observed in 1500 ticks")
	else:
		var duration: int = heavy_durations[0]
		if duration < HEAVY_TELEGRAPH_TICKS - 4 or duration > HEAVY_TELEGRAPH_TICKS + 4:
			failures.append("heavy telegraph measured %d ticks (expected ~%d)" % [duration, HEAVY_TELEGRAPH_TICKS])

	# --- 3. Leaving range during the warning cancels it, with a cooldown. ---
	await _wait_for_state(boss, boss.State.TELEGRAPH, 400)
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
		print("TELEGRAPH CHECK: PASS (warning precedes impact, light ~21 ticks, heavy ~36 ticks, range cancel + cooldown)")
		quit(0)
	else:
		for failure in failures:
			printerr("TELEGRAPH CHECK FAILURE: " + failure)
		quit(1)

func _wait_for_state(boss, target, max_frames: int) -> bool:
	for _i in max_frames:
		if boss.state == target:
			return true
		await physics_frame
	return false

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
