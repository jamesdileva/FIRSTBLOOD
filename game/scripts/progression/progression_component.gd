class_name ProgressionComponent
extends Node
## Sprint 19 progression (guide §23): XP accumulation, level thresholds, and
## a versioned local save. XP sources (D-062): actual damage dealt to the
## boss (bound lazily to its Health), a victory bonus on boss death, and a
## defeat consolation on player death. Saved after meaningful events only.

signal xp_gained(amount: float, total_xp: float, level: int)
signal level_up(new_level: int)

@export var victory_xp := 150.0
@export var defeat_xp := 25.0
## XP required for level 2 (level N needs base x growth^(N-1)).
@export var xp_base := 80.0
@export var xp_growth := 1.5

## Sprint 20 stat rates (D-066): derived from the level, applied by the
## player on level-up and load. HP per level; attack damage per level;
## movement speed per level; attack-speed multiplier per level (4%%).
@export var hp_per_level := 10.0
@export var attack_per_level := 2.0
@export var move_speed_per_level := 0.15
@export var attack_speed_per_level := 0.04

const SAVE_VERSION := 1

## D-065 save isolation: checks set FIRSTBLOOD_CHECK_SAVE so automation
## never touches the user's real save file.
static func _save_path() -> String:
	if OS.get_environment("FIRSTBLOOD_CHECK_SAVE") != "":
		return "user://check_save.json"
	return "user://save.json"

var xp := 0.0
var level := 1
## Lifetime XP earned (never decreases on level-up spend) — the HUD metric.
var total_earned := 0.0

var _boss_bound := false

func _ready() -> void:
	load_save()
	var player_health := get_node_or_null("../Health") as HealthComponent
	if player_health != null:
		player_health.died.connect(award_defeat_xp)

func _physics_process(_delta: float) -> void:
	_bind_boss()

func xp_required() -> float:
	return xp_base * pow(xp_growth, float(level - 1))

## D-062: XP for actual damage the boss took. Blocked/guarded hits never
## reach this path. Negative/zero amounts are ignored (XP never decreases).
func add_xp(amount: float) -> void:
	if amount <= 0.0:
		return
	xp += amount
	total_earned += amount
	xp_gained.emit(amount, xp, level)
	var leveled := false
	while xp >= xp_required():
		xp -= xp_required()
		level += 1
		leveled = true
		level_up.emit(level)
	if leveled:
		save()

## Victory bonus + save hook (architecture: failure still advances the
## player, so defeat pays its own consolation through add_xp on death).
func award_victory_xp() -> void:
	add_xp(victory_xp)
	save()

func award_defeat_xp() -> void:
	add_xp(defeat_xp)
	save()

func save() -> void:
	# D-080: read-merge — the save file holds per-system keys (Sprint 26's
	# gear owns "equipment"); each writer preserves the others'.
	var data := read_save()
	data["version"] = SAVE_VERSION
	data["xp"] = xp
	data["level"] = level
	var file := FileAccess.open(_save_path(), FileAccess.WRITE)
	if file == null:
		push_warning("Progression save failed: %d" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data))
	file.close()

## Clears XP/level AND the save file — used by checks for clean baselines.
func reset_progression() -> void:
	xp = 0.0
	level = 1
	total_earned = 0.0
	_current_threshold_reset()
	var save_file := _save_path()
	if FileAccess.file_exists(save_file):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_file))

func _current_threshold_reset() -> void:
	pass

## Static read for UI (the title screen): the parsed save dict, or {}.
static func read_save() -> Dictionary:
	if not FileAccess.file_exists(_save_path()):
		return {}
	var file := FileAccess.open(_save_path(), FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func load_save() -> void:
	if not FileAccess.file_exists(_save_path()):
		return
	var file := FileAccess.open(_save_path(), FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Progression save unreadable — starting fresh.")
		return
	if int(parsed.get("version", 0)) != SAVE_VERSION:
		push_warning("Progression save version mismatch — starting fresh.")
		return
	xp = maxf(float(parsed.get("xp", 0.0)), 0.0)
	level = maxi(int(parsed.get("level", 1)), 1)
	# total_earned is rebuilt from the thresholds on load (the save stores
	# only xp/level; spending history is not persisted).
	total_earned = 0.0
	var check_level := 1
	while check_level < level:
		total_earned += xp_base * pow(xp_growth, float(check_level - 1))
		check_level += 1
	total_earned += xp

func _bind_boss() -> void:
	if _boss_bound:
		return
	var boss := get_tree().get_first_node_in_group("boss")
	if boss == null:
		return
	var boss_health := boss.get_node_or_null("Health") as HealthComponent
	if boss_health == null:
		return
	# D-062: XP = actual damage the boss took (blocked hits never reach it).
	boss_health.damaged.connect(_on_boss_damaged)
	boss_health.died.connect(award_victory_xp)
	_boss_bound = true

func _on_boss_damaged(event: DamageEvent) -> void:
	add_xp(event.amount)
