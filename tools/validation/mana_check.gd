extends SceneTree
## Sprint 28 mana-subsystem verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/mana_check.gd
## Asserts the roadmap checklist — mana decreases on use and regenerates
## after the configured delay: atomic spend math (true/false, no
## over-spend), the regen delay honored (no regen inside the window, flat
## rate after it, clamp at max), the real player's component (retry
## refills), and the HUD bar tracking a spend -> delay -> regen cycle.
## Exits 0 on PASS, 1 on FAIL.

const SETTLE_FRAMES := 30

func _initialize() -> void:
	_run()

func _run() -> void:
	var failures: PackedStringArray = []
	OS.set_environment("FIRSTBLOOD_CHECK_SAVE", "1")
	var check_save := ProjectSettings.globalize_path("user://check_save.json")
	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)

	# --- A. Atomic spend math (standalone component). ---
	var mana := ManaComponent.new()
	if not is_equal_approx(mana.current_mana, 100.0):
		failures.append("a fresh mana pool is not full (%.1f)" % mana.current_mana)
	if not mana.spend(30.0):
		failures.append("spending from a full pool returned false")
	if not is_equal_approx(mana.current_mana, 70.0):
		failures.append("spending 30 left %.1f (expected 70)" % mana.current_mana)
	if mana.spend(80.0):
		failures.append("an over-spend returned true")
	if not is_equal_approx(mana.current_mana, 70.0):
		failures.append("the over-spend changed the pool (%.1f)" % mana.current_mana)
	if not mana.spend(0.0):
		failures.append("a zero-cost spend returned false")
	if not mana.is_available(70.0):
		failures.append("is_available denied the exact pool amount")
	if mana.is_available(70.1):
		failures.append("is_available granted more than the pool holds")

	# --- B. The delay + flat regen on a REAL player. ---
	var player_scene: PackedScene = load("res://game/scenes/player/player.tscn")
	var player = player_scene.instantiate()
	root.add_child(player)
	await _wait(SETTLE_FRAMES)
	var mana_node: ManaComponent = player.get_node("Mana")
	if not is_equal_approx(mana_node.current_mana, mana_node.max_mana):
		failures.append("the player's mana pool did not spawn full (%.1f)" % mana_node.current_mana)
	mana_node.spend(50.0)
	var after_spend := mana_node.current_mana
	if not is_equal_approx(after_spend, 50.0):
		failures.append("the player's spend left %.1f (expected 50)" % after_spend)
	# inside the 3.0 s delay: 100 ticks (~1.67 s) -> no regen yet
	await _wait(100)
	if not is_equal_approx(mana_node.current_mana, after_spend):
		failures.append("mana regenerated inside the delay window (%.1f)" % mana_node.current_mana)
	# after the delay: 30 ticks (0.5 s) at 20/s -> ~+10
	await _wait(80)  # the remaining ~1.33 s of delay
	await _wait(30)
	var gained := mana_node.current_mana - after_spend
	if absf(gained - 10.0) > 2.0:
		failures.append("the flat regen rate is wrong: +%.1f over 0.5 s (expected ~10)" % gained)
	# full refill + clamp
	for _i in 600:
		if mana_node.current_mana >= mana_node.max_mana:
			break
		await physics_frame
	if not is_equal_approx(mana_node.current_mana, mana_node.max_mana):
		failures.append("mana did not refill to max (%.1f)" % mana_node.current_mana)

	# --- C. Retry refills (D-058 full-reset semantics). ---
	mana_node.spend(60.0)
	player.reset_for_retry()
	if not is_equal_approx(mana_node.current_mana, mana_node.max_mana):
		failures.append("reset_for_retry did not refill mana (%.1f)" % mana_node.current_mana)

	# --- D. The HUD bar tracks a spend -> delay -> regen cycle. ---
	var hud_scene: PackedScene = load("res://game/scenes/ui/hud.tscn")
	var hud = hud_scene.instantiate()
	root.add_child(hud)
	await _wait(SETTLE_FRAMES)
	var mana_bar: ProgressBar = hud.get_node_or_null("ManaBar")
	if mana_bar == null:
		failures.append("the HUD has no ManaBar")
	else:
		mana_node.spend(40.0)
		await _wait(3)
		if not is_equal_approx(float(mana_bar.value), mana_node.current_mana):
			failures.append("the HUD mana bar ignored a spend (%.0f vs %.1f)" % [
				float(mana_bar.value), mana_node.current_mana,
			])
		for _i in 600:
			if mana_node.current_mana >= mana_node.max_mana:
				break
			await physics_frame
		await _wait(3)
		if not is_equal_approx(float(mana_bar.max_value), mana_node.max_mana):
			failures.append("the HUD mana bar max does not match the component (%.0f)" % float(mana_bar.max_value))
		if not is_equal_approx(float(mana_bar.value), mana_node.max_mana):
			failures.append("the HUD mana bar did not refill (%.0f)" % float(mana_bar.value))
	hud.free()
	player.free()

	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)

	if failures.is_empty():
		print("MANA CHECK: PASS (atomic spend, delay honored, flat regen + clamp, retry refill, HUD bar tracks)")
		quit(0)
	else:
		for failure in failures:
			printerr("MANA CHECK FAILURE: " + failure)
		quit(1)

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
