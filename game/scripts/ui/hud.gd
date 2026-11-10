extends CanvasLayer
## Sprint 21 HUD (D-068): always-on combat information, polled every frame
## from group lookups — robust to retry/resets/revives with no cross-node
## wiring. Shows only player-facing values (D-069): HP, XP/level, boss HP,
## and the telegraph warning. Debug diagnostics stay in the F1 overlay.

@onready var _player_bar: ProgressBar = $PlayerBar
@onready var _xp_bar: ProgressBar = $XPBar
@onready var _level_label: Label = $LevelLabel
@onready var _boss_panel: Control = $BossPanel
@onready var _boss_bar: ProgressBar = $BossPanel/BossBar
@onready var _boss_name_label: Label = $BossPanel/BossName
@onready var _telegraph_bar: ProgressBar = $BossPanel/TelegraphBar

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		var health := player.get_node_or_null("Health") as HealthComponent
		if health != null:
			_player_bar.max_value = health.max_health
			_player_bar.value = health.current_health
		var progression := player.get_node_or_null("Progression")
		if progression != null:
			_xp_bar.max_value = progression.xp_required()
			_xp_bar.value = progression.xp
			_level_label.text = "LV %d" % progression.level
	var boss := get_tree().get_first_node_in_group("boss")
	if boss == null:
		_boss_panel.visible = false
		_telegraph_bar.visible = false
		return
	var boss_health := boss.get_node_or_null("Health") as HealthComponent
	var boss_alive: bool = boss_health != null and not boss_health.is_dead()
	_boss_panel.visible = boss_alive
	if boss_health != null and boss_alive:
		_boss_bar.max_value = boss_health.max_health
		_boss_bar.value = boss_health.current_health
	# D-070: telegraph warning bar — mirrors the world marker's language.
	var telegraphing: bool = boss.state == boss.State.TELEGRAPH and boss._current_attack != null
	_telegraph_bar.visible = telegraphing
	if telegraphing:
		var total: float = boss._current_attack.telegraph_duration
		_telegraph_bar.max_value = total
		_telegraph_bar.value = maxf(total - boss.state_elapsed, 0.0)
		var heavy: bool = boss._current_attack.hit_type != CombatTypes.HitType.NORMAL
		_telegraph_bar.modulate = Color(1.0, 0.25, 0.15) if heavy else Color(1.0, 0.85, 0.2)
