extends SceneTree
## Sprint 29 four-slot spell-input verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/spell_input_check.gd
## Asserts the roadmap checklist — each of the four slots reliably
## activates its assigned spell: loadout integrity, the mana-gated cast
## path (empty slot, mana-short), REAL joypad input (LB held + each face
## button casts exactly once; LB up = melee inputs untouched), and melee
## coexistence (casting is rejected mid-attack, works again after
## recovery). Exits 0 on PASS, 1 on FAIL.

const SETTLE_FRAMES := 30
const SPARK_COST := 10.0
const BTN_LB := 9
const BTN_A := 0
const BTN_B := 1
const BTN_X := 2
const BTN_Y := 3

func _initialize() -> void:
	_run()

func _run() -> void:
	var failures: PackedStringArray = []
	OS.set_environment("FIRSTBLOOD_CHECK_SAVE", "1")
	var check_save := ProjectSettings.globalize_path("user://check_save.json")
	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)

	# --- A. Loadout integrity (the player scene's assignments). ---
	var player_scene: PackedScene = load("res://game/scenes/player/player.tscn")
	var player = player_scene.instantiate()
	root.add_child(player)
	await _wait(SETTLE_FRAMES)
	var magic: MagicComponent = player.get_node("Magic")
	for slot in ["a", "b", "x", "y"]:
		if magic._spell(StringName(slot)) == null:
			failures.append("slot %s has no spell assigned" % slot)
	var spark: SpellData = magic._spell(&"a")
	if spark == null or spark.mana_cost <= 0.0:
		failures.append("the assigned spell carries no mana cost")
	if spark != null and not is_equal_approx(spark.mana_cost, SPARK_COST):
		failures.append("the spark cost drifted: %.1f (expected %.1f)" % [spark.mana_cost, SPARK_COST])

	# --- B. The mana-gated cast path (direct calls). ---
	var mana: ManaComponent = player.get_node("Mana")
	if not magic.cast_slot(&"a"):
		failures.append("casting an assigned slot returned false")
	if not is_equal_approx(mana.current_mana, 90.0):
		failures.append("the spark cast cost %.1f instead of %.1f (pool %.1f)" % [
			100.0 - mana.current_mana, SPARK_COST, mana.current_mana,
		])
	if magic.cast_slot(&"b") == false:
		failures.append("slot b did not cast")
	if magic.cast_slot(&"q"):
		failures.append("an unknown slot cast successfully")
	mana.spend(75.0)  # pool: 80 - 75 = 5 (spend() is atomic: 85 would bounce)
	if magic.cast_slot(&"x"):
		failures.append("a mana-short cast succeeded")
	if not is_equal_approx(mana.current_mana, 5.0):
		failures.append("the mana-short cast spent mana (%.1f)" % mana.current_mana)
	mana.reset()

	# --- C. Real joypad input: LB + each face casts exactly once. ---
	# The input gate lives in the ground-neutral states, so the player needs
	# a floor to stand on (a bare instantiation floats in AIRBORNE forever).
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(20, 1, 20)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	player.global_position = Vector3(0, 0.5, 0)
	await _wait(SETTLE_FRAMES)
	if player.state != player.State.IDLE and player.state != player.State.MOVE:
		failures.append("the player never landed on the check floor (state %s)" % player.State.keys()[player.state])
	if not is_equal_approx(mana.current_mana, mana.max_mana):
		mana.reset()
		await _wait(2)
	# hold LB, press and release each face button once
	Input.parse_input_event(_pad(BTN_LB, true))
	await _wait(2)
	var before := mana.current_mana
	for button in [BTN_A, BTN_B, BTN_X, BTN_Y]:
		Input.parse_input_event(_pad(button, true))
		await _wait(2)
		Input.parse_input_event(_pad(button, false))
		await _wait(2)
	var spent := before - mana.current_mana
	if absf(spent - 4.0 * SPARK_COST) > 1.0:
		failures.append("four face casts spent %.1f mana (expected %.1f)" % [spent, 4.0 * SPARK_COST])
	# LB up: a face press must NOT cast (A is start_match; X would attack —
	# both leave the pool alone here)
	Input.parse_input_event(_pad(BTN_LB, false))
	await _wait(2)
	before = mana.current_mana
	Input.parse_input_event(_pad(BTN_A, true))
	await _wait(2)
	Input.parse_input_event(_pad(BTN_A, false))
	await _wait(2)
	if not is_equal_approx(mana.current_mana, before):
		failures.append("a face press without LB spent mana (%.1f -> %.1f)" % [before, mana.current_mana])

	# --- D. Melee coexistence: no casting mid-attack. ---
	mana.reset()
	await _wait(2)
	Input.parse_input_event(_pad(BTN_X, true))  # attack (X without LB)
	await _wait(2)
	Input.parse_input_event(_pad(BTN_X, false))
	await _wait(2)
	if player.state != player.State.ATTACK:
		failures.append("the attack press did not start an attack (state %s)" % player.State.keys()[player.state])
	else:
		Input.parse_input_event(_pad(BTN_LB, true))
		await _wait(2)
		Input.parse_input_event(_pad(BTN_A, true))
		await _wait(2)
		Input.parse_input_event(_pad(BTN_A, false))
		await _wait(2)
		if not is_equal_approx(mana.current_mana, mana.max_mana):
			failures.append("a cast slipped through mid-attack (pool %.1f)" % mana.current_mana)
		Input.parse_input_event(_pad(BTN_LB, false))
		await _wait(2)
		# recovery: the swing finishes, then casting works again
		for _i in 120:
			if player.state == player.State.IDLE or player.state == player.State.MOVE:
				break
			await physics_frame
		await _wait(5)
		if player.state != player.State.IDLE and player.state != player.State.MOVE:
			failures.append("the attack never recovered (state %s)" % player.State.keys()[player.state])
		else:
			Input.parse_input_event(_pad(BTN_LB, true))
			await _wait(2)
			Input.parse_input_event(_pad(BTN_A, true))
			await _wait(2)
			Input.parse_input_event(_pad(BTN_A, false))
			await _wait(2)
			if not is_equal_approx(mana.current_mana, mana.max_mana - SPARK_COST):
				failures.append("casting did not work again after recovery (pool %.1f)" % mana.current_mana)
			Input.parse_input_event(_pad(BTN_LB, false))
			await _wait(2)

	player.free()
	floor_body.free()

	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)

	if failures.is_empty():
		print("SPELL INPUT CHECK: PASS (loadout, mana-gated cast, LB+face casts once per press, melee coexistence)")
		quit(0)
	else:
		for failure in failures:
			printerr("SPELL INPUT CHECK FAILURE: " + failure)
		quit(1)

func _pad(button: int, pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	return event

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
