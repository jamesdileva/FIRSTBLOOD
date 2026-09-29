extends SceneTree
## Sprint 02 automated movement verification (headless). Run from the project root:
##   cmd //c godot --headless --path . -s res://tools/validation/movement_check.gd
## Drives the real arena scene with synthesized input actions and asserts the
## roadmap's testable checklist: camera-relative movement, no drift after input
## release, facing follows movement, arena bounds hold. Exits 0 on PASS, 1 on FAIL.

const SETTLE_FRAMES := 30
const MOVE_FRAMES := 60
const STOP_FRAMES := 60
const BOUND_FRAMES := 10

const MIN_TRAVEL := 3.0          # meters covered while holding move for MOVE_FRAMES
const DIRECTION_DOT_MIN := 0.7   # alignment with expected camera-relative direction
const FACING_DOT_MIN := 0.9      # body forward vs movement direction
const MAX_DRIFT_SPEED := 0.1     # m/s after releasing input

func _initialize() -> void:
	_run()

func _run() -> void:
	var failures: PackedStringArray = []
	var arena_scene: PackedScene = load("res://game/scenes/arena/arena.tscn")
	if arena_scene == null:
		printerr("MOVEMENT CHECK FAILURE: arena scene missing")
		quit(1)
		return
	var arena := arena_scene.instantiate()
	root.add_child(arena)

	await _wait(SETTLE_FRAMES)
	# Untyped on purpose: reads script members (arena_half_extent) Godot's
	# CharacterBody3D class doesn't define.
	var player := get_first_node_in_group("player")
	if player == null:
		printerr("MOVEMENT CHECK FAILURE: player not found in arena")
		quit(1)
		return

	# 1. Holding move_forward travels in the camera's flattened forward direction.
	var start: Vector3 = player.global_position
	Input.action_press("move_forward")
	await _wait(MOVE_FRAMES)
	Input.action_release("move_forward")
	var travel: Vector3 = player.global_position - start
	var flat := Vector3(travel.x, 0.0, travel.z)
	if flat.length() < MIN_TRAVEL:
		failures.append("moved only %.2f m (expected >= %.1f)" % [flat.length(), MIN_TRAVEL])
	var direction_dot := flat.normalized().dot(Vector3(0.0, 0.0, -1.0))
	if direction_dot < DIRECTION_DOT_MIN:
		failures.append("moved in wrong direction (dot=%.2f, expected camera-relative -Z)" % direction_dot)

	# 2. Body rotates to face the movement direction.
	var body_forward: Vector3 = -player.global_basis.z
	var facing_dot := Vector3(body_forward.x, 0.0, body_forward.z).normalized().dot(Vector3(0.0, 0.0, -1.0))
	if facing_dot < FACING_DOT_MIN:
		failures.append("player not facing movement direction (dot=%.2f)" % facing_dot)

	# 3. Releasing input stops the player: no drift, no uncontrolled slide.
	await _wait(STOP_FRAMES)
	var residual: Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z)
	if residual.length() > MAX_DRIFT_SPEED:
		failures.append("player drifts after input release: %.2f m/s" % residual.length())
	var stop_travel := Vector3(player.global_position.x - (start.x + flat.x), 0.0, player.global_position.z - (start.z + flat.z))
	if stop_travel.length() > 1.0:
		failures.append("player slid %.2f m past the release point" % stop_travel.length())

	# 4. Arena boundary: a player placed outside is clamped back inside.
	player.global_position = Vector3(100.0, 5.0, 100.0)
	player.velocity = Vector3.ZERO
	await _wait(BOUND_FRAMES)
	if absf(player.global_position.x) > player.arena_half_extent + 0.5 \
			or absf(player.global_position.z) > player.arena_half_extent + 0.5:
		failures.append("player escaped arena bounds at %s" % player.global_position)

	arena.free()

	if failures.is_empty():
		print("MOVEMENT CHECK: PASS (travel %.2f m, direction dot %.2f, facing dot %.2f, drift %.3f m/s)" % [
			flat.length(), direction_dot, facing_dot, residual.length(),
		])
		quit(0)
	else:
		for failure in failures:
			printerr("MOVEMENT CHECK FAILURE: " + failure)
		quit(1)

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
