extends SceneTree
## Sprint 05 automated light-attack verification (headless). Run from the root:
##   cmd //c godot --headless --path . -s res://tools/validation/attack_check.gd
## Drives the real arena scene with synthesized input: the player walks up to
## the boss placeholder, swings, and the check asserts the roadmap checklist —
## hitbox live only during the active window, exactly one intended hit per
## swing with the full payload, and no spamming through recovery.
## Exits 0 on PASS, 1 on FAIL.

const SETTLE_FRAMES := 30
const STARTUP_TICKS := 6     # 0.10 s
const ACTIVE_END_TICKS := 13 # 0.10 + 0.12 s
const RECOVERY_TICKS := 15   # 0.25 s
const ATTACK_TOTAL_TICKS := 28
const SPAM_MIN_GAP := 26     # ATTACK_TOTAL_TICKS minus edge tolerance

func _initialize() -> void:
	_run()

func _run() -> void:
	var failures: PackedStringArray = []
	var arena_scene: PackedScene = load("res://game/scenes/arena/arena.tscn")
	if arena_scene == null:
		printerr("ATTACK CHECK FAILURE: arena scene missing")
		quit(1)
		return
	var arena := arena_scene.instantiate()
	root.add_child(arena)
	await _wait(SETTLE_FRAMES)
	# Untyped on purpose: reads script members Godot's base classes lack.
	var player = get_first_node_in_group("player")
	var boss = get_first_node_in_group("boss")
	if player == null or boss == null:
		printerr("ATTACK CHECK FAILURE: player or boss not found")
		quit(1)
		return
	var boss_hurtbox = boss.get_node_or_null("Hurtbox")
	var attack_hitbox = player.get_node_or_null("AttackHitbox")
	if boss_hurtbox == null or attack_hitbox == null:
		printerr("ATTACK CHECK FAILURE: hurtbox/hitbox nodes missing")
		quit(1)
		return
	var events: Array[DamageEvent] = []
	var hit_frames: Array[int] = []
	boss_hurtbox.damaged.connect(func(event: DamageEvent) -> void:
		events.append(event)
		hit_frames.append(Engine.get_physics_frames()))

	# Stand in reach of the boss, facing it (+X). Yaw is snapped directly —
	# walking up would stall against the boss and freeze facing mid-turn;
	# the facing mechanism itself is already verified by movement_check.
	await _settle_player(player, Vector3(3.0, 0.5, 0.0))
	player.rotation.y = -PI / 2.0
	var dist: float = player.global_position.distance_to(boss.global_position)
	if dist > 1.4:
		failures.append("player not in reach of boss (dist %.2f)" % dist)
	var body_forward: Vector3 = -player.global_basis.z
	if Vector3(body_forward.x, 0.0, body_forward.z).normalized().dot(Vector3(1.0, 0.0, 0.0)) < 0.9:
		failures.append("player not facing the boss before attacking")

	# --- 1. Hitbox is live only during [startup, startup+active). ---
	await _attack_tap()
	var active_ticks: Array[int] = []
	for i in 40:
		await physics_frame
		if attack_hitbox.is_active():
			active_ticks.append(i)
	if active_ticks.is_empty():
		failures.append("hitbox never went active during the swing")
	else:
		# Attack begins on the input edge; poll offsets drift ±1 tick, so the
		# first active sample must land inside the startup-adjacent band.
		if active_ticks[0] < 2 or active_ticks[0] > 6:
			failures.append("hitbox activation misaligned with startup (first active poll tick %d)" % active_ticks[0])
		if active_ticks[-1] > 14:
			failures.append("hitbox active into recovery (last active poll tick %d)" % active_ticks[-1])
		if active_ticks.size() < 4:
			failures.append("active window too short: %d ticks" % active_ticks.size())

	# --- 2. The target receives exactly one intended hit with the full payload. ---
	await _wait(SETTLE_FRAMES)
	if events.size() != 1:
		failures.append("expected 1 damage event on the boss, got %d" % events.size())
	else:
		var event := events[0]
		if event.amount != 10.0:
			failures.append("attack damage wrong: %.1f" % event.amount)
		if event.stagger_damage != 5.0:
			failures.append("attack stagger payload wrong: %.1f" % event.stagger_damage)
		if event.attack_id != &"light_01":
			failures.append("attack_id wrong: %s" % event.attack_id)
		if event.source != player:
			failures.append("event source is not the player")

	# --- 3. Mashing attack cannot attack through its own recovery. ---
	# Since Sprint 06 the chain re-enters ATTACK without a state change, so
	# swings are counted by their hits; the invariant is that consecutive
	# hits stay a full step apart (recovery respected) and each lands once.
	events.clear()
	hit_frames.clear()
	for _i in 90:
		Input.action_press("attack")
		await physics_frame
		Input.action_release("attack")
		await physics_frame
	if events.size() < 2:
		failures.append("expected repeated swings after recovery, got %d hits" % events.size())
	for i in range(1, hit_frames.size()):
		var gap: int = hit_frames[i] - hit_frames[i - 1]
		if gap < SPAM_MIN_GAP:
			failures.append("re-attack landed after only %d ticks (recovery bypassed)" % gap)
	for event in events:
		# Mashing chains through the combo into the finisher, so all per-step
		# and finisher damage values apply.
		if not [10.0, 12.0, 14.0, 25.0].has(event.amount):
			failures.append("spam swing payload wrong: %.1f" % event.amount)

	# --- 4. Hitbox is inert outside ATTACK. ---
	await _wait(10)
	if attack_hitbox.is_active():
		failures.append("hitbox active while idle")

	var swing_count := events.size()
	events.clear()
	hit_frames.clear()
	arena.free()

	if failures.is_empty():
		print("ATTACK CHECK: PASS (active window ticks %d-%d, %d swings, one hit per swing, recovery respected)" % [
			active_ticks[0], active_ticks[-1], swing_count,
		])
		quit(0)
	else:
		for failure in failures:
			printerr("ATTACK CHECK FAILURE: " + failure)
		quit(1)

func _attack_tap() -> void:
	Input.action_press("attack")
	await _wait(2)
	Input.action_release("attack")

func _settle_player(player, pos: Vector3) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	await _wait(SETTLE_FRAMES)

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
