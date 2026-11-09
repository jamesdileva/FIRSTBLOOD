extends SceneTree
## Temporary diagnostic: camera state on load + retry action/flow.

const SETTLE := 30

func _initialize() -> void:
	_run()

func _run() -> void:
	var arena_scene: PackedScene = load("res://game/scenes/arena/arena.tscn")
	var arena := arena_scene.instantiate()
	root.add_child(arena)
	await _wait(5)
	var player = get_first_node_in_group("player")
	var boss = get_first_node_in_group("boss")
	var rig = arena.get_node_or_null("CameraRig")
	var cam: Camera3D = rig.get_node("Camera3D") if rig != null else null
	print("retry_action_exists=", InputMap.has_action("retry"))
	if InputMap.has_action("retry"):
		print("retry_events=", InputMap.action_get_events("retry").size())
	print("rig_target=", rig.target if rig != null else "no rig")
	print("rig_pos=", rig.global_position, " cam_pos=", cam.global_position)
	var forward: Vector3 = -cam.global_transform.basis.z
	print("cam_forward=", forward, " pitch_down_deg=", rad_to_deg(asin(-forward.y)))
	print("cam_looking_at_floor=", cam.position.y, " rig_script=", rig.get_script().resource_path)
	# what does the camera see on load? ray-ish check: angle between forward and dir-to-player
	var to_player: Vector3 = (player.global_position + Vector3.UP * 1.0) - cam.global_position
	print("angle_to_player_deg=", rad_to_deg(forward.angle_to(to_player.normalized())))
	await _wait(SETTLE)
	print("after_settle: cam_pos=", cam.global_position, " forward=", -cam.global_transform.basis.z)
	var to_player2: Vector3 = (player.global_position + Vector3.UP * 1.0) - cam.global_position
	print("angle_to_player_deg=", rad_to_deg((-cam.global_transform.basis.z).angle_to(to_player2.normalized())))

	# --- retry flow A: action_press (already proven) ---
	# --- retry flow B: the REAL physical R key event ---
	player.get_node("Health").apply_damage(func_get_lethal())
	await _wait(5)
	print("after_kill: player_state=", player.State.keys()[player.state], " player_dead=", player.is_dead())
	var key_event := InputEventKey.new()
	key_event.physical_keycode = 82
	key_event.keycode = 82
	key_event.pressed = true
	Input.parse_input_event(key_event)
	await _wait(2)
	var release := InputEventKey.new()
	release.physical_keycode = 82
	release.keycode = 82
	release.pressed = false
	Input.parse_input_event(release)
	await _wait(10)
	print("after_physical_R: player_state=", player.State.keys()[player.state],
			" player_hp=", player.get_node("Health").current_health,
			" boss_state=", boss.State.keys()[boss.state],
			" boss_hp=", boss.get_node("Health").current_health)
	# --- retry flow C: retry while the boss is mid-offense ---
	player.get_node("Health").apply_damage(func_get_lethal())
	await _wait(3)
	var key2 := InputEventKey.new()
	key2.physical_keycode = 82
	key2.keycode = 82
	key2.pressed = true
	Input.parse_input_event(key2)
	await _wait(2)
	var release2 := InputEventKey.new()
	release2.physical_keycode = 82
	release2.keycode = 82
	release2.pressed = false
	Input.parse_input_event(release2)
	await _wait(10)
	print("after_retry_mid_offense: player_state=", player.State.keys()[player.state],
			" player_hp=", player.get_node("Health").current_health)
	quit(0)

func func_get_lethal() -> DamageEvent:
	var event := DamageEvent.new()
	event.amount = 1000.0
	return event

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
