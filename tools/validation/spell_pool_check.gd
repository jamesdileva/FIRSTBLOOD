extends SceneTree
## Sprint 30 initial-magic verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/spell_pool_check.gd
## Asserts the roadmap checklist — each spell has distinct behavior and a
## distinct resource cost: heal restores clamped HP, fire's projectile
## reaches and damages the boss through the real pipeline and despawns,
## freeze roots the boss and releases, reflect negates a boss-sourced hit
## and returns its power to the boss, then expires. Exits 0 on PASS, 1 on
## FAIL.

const SETTLE_FRAMES := 30

func _initialize() -> void:
	_run()

func _run() -> void:
	var failures: PackedStringArray = []
	OS.set_environment("FIRSTBLOOD_CHECK_SAVE", "1")
	var check_save := ProjectSettings.globalize_path("user://check_save.json")
	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)

	# The arena gives the pool a real floor, a real boss, and the real
	# hurtbox layers (the flow_check instantiation pattern).
	var arena_scene: PackedScene = load("res://game/scenes/arena/arena.tscn")
	if arena_scene == null:
		printerr("SPELL POOL CHECK FAILURE: arena scene missing")
		quit(1)
		return
	var arena := arena_scene.instantiate()
	root.add_child(arena)
	await _wait(SETTLE_FRAMES)
	var player = get_first_node_in_group("player")
	var boss = get_first_node_in_group("boss")
	if player == null or boss == null:
		printerr("SPELL POOL CHECK FAILURE: player or boss missing")
		quit(1)
		return
	var magic: MagicComponent = player.get_node("Magic")
	var mana: ManaComponent = player.get_node("Mana")
	var player_health = player.get_node("Health")
	var boss_health = boss.get_node("Health")
	# park the fight: the boss stays put, the tests stay deterministic
	boss.movement_speed = 0.0
	player.global_position = Vector3(-4, 0.5, 0)
	boss.global_position = Vector3(4, 0, 0)
	await _wait(SETTLE_FRAMES)

	# --- A. The loadout: four distinct spells, distinct positive costs. ---
	var slots := {
		"a": magic._spell(&"a"), "b": magic._spell(&"b"),
		"x": magic._spell(&"x"), "y": magic._spell(&"y"),
	}
	var costs: Array = []
	var effects: Array = []
	for slot in slots:
		var spell: SpellData = slots[slot]
		if spell == null:
			failures.append("slot %s is empty" % slot)
			continue
		costs.append(spell.mana_cost)
		effects.append(spell.effect)
		if spell.mana_cost <= 0.0:
			failures.append("spell %s is free" % spell.id)
	if costs.size() == 4:
		if effects[0] != &"heal" or effects[1] != &"fire" or effects[2] != &"freeze" or effects[3] != &"reflect":
			failures.append("the slots are not heal/fire/freeze/reflect (%s)" % [effects])
		var distinct := {}
		for cost in costs:
			distinct[cost] = true
		if distinct.size() != 4:
			failures.append("the spell costs are not distinct (%s)" % [costs])

	# --- B. Heal: restores HP (clamped at max). ---
	mana.reset()
	player_health.apply_damage(_event(40.0))
	if not is_equal_approx(float(player_health.current_health), 60.0):
		failures.append("the heal setup left HP at %.1f (expected 60)" % float(player_health.current_health))
	if not magic.cast_slot(&"a"):
		failures.append("heal did not cast")
	if not is_equal_approx(float(player_health.current_health), 90.0):
		failures.append("heal left HP at %.1f (expected 90)" % float(player_health.current_health))
	player_health.heal(50.0)
	if not is_equal_approx(float(player_health.current_health), player_health.max_health):
		failures.append("healing past max was not clamped (%.1f)" % float(player_health.current_health))

	# --- C. Fire: the projectile reaches and damages the boss, then despawns. ---
	mana.reset()
	if not magic.cast_slot(&"b"):
		failures.append("fire did not cast")
	if get_nodes_in_group("spell_projectile").size() != 1:
		failures.append("the fire cast did not spawn exactly one projectile")
	var boss_start := float(boss_health.current_health)
	var hit_seen := false
	for _i in 120:
		await physics_frame
		if not is_equal_approx(float(boss_health.current_health), boss_start):
			hit_seen = true
			break
	if not hit_seen:
		failures.append("the firebolt never reached the boss")
	elif not is_equal_approx(float(boss_health.current_health), boss_start - 16.0):
		failures.append("the firebolt dealt %.1f (expected 16)" % [
			boss_start - float(boss_health.current_health),
		])
	await _wait(5)
	if get_nodes_in_group("spell_projectile").size() != 0:
		failures.append("the projectile did not despawn after its hit")

	# --- D. Freeze: the boss is rooted, then released. ---
	boss.movement_speed = 3.0
	mana.reset()
	if not magic.cast_slot(&"x"):
		failures.append("freeze did not cast")
	if not boss.is_frozen():
		failures.append("the boss did not freeze")
	if not is_equal_approx(float(boss.movement_speed), 0.0):
		failures.append("the frozen boss still moves (%.2f m/s)" % float(boss.movement_speed))
	for _i in 140:
		await physics_frame
		if not boss.is_frozen():
			break
	if boss.is_frozen():
		failures.append("the freeze never expired")
	elif not is_equal_approx(float(boss.movement_speed), 3.0):
		failures.append("the unfrozen boss kept the frozen speed (%.2f)" % float(boss.movement_speed))
	boss.movement_speed = 0.0  # re-park for the reflect test

	# --- E. Reflect: negates a boss-sourced hit, returns its power, expires. ---
	mana.reset()
	if not magic.cast_slot(&"y"):
		failures.append("reflect did not cast")
	if not magic.reflect_active():
		failures.append("the reflect window did not open")
	var player_start := float(player_health.current_health)
	boss_start = float(boss_health.current_health)
	var boss_hit := _event(12.0)
	boss_hit.source = boss
	player._resolve_incoming_damage(boss_hit)
	if not is_equal_approx(float(player_health.current_health), player_start):
		failures.append("reflect did not negate the hit (%.1f -> %.1f)" % [
			player_start, float(player_health.current_health),
		])
	if not is_equal_approx(float(boss_health.current_health), boss_start - 10.0):
		failures.append("reflect returned %.1f (expected 10)" % [
			boss_start - float(boss_health.current_health),
		])
	for _i in 220:
		await physics_frame
		if not magic.reflect_active():
			break
	if magic.reflect_active():
		failures.append("the reflect window never closed")
	else:
		var after_hit := _event(12.0)
		after_hit.source = boss
		player._resolve_incoming_damage(after_hit)
		if not is_equal_approx(float(player_health.current_health), player_start - 12.0):
			failures.append("a post-window hit did not land normally (%.1f -> %.1f)" % [
				player_start, float(player_health.current_health),
			])
		if not is_equal_approx(float(boss_health.current_health), boss_start - 10.0):
			failures.append("a post-window hit still reflected damage (%.1f)" % float(boss_health.current_health))

	arena.free()

	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)

	if failures.is_empty():
		print("SPELL POOL CHECK: PASS (distinct slots/costs, heal+clamp, firebolt pipeline, freeze root/release, reflect return+expiry)")
		quit(0)
	else:
		for failure in failures:
			printerr("SPELL POOL CHECK FAILURE: " + failure)
		quit(1)

func _event(amount: float) -> DamageEvent:
	var event := DamageEvent.new()
	event.amount = amount
	return event

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
