extends Control
## Sprint 22 title screen (D-072): the game's entry point. Start (Enter,
## Space, gamepad A/Start) fights; Esc quits. Reads the real save to show
## the continue level — never the check-save override (the checks don't run
## the title).

const ARENA_SCENE := "res://game/scenes/arena/arena.tscn"

func _ready() -> void:
	var save := ProgressionComponent.read_save()
	var level := maxi(int(save.get("level", 1)), 1)
	var xp := float(save.get("xp", 0.0))
	if level > 1 or xp > 0.0:
		$SaveLabel.text = "CONTINUE — LV %d" % level
	else:
		$SaveLabel.text = ""

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("start_match"):
		get_tree().change_scene_to_file(ARENA_SCENE)
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		get_tree().quit()
