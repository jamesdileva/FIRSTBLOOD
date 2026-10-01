class_name ComboStepData
extends Resource
## One swing in a combo chain (guide §9): timing, payload identity, and the
## input-buffer window. All times are seconds measured from the step's start.

@export var attack_id := StringName("light_01")
@export var animation := StringName("attack_01")
@export var damage := 10.0
@export var stagger_damage := 5.0
@export var startup := 0.10
@export var active := 0.12
@export var recovery := 0.25
## Attack presses inside [buffer_open, buffer_close] are remembered (once)
## and consumed when the step ends, chaining into the next step (D-023).
@export var buffer_open := 0.05
@export var buffer_close := 0.30

func total_duration() -> float:
	return startup + active + recovery
