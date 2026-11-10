extends Node
## Sprint 22 match flow (D-071): victory/defeat/pause/retry. Polls (D-068)
## player/boss death, counts a readable 1.2 s delay, then shows the outcome
## overlay. Self-healing: a retry that heals both sides returns the flow to
## RUNNING even if the reset bypassed this component. Pause freezes the tree
## by engine semantics (D-072); this node runs ALWAYS to handle resume.

signal match_state_changed(new_state: MatchState)

enum MatchState { RUNNING, VICTORY, DEFEAT }

@export var victory_delay := 1.2
@export var defeat_delay := 1.2

var state: MatchState = MatchState.RUNNING
var _pending := ""  # "", "player", "boss"
var _countdown := 0.0
var _victory_panel: Control
var _defeat_panel: Control
var _pause_panel: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_panels()

func _process(delta: float) -> void:
	var tree := get_tree()
	if Input.is_action_just_pressed("pause"):
		tree.paused = not tree.paused
		_pause_panel.visible = tree.paused
	if tree.paused:
		if Input.is_action_just_pressed("retry"):
			_reset_match()
		return
	if Input.is_action_just_pressed("to_title") and state != MatchState.RUNNING:
		to_title()
		return
	match state:
		MatchState.RUNNING:
			_tick_running(delta)
		MatchState.VICTORY, MatchState.DEFEAT:
			# self-heal: a retry that revived both sides returns to RUNNING
			if not _player_dead() and not _boss_dead():
				_set_state(MatchState.RUNNING)
				_hide_panels()

func _tick_running(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	var boss := get_tree().get_first_node_in_group("boss")
	var player_dead: bool = player != null and player.is_dead()
	var boss_dead: bool = boss != null and boss.is_dead()
	if _pending != "":
		_countdown -= delta
		# revived mid-countdown (universal retry): cancel
		if (_pending == "player" and not player_dead) or (_pending == "boss" and not boss_dead):
			_pending = ""
			return
		if _countdown <= 0.0:
			_finish_match(_pending)
		return
	if player_dead:
		_pending = "player"
		_countdown = defeat_delay
		return
	if boss_dead:
		_pending = "boss"
		_countdown = victory_delay
		return

func _finish_match(kind: String) -> void:
	_pending = ""
	if kind == "boss":
		_set_state(MatchState.VICTORY)
		_victory_panel.visible = true
	else:
		_set_state(MatchState.DEFEAT)
		_defeat_panel.visible = true

func _set_state(new_state: MatchState) -> void:
	if state == new_state:
		return
	state = new_state
	match_state_changed.emit(new_state)

## D-058 semantics: a full fight reset to spawn positions.
func _reset_match() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("reset_for_retry"):
		player.reset_for_retry()
	var boss := get_tree().get_first_node_in_group("boss")
	if boss != null and boss.has_method("reset"):
		boss.reset()
	tree_paused(false)
	_pending = ""
	_countdown = 0.0
	state = MatchState.RUNNING
	match_state_changed.emit(MatchState.RUNNING)
	_hide_panels()

func to_title() -> void:
	tree_paused(false)
	get_tree().change_scene_to_file("res://game/scenes/ui/title_screen.tscn")

func _player_dead() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	return player != null and player.has_method("is_dead") and player.is_dead()

func _boss_dead() -> bool:
	var boss := get_tree().get_first_node_in_group("boss")
	return boss != null and boss.has_method("is_dead") and boss.is_dead()

func tree_paused(paused: bool) -> void:
	get_tree().paused = paused

func _hide_panels() -> void:
	_victory_panel.visible = false
	_defeat_panel.visible = false
	_pause_panel.visible = false

func _build_panels() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MatchOver"
	layer.layer = 30
	add_child(layer)

	_victory_panel = _make_panel(layer, "VictoryPanel", Color(0.35, 0.28, 0.08, 0.55),
			"VICTORY", Color(1.0, 0.85, 0.3))
	_defeat_panel = _make_panel(layer, "DefeatPanel", Color(0.2, 0.05, 0.05, 0.6),
			"YOU DIED", Color(0.9, 0.25, 0.2))
	_pause_panel = _make_panel(layer, "PausePanel", Color(0.05, 0.05, 0.08, 0.6),
			"PAUSED", Color(0.85, 0.85, 0.9))

func _make_panel(layer: CanvasLayer, panel_name: String, tint: Color, title_text: String, title_color: Color) -> Control:
	var panel := Control.new()
	panel.name = panel_name
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = tint
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(dim)
	var title := Label.new()
	title.name = "Title"
	title.text = title_text
	title.add_theme_color_override("font_color", title_color)
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	panel.add_child(title)
	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "R — Retry      T — Title"
	hint.add_theme_color_override("font_color", Color(0.9, 0.9, 0.92, 1.0))
	hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.offset_top = 90.0
	hint.add_theme_font_size_override("font_size", 18)
	panel.add_child(hint)
	layer.add_child(panel)
	return panel
