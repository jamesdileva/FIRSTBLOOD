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

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

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
	var data := {"version": SAVE_VERSION, "xp": xp, "level": level}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
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
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func _current_threshold_reset() -> void:
	pass

func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
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
