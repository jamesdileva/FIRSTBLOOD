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
	"res://game/scenes/bosses/boss_placeholder.tscn",
	"res://game/scripts/player/player_controller.gd",
	"res://game/scripts/camera/third_person_camera.gd",
	"res://game/scripts/debug/debug_overlay.gd",
	"res://game/scripts/combat/combat_types.gd",
	"res://game/scripts/combat/damage_event.gd",
	"res://game/scripts/combat/hitbox_component.gd",
	"res://game/scripts/combat/hurtbox_component.gd",
	"res://game/scripts/combat/combo_data.gd",
	"res://game/scripts/combat/combo_step_data.gd",
	"res://game/resources/attacks/player_light_combo.tres",
	"res://game/scripts/debug/combat_debug.gd",
]

func _initialize() -> void:
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
