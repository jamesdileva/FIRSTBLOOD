extends SceneTree
## Sprint 15 automated hit-feedback verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/feedback_check.gd
## A probe player fights the live gladiator (guard through offense, mash in
## openings) while polling the feedback bus, the camera, and the boss:
##   - hit-stop fires on landed hits and never uses Engine.time_scale;
##   - both weight magnitudes are observed (light 45 ms / heavy 90 ms);
##   - the camera consumes shake impulses and decays them to rest;
##   - impact bursts spawn and clean up;
##   - the boss flinches when damaged;
##   - the player hurt flash fires on taken/mitigated hits.
## Exits 0 on PASS, 1 on FAIL.

const SETTLE_FRAMES := 30

var _mash_edge := false

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
		printerr("FEEDBACK CHECK FAILURE: arena scene missing")
		quit(1)
		return
	var arena := arena_scene.instantiate()
	root.add_child(arena)
	await _wait(2)
	var player = get_first_node_in_group("player")
	var boss = get_first_node_in_group("boss")
	if player == null or boss == null:
		printerr("FEEDBACK CHECK FAILURE: player or boss not found")
		quit(1)
		return
	var camera_rig = arena.get_node_or_null("CameraRig")
	var player_health = player.get_node("Health")

	player.global_position = Vector3(2.6, 0.5, 0.0)
	player.rotation.y = -PI / 2.0
	await _wait(SETTLE_FRAMES)

	var saw_hit_stop := false
	var saw_light_stop := false
	var saw_heavy_stop := false
	var saw_heavy_flag := false
	var saw_impact := false
	var saw_camera_shake := false
	var saw_boss_flinch := false
	var saw_hurt_flash := false
	var time_scale_violations := 0
	var hits_seen := [0]
	player.get_node("AttackHitbox").hit_landed.connect(func(_e: DamageEvent, _t) -> void: hits_seen[0] += 1)

	for _i in 5000:
		_drive(boss, player)
		await physics_frame
		if player_health.is_dead():
			player.reset_for_retry()
			await _wait(SETTLE_FRAMES)
		if float(boss.get_node("Health").current_health) < 30.0:
			boss.get_node("Health").reset()  # measure feedback, not the kill
		# poll feedback state
		if HitFeedback.is_hit_stop_active():
			saw_hit_stop = true
		if Engine.time_scale != 1.0:
			time_scale_violations += 1
		if HitFeedback.last_hit_stop_ms == 45:
			saw_light_stop = true
		if HitFeedback.last_hit_stop_ms == 90:
			saw_heavy_stop = true
		if HitFeedback.last_hit_heavy:
			saw_heavy_flag = true
		if HitFeedback.impact_bursts_alive > 0:
			saw_impact = true
		if camera_rig != null and camera_rig.shake_level > 0.02:
			saw_camera_shake = true
		if boss.flinch_level() > 0.05:
			saw_boss_flinch = true
		if HitFeedback.hurt_flash_active():
			saw_hurt_flash = true
		# early exit once everything is observed
		if saw_hit_stop and saw_light_stop and saw_heavy_stop and saw_heavy_flag \
				and saw_impact and saw_camera_shake and saw_boss_flinch and saw_hurt_flash:
			break

	# Guaranteed mitigated hit: a heavy test strike on the guarding probe
	# fires the resolver's mitigated path -> hurt flash (the boss's own
	# heavy is too rare against a stagger-locking probe).
	Input.action_press("block")
	await _wait(10)  # into BLOCK_ACTIVE
	var probe_holder := Node3D.new()
	probe_holder.position = player.global_position + Vector3(0, 0.9, 0)
	arena.add_child(probe_holder)
	var probe_hitbox := HitboxComponent.new()
	probe_hitbox.faction = CombatTypes.Faction.BOSS
	probe_hitbox.damage = 20.0
	probe_hitbox.stagger_damage = 4.0
	probe_hitbox.hit_type = CombatTypes.HitType.HEAVY
	probe_hitbox.attack_id = &"test_heavy"
	probe_holder.add_child(probe_hitbox)
	var probe_shape := CollisionShape3D.new()
	var probe_box := BoxShape3D.new()
	probe_box.size = Vector3(1.2, 1.2, 1.2)
	probe_shape.shape = probe_box
	probe_hitbox.add_child(probe_shape)
	await _wait(2)
	probe_hitbox.set_active(true)
	await _wait(5)
	probe_hitbox.set_active(false)
	Input.action_release("block")
	await _wait(3)
	if HitFeedback.hurt_flash_active():
		saw_hurt_flash = true

	# decay pass: everything returns to rest
	Input.action_release("block")
	Input.action_release("attack")
	Input.action_release("move_right")
	Input.action_release("move_left")
	await _wait(150)
	if Engine.time_scale != 1.0:
		time_scale_violations += 1
	if camera_rig != null and camera_rig.shake_level > 0.02:
		failures.append("camera shake never decayed to rest (level %.3f)" % camera_rig.shake_level)
	if HitFeedback.is_hit_stop_active():
		failures.append("hit-stop never released")

	if hits_seen[0] == 0:
		failures.append("no player hits landed at all — probe or fight broken")
	if not saw_hit_stop:
		failures.append("hit-stop never activated on a landed hit")
	if Engine.time_scale != 1.0:
		failures.append("Engine.time_scale was touched (D-050 violation)")
	if time_scale_violations > 0:
		failures.append("time_scale left 1.0 during the fight")
	if not saw_light_stop:
		failures.append("light hit-stop magnitude (45 ms) never observed")
	if not saw_heavy_stop:
		failures.append("heavy hit-stop magnitude (90 ms) never observed")
	if not saw_heavy_flag:
		failures.append("no heavy hit was ever reported")
	if not saw_impact:
		failures.append("no impact burst ever spawned")
	if not saw_camera_shake:
		failures.append("the camera never consumed a shake impulse")
	if not saw_boss_flinch:
		failures.append("the boss never flinched from damage")
	if not saw_hurt_flash:
		failures.append("the player hurt flash never fired")

	player_health.reset()
	arena.free()

	if failures.is_empty():
		print("FEEDBACK CHECK: PASS (hit-stop both magnitudes, no time_scale, bursts, camera shake+decay, flinch, hurt flash)")
		quit(0)
	else:
		for failure in failures:
			printerr("FEEDBACK CHECK FAILURE: " + failure)
		quit(1)

## Probe: guard through boss offense, mash in openings, hold the 1.15-1.6 m
## band (soft-facing aligns the swings).
func _drive(boss, player) -> void:
	var distance: float = (boss.global_position - player.global_position).length()
	if boss.state == boss.State.STAGGERED:
		Input.action_release("block")
		if _mash_edge:
			Input.action_release("attack")
		else:
			Input.action_press("attack")
		_mash_edge = not _mash_edge
		return
	if boss.state == boss.State.TELEGRAPH or boss.state == boss.State.ATTACK:
		Input.action_release("attack")
		_mash_edge = false
		Input.action_press("block")
		return
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

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
