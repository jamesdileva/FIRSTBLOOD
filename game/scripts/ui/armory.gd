extends Control
## Sprint 26 (D-079/080): the armory — the equip affordance between fights.
## Lists the gear catalog, toggles pieces with start_match (A / Enter),
## navigates with ui_up/ui_down, backs out with ui_cancel. Edits the
## GearLibrary loadout (static, save-backed) directly — no player needs to
## be alive here; the player's EquipmentComponent applies the loadout when
## the arena spawns. UI is code-built (the D-073 precedent).

const TITLE_SCENE := "res://game/scenes/ui/title_screen.tscn"

const GOLD := Color(1.0, 0.85, 0.3)
const INK := Color(0.05, 0.06, 0.05)
const PARCHMENT := Color(0.93, 0.88, 0.78)
const DIMMED := Color(0.55, 0.52, 0.48)
const WORN := Color(0.55, 0.85, 0.45)

var _catalog: GearCatalog
var _index := 0
var _rows: Array[PanelContainer] = []
var _worn_tags: Array[Label] = []

func _ready() -> void:
	GearLibrary.ensure_loaded()
	_catalog = GearLibrary.catalog()
	_build()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		_move(-1)
	elif event.is_action_pressed("ui_down"):
		_move(1)
	elif event.is_action_pressed("start_match"):
		_toggle()
	elif event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(TITLE_SCENE)

func _move(step: int) -> void:
	if _catalog.items.is_empty():
		return
	_index = wrapi(_index + step, 0, _catalog.items.size())
	_refresh()

func _toggle() -> void:
	if _catalog.items.is_empty():
		return
	# Stage the current loadout on a headless EquipmentComponent and let IT
	# own the one-piece-per-slot swap (D-079) — the component mirrors the
	# change into GearLibrary + the save (D-080).
	var staging := EquipmentComponent.new()
	staging.apply_ids(_loadout_ids())
	staging.toggle(_catalog.items[_index])
	_refresh()

func _loadout_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in GearLibrary.loadout:
		ids.append(id)
	return ids

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
	layout.add_theme_constant_override("separation", 10)
	add_child(layout)

	var title := Label.new()
	title.name = "Title"
	title.text = "ARMORY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", PARCHMENT)
	layout.add_child(title)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_theme_constant_override("separation", 8)
	layout.add_child(rows)

	for item in _catalog.items:
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(460, 0)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.11, 0.12, 0.1)
		style.set_corner_radius_all(6)
		style.set_border_width_all(2)
		style.border_color = Color.TRANSPARENT
		style.set_content_margin_all(10)
		row.add_theme_stylebox_override("panel", style)
		var row_layout := HBoxContainer.new()
		row_layout.add_theme_constant_override("separation", 14)
		row.add_child(row_layout)
		var name_label := Label.new()
		name_label.text = item.display_name
		name_label.custom_minimum_size = Vector2(240, 0)
		name_label.add_theme_font_size_override("font_size", 18)
		row_layout.add_child(name_label)
		var summary := Label.new()
		summary.text = item.summary()
		summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summary.add_theme_font_size_override("font_size", 14)
		summary.add_theme_color_override("font_color", DIMMED)
		row_layout.add_child(summary)
		var worn := Label.new()
		worn.text = "WORN"
		worn.add_theme_font_size_override("font_size", 14)
		worn.add_theme_color_override("font_color", WORN)
		row_layout.add_child(worn)
		rows.add_child(row)
		_rows.append(row)
		_worn_tags.append(worn)

	var totals := Label.new()
	totals.name = "Totals"
	totals.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	totals.add_theme_font_size_override("font_size", 15)
	totals.add_theme_color_override("font_color", GOLD)
	layout.add_child(totals)

	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "A — WEAR / REMOVE        B — BACK        UP / DOWN — CHOOSE"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", DIMMED)
	layout.add_child(hint)

	_refresh()

func _refresh() -> void:
	var worn_ids := _loadout_ids()
	var worn_items := GearLibrary.resolve(worn_ids)
	for i in _rows.size():
		var item: GearData = _catalog.items[i]
		var is_worn: bool = worn_ids.has(StringName(item.id))
		_worn_tags[i].visible = is_worn
		var style: StyleBoxFlat = _rows[i].get_theme_stylebox("panel")
		style.border_color = GOLD if i == _index else Color.TRANSPARENT
		style.bg_color = Color(0.14, 0.16, 0.12) if is_worn else Color(0.11, 0.12, 0.1)
		_rows[i].modulate = Color.WHITE if i == _index else DIMMED
	var hp := 0.0
	var armor := 0.0
	var attack := 0.0
	var move := 0.0
	var aspd := 0.0
	for item in worn_items:
		hp += item.hp_bonus
		armor += item.armor
		attack += item.attack_bonus
		move += item.movement_bonus
		aspd += item.attack_speed_bonus
	var totals := get_node("Layout/Totals") as Label
	var parts: PackedStringArray = []
	if hp != 0.0:
		parts.append("HP +%.0f" % hp)
	if armor != 0.0:
		parts.append("ARMOR %.0f" % armor)
	if attack != 0.0:
		parts.append("ATTACK +%.0f" % attack)
	if move != 0.0:
		parts.append("SPEED +%.2f" % move)
	if aspd != 0.0:
		parts.append("SWING +%.0f%%" % (aspd * 100.0))
	totals.text = "WEARING:  " + ("  ·  ".join(parts) if not parts.is_empty() else "(nothing)")
