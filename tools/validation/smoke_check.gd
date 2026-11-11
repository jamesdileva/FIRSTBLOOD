extends SceneTree
## Headless project smoke check. Run from the project root:
##   cmd //c godot --headless --path . -s res://tools/validation/smoke_check.gd
## Exits 0 on PASS, 1 on FAIL. Extend REQUIRED_* as systems are added.

const REQUIRED_ACTIONS := [
	"move_left", "move_right", "move_forward", "move_back",
	"attack", "block", "dodge", "pause", "debug_toggle",
	"spell_modifier", "spell_a", "spell_b", "spell_x", "spell_y",
	"camera_left", "camera_right", "camera_up", "camera_down",
]

const REQUIRED_PATHS := [
	"res://game/scenes/arena/arena.tscn",
	"res://game/scenes/player/player.tscn",
	"res://game/scenes/bosses/new_gladiator.tscn",
	"res://game/scripts/player/player_controller.gd",
	"res://game/scripts/camera/third_person_camera.gd",
	"res://game/scripts/debug/debug_overlay.gd",
	"res://game/scripts/combat/combat_types.gd",
	"res://game/scripts/combat/damage_event.gd",
	"res://game/scripts/combat/hitbox_component.gd",
	"res://game/scripts/combat/hurtbox_component.gd",
	"res://game/scripts/combat/combo_data.gd",
	"res://game/scripts/combat/combo_step_data.gd",
	"res://game/scripts/combat/health_component.gd",
	"res://game/scripts/progression/progression_component.gd",
	"res://game/scenes/ui/hud.tscn",
	"res://game/scripts/ui/hud.gd",
	"res://game/scenes/ui/title_screen.tscn",
	"res://game/scripts/ui/title_screen.gd",
	"res://game/scripts/arena/match_flow.gd",
	"res://tools/validation/playthrough_check.gd",
	"res://game/resources/attacks/player_light_combo.tres",
	"res://game/scenes/ui/boss_select.tscn",
	"res://game/scripts/ui/boss_select.gd",
	"res://game/scripts/arena/match_setup.gd",
	"res://game/scripts/arena/arena.gd",
	"res://game/scripts/bosses/boss_entry.gd",
	"res://game/scripts/bosses/boss_roster.gd",
	"res://game/resources/bosses/boss_roster.tres",
	"res://game/scenes/bosses/sparring_gladiator.tscn",
	"res://game/scripts/bosses/boss_controller.gd",
	"res://game/scripts/bosses/boss_brain.gd",
	"res://game/scripts/bosses/boss_attack_data.gd",
	"res://game/scripts/debug/combat_debug.gd",
]

func _initialize() -> void:
	# D-065 save isolation: checks never touch the user's real save.
	OS.set_environment("FIRSTBLOOD_CHECK_SAVE", "1")
	if FileAccess.file_exists("user://check_save.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://check_save.json"))
	var failures: PackedStringArray = []

	for action in REQUIRED_ACTIONS:
		if not InputMap.has_action(action):
			failures.append("missing input action: %s" % action)

	for path in REQUIRED_PATHS:
		if load(path) == null:
			failures.append("failed to load: %s" % path)

	var main_scene: PackedScene = load("res://game/scenes/arena/arena.tscn")
	if main_scene == null:
		failures.append("main scene failed to load")
	else:
		var instance := main_scene.instantiate()
		if instance == null:
			failures.append("main scene failed to instantiate")
		else:
			instance.free()

	if failures.is_empty():
		print("SMOKE CHECK: PASS (%d input actions, %d resources OK)" % [
			REQUIRED_ACTIONS.size(), REQUIRED_PATHS.size(),
		])
		quit(0)
	else:
		for failure in failures:
			printerr("SMOKE CHECK FAILURE: " + failure)
		quit(1)
