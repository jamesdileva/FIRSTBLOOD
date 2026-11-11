extends Control
## Sprint 25 (D-076/077): boss selection — the screen between the title and
## the arena. Reads the data roster, cycles it with ui_left/ui_right (d-pad
## and arrows), confirms with start_match (Enter / Space / A / Start), backs
## out with ui_cancel (Esc / B). The choice goes into MatchSetup; the arena
## swaps its boss from it. UI is code-built (the D-073 precedent).

const TITLE_SCENE := "res://game/scenes/ui/title_screen.tscn"
const ARENA_SCENE := "res://game/scenes/arena/arena.tscn"

const GOLD := Color(1.0, 0.85, 0.3)
const INK := Color(0.06, 0.05, 0.04)
const PARCHMENT := Color(0.93, 0.88, 0.78)
const DIMMED := Color(0.55, 0.52, 0.48)

var _roster: BossRoster
var _index := 0
var _cards: Array[PanelContainer] = []
var _name_labels: Array[Label] = []

func _ready() -> void:
	_roster = MatchSetup.roster()
	if MatchSetup.selected != null:
		var found := _roster.entries.find(MatchSetup.selected)
		if found >= 0:
			_index = found
	_build()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_move(-1)
	elif event.is_action_pressed("ui_right"):
		_move(1)
	elif event.is_action_pressed("start_match"):
		_confirm()
	elif event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(TITLE_SCENE)

func _move(step: int) -> void:
	if _roster.entries.is_empty():
		return
	_index = wrapi(_index + step, 0, _roster.entries.size())
	_refresh()

func _confirm() -> void:
	if _roster.entries.is_empty():
		return
	MatchSetup.selected = _roster.entries[_index]
	get_tree().change_scene_to_file(ARENA_SCENE)

func _build() -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = INK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 28)
	add_child(layout)

	var title := Label.new()
	title.name = "Title"
	title.text = "SELECT YOUR OPPONENT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", PARCHMENT)
	layout.add_child(title)

	var cards := HBoxContainer.new()
	cards.name = "Cards"
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 32)
	layout.add_child(cards)

	for i in _roster.entries.size():
		var entry := _roster.entries[i]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(280, 140)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.1, 0.08)
		style.set_corner_radius_all(8)
		style.set_border_width_all(2)
		style.border_color = Color.TRANSPARENT
		style.set_content_margin_all(16)
		card.add_theme_stylebox_override("panel", style)
		var card_layout := VBoxContainer.new()
		card_layout.alignment = BoxContainer.ALIGNMENT_CENTER
		card_layout.add_theme_constant_override("separation", 8)
		card.add_child(card_layout)
		var name_label := Label.new()
		name_label.text = entry.display_name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 22)
		card_layout.add_child(name_label)
		var blurb := Label.new()
		blurb.text = entry.blurb
		blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.add_theme_font_size_override("font_size", 14)
		card_layout.add_child(blurb)
		cards.add_child(card)
		_cards.append(card)
		_name_labels.append(name_label)

	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "A — FIGHT        B — BACK        LEFT / RIGHT — CHOOSE"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", DIMMED)
	layout.add_child(hint)

	_refresh()

func _refresh() -> void:
	for i in _cards.size():
		var selected: bool = i == _index
		var style: StyleBoxFlat = _cards[i].get_theme_stylebox("panel")
		style.border_color = GOLD if selected else Color.TRANSPARENT
		_cards[i].modulate = Color.WHITE if selected else DIMMED
		_name_labels[i].add_theme_color_override("font_color", GOLD if selected else PARCHMENT)
