class_name ComboData
extends Resource
## A light-attack chain (guide §9/§10): ordered steps, played in sequence as
## inputs buffer through each one. Sprint 07 will append the automatic
## finisher after the last step. `reset_timeout` is how long the chain stays
## alive for a follow-up press after a step ends without buffered input.

@export var steps: Array[ComboStepData] = []
## The automatic finisher (Sprint 07): plays after the last chain step with
## no extra input (D-024). Null means the chain simply ends. Post-MVP this
## becomes configurable sequences (Sprint 39).
@export var finisher: ComboStepData
@export var reset_timeout := 0.35
