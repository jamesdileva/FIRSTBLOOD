extends SceneTree
## Sprint 17 automated Colosseum-blockout verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/colosseum_check.gd
## Asserts the arena shell: a disc floor, a wall ring with a gate gap and
## posts, three stand tiers, and the RADIAL navigation clamp on both actors
## (player and boss teleported far out are pulled back inside the ring).
## Exits 0 on PASS, 1 on FAIL.

const SETTLE_FRAMES := 30
const ARENA_RADIUS := 16.0

func _initialize() -> void:
	_run()

func _run() -> void:
	var failures: PackedStringArray = []
	var arena_scene: PackedScene = load("res://game/scenes/arena/arena.tscn")
	if arena_scene == null:
		printerr("COLOSSEUM CHECK FAILURE: arena scene missing")
		quit(1)
		return
	var arena := arena_scene.instantiate()
	root.add_child(arena)
	await _wait(2)
	var player = get_first_node_in_group("player")
	var boss = get_first_node_in_group("boss")
	if player == null or boss == null:
		printerr("COLOSSEUM CHECK FAILURE: player or boss not found")
		quit(1)
		return

	# --- 1. The floor is a disc of radius ~18. ---
	var floor_mesh = arena.get_node("Floor/FloorMesh").mesh
	if floor_mesh == null or not floor_mesh is CylinderMesh:
		failures.append("the floor is not a disc (CylinderMesh)")
	else:
		if absf(floor_mesh.top_radius - 18.0) > 0.5:
			failures.append("floor disc radius wrong: %.1f (expected ~18)" % floor_mesh.top_radius)

	# --- 2. The blockout shell: walls, gate, tiers. ---
	var blockout = arena.get_node_or_null("Blockout")
	var walls := 0
	if blockout == null:
		failures.append("the Blockout node is missing")
	else:
		var posts := 0
		var tiers := 0
		for node in blockout.find_children("*", "MeshInstance3D", true, false):
			if String(node.name).begins_with("Wall"):
				walls += 1
		for node in blockout.find_children("GatePost*", "StaticBody3D", true, false):
			posts += 1
		for node in blockout.find_children("Tier*", "MeshInstance3D", true, false):
			tiers += 1
		if walls < 14 or walls > 16:
			failures.append("wall segment count wrong: %d (expected ~15 + gate gap)" % walls)
		if posts != 2:
			failures.append("gate post count wrong: %d (expected 2)" % posts)
		if tiers != 3:
			failures.append("stand tier count wrong: %d (expected 3)" % tiers)

	# --- 3. Radial navigation clamp on both actors. ---
	player.global_position = Vector3(100.0, 5.0, 0.0)
	player.velocity = Vector3.ZERO
	boss.global_position = Vector3(0.0, 5.0, 100.0)
	boss.velocity = Vector3.ZERO
	await _wait(SETTLE_FRAMES)
	var player_flat: float = Vector2(player.global_position.x, player.global_position.z).length()
	var boss_flat: float = Vector2(boss.global_position.x, boss.global_position.z).length()
	if player_flat > ARENA_RADIUS + 0.5:
		failures.append("the player escaped the ring: %.2f > %.1f" % [player_flat, ARENA_RADIUS])
	if boss_flat > ARENA_RADIUS + 0.5:
		failures.append("the boss escaped the ring: %.2f > %.1f" % [boss_flat, ARENA_RADIUS])

	# --- 4. The wall ring physically blocks (drive the player outward). ---
	Input.action_press("move_right")
	await _wait(90)
	Input.action_release("move_right")
	var driven_flat: float = Vector2(player.global_position.x, player.global_position.z).length()
	if driven_flat > ARENA_RADIUS + 1.0:
		failures.append("the player drove through the wall ring: %.2f" % driven_flat)

	player.global_position = Vector3(-4.0, 0.5, 0.0)
	await _wait(SETTLE_FRAMES)
	arena.free()

	if failures.is_empty():
		print("COLOSSEUM CHECK: PASS (disc floor, %d walls + gate, 3 tiers, radial clamp holds for both actors)" % [
			walls,
		])
		quit(0)
	else:
		for failure in failures:
			printerr("COLOSSEUM CHECK FAILURE: " + failure)
		quit(1)

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
