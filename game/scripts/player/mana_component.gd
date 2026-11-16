class_name ManaComponent
extends Node
## Sprint 28 (D-085): the mana subsystem — architecture §14: mana depletes
## on use and regenerates after a delay; exact values are tuning exports.
## `spend()` is atomic (all-or-nothing — no partial spends, never negative);
## every spend restarts the regen delay; after the delay, mana regenerates
## at a flat rate per second until full (the D-068 poll pattern). Nothing
## consumes mana until the Sprint 29/30 spells (D-086) — this component is
## the single API every future spell calls.

signal mana_changed(current: float, max_mana: float)
signal mana_spent(amount: float)

@export var max_mana := 100.0
@export var regen_delay := 3.0
@export var regen_rate := 20.0

var current_mana := 100.0
var _delay_left := 0.0

func _ready() -> void:
	current_mana = max_mana

## All-or-nothing. Returns false (and spends nothing) when the pool is
## short — the caller decides what "not enough mana" means.
func spend(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if current_mana < amount:
		return false
	current_mana -= amount
	_delay_left = regen_delay
	mana_spent.emit(amount)
	mana_changed.emit(current_mana, max_mana)
	return true

func is_available(amount: float) -> bool:
	return current_mana >= amount

## D-058 full-reset semantics: retry/restart refills the pool and clears
## the regen delay.
func reset() -> void:
	current_mana = max_mana
	_delay_left = 0.0
	mana_changed.emit(current_mana, max_mana)

func _physics_process(delta: float) -> void:
	if current_mana >= max_mana:
		return
	if _delay_left > 0.0:
		_delay_left -= delta
		return
	var before := current_mana
	current_mana = minf(current_mana + regen_rate * delta, max_mana)
	if not is_equal_approx(current_mana, before):
		mana_changed.emit(current_mana, max_mana)
