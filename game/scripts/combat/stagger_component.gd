class_name StaggerComponent
extends Node
## Stagger model (guide §14): accumulated stagger_damage from resolved
## DamageEvents crosses a threshold, opens a timed punish window, then
## re-arms with resistance so windows can't be farmed. The owner state
## machine drives visuals/attacks; this component owns only the numbers.

signal staggered
signal recovered

@export var stagger_threshold := 30.0
@export var stagger_duration := 2.0
## Threshold multiplier applied after every stagger (D-043 resistance).
@export var resistance_growth := 1.5

var _accumulated := 0.0
var _current_threshold := 0.0
var _staggered := false
var _elapsed := 0.0

func _ready() -> void:
	reset()

func is_staggered() -> bool:
	return _staggered

## Returns true when THIS event crossed the threshold and opened the window.
func add_stagger(event: DamageEvent) -> bool:
	if _staggered or event.stagger_damage <= 0.0:
		return false
	_accumulated += event.stagger_damage
	if _accumulated < _current_threshold:
		return false
	_staggered = true
	_elapsed = 0.0
	staggered.emit()
	return true

## Ticks the punish window; returns true when it ends and re-arms.
func tick_recovery(delta: float) -> bool:
	if not _staggered:
		return false
	_elapsed += delta
	if _elapsed < stagger_duration:
		return false
	breakout()
	return true

## Sprint 14 (D-045): force-end the window without waiting for the timer —
## the finisher landed during the stagger. Resistance still applies, and
## `recovered` fires so the owner can react.
func breakout() -> void:
	if not _staggered:
		return
	_staggered = false
	_accumulated = 0.0
	_elapsed = 0.0
	_current_threshold *= resistance_growth
	recovered.emit()

func reset() -> void:
	_accumulated = 0.0
	_current_threshold = stagger_threshold
	_staggered = false
	_elapsed = 0.0
