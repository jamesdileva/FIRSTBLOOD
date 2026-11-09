class_name HealthComponent
extends Node
## Damage/death state (guide §11). Consumes **resolved** DamageEvents only
## (D-027): on the player that means the controller's hit_blocked/hit_mitigated/
## hit_taken signals; on the boss (no mitigation layer) the hurtbox's raw
## `damaged` signal is the resolved path.

signal health_changed(current: float, maximum: float)
signal damaged(event: DamageEvent)
signal died

@export var max_health := 100.0

var current_health := 0.0
var _dead := false

func _ready() -> void:
	reset()

func is_dead() -> bool:
	return _dead

func apply_damage(event: DamageEvent) -> void:
	if _dead or event.amount <= 0.0:
		return
	# The event reports the ACTUAL damage dealt (overkill clamped at the
	# remaining health) — XP and feedback must not reward phantom damage.
	var applied := minf(event.amount, current_health)
	current_health = maxf(current_health - event.amount, 0.0)
	event.amount = applied
	damaged.emit(event)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		_dead = true
		died.emit()

## Full restore for retry flows (Sprint 22) — also the setup call for tests.
func reset() -> void:
	current_health = max_health
	_dead = false
	health_changed.emit(current_health, max_health)
