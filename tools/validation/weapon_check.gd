extends SceneTree
## Sprint 27 weapon-variants verification (headless). Run:
##   cmd //c godot --headless --path . -s res://tools/validation/weapon_check.gd
## Asserts the roadmap checklist — weapon data changes attack behavior and
## visuals correctly: catalog integrity (>= 2 WEAPON pieces, every combo
## resolves with steps + finisher), the D-083 default-first rule, the combo
## swap + payload carried from the weapon's own step data, blade visuals
## (tint + length) following and restoring, and the real path armory ->
## equip the spear -> fight with the spear's combo and blade. Exits 0 on
## PASS, 1 on FAIL.

const SETTLE_FRAMES := 30
const TITLE_SCENE := "res://game/scenes/ui/title_screen.tscn"

func _initialize() -> void:
	_run()

func _run() -> void:
	var failures: PackedStringArray = []
	OS.set_environment("FIRSTBLOOD_CHECK_SAVE", "1")
	var check_save := ProjectSettings.globalize_path("user://check_save.json")
	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)
	GearLibrary.reload_from_save()

	# --- A. Weapon catalog integrity. ---
	var gear_catalog := GearLibrary.catalog()
	if gear_catalog == null:
		printerr("WEAPON CHECK FAILURE: the gear catalog failed to load")
		quit(1)
		return
	var weapons: Array[WeaponData] = []
	for item in gear_catalog.items:
		var weapon := item as WeaponData
		if weapon == null:
			continue
		weapons.append(weapon)
		if weapon.combo == null:
			failures.append("weapon %s carries no combo" % weapon.id)
		elif weapon.combo.steps.is_empty():
			failures.append("weapon %s's combo has no steps" % weapon.id)
		elif weapon.combo.finisher == null:
			failures.append("weapon %s's combo has no finisher" % weapon.id)
	if weapons.size() < 2:
		failures.append("the catalog holds fewer than two weapons (%d)" % weapons.size())
	var dull := _weapon(weapons, "dull_sword")
	var gladius := _weapon(weapons, "legion_gladius")
	var spear := _weapon(weapons, "trainers_spear")
	if dull == null or gladius == null or spear == null:
		printerr("WEAPON CHECK FAILURE: expected starter weapons missing")
		quit(1)
		return
	var default_combo: ComboData = load("res://game/resources/attacks/player_light_combo.tres")
	if dull.combo != default_combo:
		failures.append("the Dull Sword does not reference the default combo")

	# --- B. Behavior: default -> weapon -> default; payload from weapon data. ---
	var player_scene: PackedScene = load("res://game/scenes/player/player.tscn")
	var player = player_scene.instantiate()
	root.add_child(player)
	await _wait(SETTLE_FRAMES)
	var equipment: EquipmentComponent = player.get_node("Equipment")
	if player.combo != default_combo:
		failures.append("a fresh player did not start on the scene default combo")
	equipment.equip(gladius)
	if player.combo != gladius.combo:
		failures.append("equipping the gladius did not swap the combo")
	player._push_step_payload(player.combo.steps[0])
	var hitbox_damage: float = float(player.get_node("AttackHitbox").damage)
	if not is_equal_approx(hitbox_damage, 12.0):
		failures.append("the gladius payload is wrong: %.1f (expected 12)" % hitbox_damage)
	equipment.unequip_slot(&"WEAPON")
	if player.combo != default_combo:
		failures.append("unequipping the weapon did not restore the default combo")

	# --- C. Visuals: the blade tint + length follow and restore. ---
	var blade: MeshInstance3D = player.get_node_or_null("Visual/WeaponBlade")
	if blade == null:
		failures.append("the player scene has no WeaponBlade mesh")
	else:
		var material := blade.material_override as StandardMaterial3D
		if material == null:
			failures.append("the blade has no runtime material override")
		else:
			equipment.equip(gladius)
			if material.albedo_color != gladius.visual_color:
				failures.append("the blade did not take the gladius tint")
			if not is_equal_approx(float(blade.scale.y), 0.9):
				failures.append("the blade did not take the gladius length (%.2f)" % float(blade.scale.y))
			equipment.unequip_slot(&"WEAPON")
			if material.albedo_color != player.DEFAULT_BLADE_COLOR:
				failures.append("the blade did not restore the default tint")
			if not is_equal_approx(float(blade.scale.y), 1.0):
				failures.append("the blade did not restore the default length (%.2f)" % float(blade.scale.y))
	player.free()

	# --- D. Real path: armory -> equip the spear -> fight with it. ---
	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)
	GearLibrary.reload_from_save()
	var title_scene: PackedScene = load(TITLE_SCENE)
	var title: Control = title_scene.instantiate()
	root.add_child(title)
	current_scene = title
	await _wait(5)
	Input.parse_input_event(_key(KEY_G, true))
	await _wait(2)
	Input.parse_input_event(_key(KEY_G, false))
	var armory: Control = null
	for _i in 120:
		await physics_frame
		if current_scene != null and current_scene.name == "Armory":
			armory = current_scene
			break
	if armory == null:
		failures.append("the armory action did not open the armory")
	else:
		# rows are in catalog order: cap(0) cuirass(1) wraps(2) sandals(3)
		# dull_sword(4) gladius(5) spear(6) -> six downs, then wear
		for _step in 6:
			Input.parse_input_event(_key(KEY_DOWN, true))
			await _wait(2)
			Input.parse_input_event(_key(KEY_DOWN, false))
			await _wait(2)
		Input.parse_input_event(_key(KEY_ENTER, true))
		await _wait(2)
		Input.parse_input_event(_key(KEY_ENTER, false))
		await _wait(2)
		if not GearLibrary.loadout.has(StringName("trainers_spear")):
			failures.append("the armory toggle did not wear the spear (%s)" % [GearLibrary.loadout])
		Input.parse_input_event(_key(KEY_ESCAPE, true))
		await _wait(2)
		Input.parse_input_event(_key(KEY_ESCAPE, false))
		var back := false
		for _i in 120:
			await physics_frame
			if current_scene != null and current_scene.name == "TitleScreen":
				back = true
				break
		if not back:
			failures.append("ui_cancel did not return to the title")
		else:
			current_scene.start_fight()
			var select_ready := false
			for _i in 120:
				await physics_frame
				if current_scene != null and current_scene.name == "BossSelect":
					select_ready = true
					break
			if not select_ready:
				failures.append("start_fight did not reach the boss select screen")
			else:
				Input.parse_input_event(_key(KEY_ENTER, true))
				await _wait(2)
				Input.parse_input_event(_key(KEY_ENTER, false))
				var arena_ready := false
				for _i in 120:
					await physics_frame
					if current_scene != null and current_scene.name == "Arena":
						arena_ready = true
						break
				if not arena_ready:
					failures.append("confirm did not reach the arena")
				else:
					await _wait(SETTLE_FRAMES)
					var fight_player = get_first_node_in_group("player")
					if fight_player == null:
						failures.append("no player spawned for the weapon fight")
					elif fight_player.combo != spear.combo:
						failures.append("the spawned player did not swing the spear's combo")
					else:
						var fight_blade: MeshInstance3D = fight_player.get_node_or_null("Visual/WeaponBlade")
						var fight_material := fight_blade.material_override as StandardMaterial3D if fight_blade != null else null
						if fight_material == null or fight_material.albedo_color != spear.visual_color:
							failures.append("the spawned player's blade did not take the spear tint")
				current_scene.free()
				current_scene = null

	if FileAccess.file_exists(check_save):
		DirAccess.remove_absolute(check_save)

	if failures.is_empty():
		print("WEAPON CHECK: PASS (catalog, default-first, combo+payload swap, blade visuals, armory->fight with the spear)")
		quit(0)
	else:
		for failure in failures:
			printerr("WEAPON CHECK FAILURE: " + failure)
		quit(1)

func _weapon(weapons: Array[WeaponData], id: String) -> WeaponData:
	for weapon in weapons:
		if weapon.id == id:
			return weapon
	return null

func _key(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = pressed
	return event

func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame
