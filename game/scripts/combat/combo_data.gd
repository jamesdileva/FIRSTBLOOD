class_name ComboData
extends Resource
## A light-attack chain (guide §9/§10): ordered steps, played in sequence as
## inputs buffer through each one. Sprint 07 will append the automatic
## finisher after the last step. `reset_timeout` is how long the chain stays
## alive for a follow-up press after a step ends without buffered input.

@export var steps: Array[ComboStepData] = []
## The automatic finisher SEQUENCE (Sprint 39, D-109): the steps play in
## order after the last chain step with no extra input (D-024). Empty means
## the chain simply ends. Any length — a 1-element chain is the old single
## finisher, a 2-element chain proves the automatic chaining.
@export var finisher_chain: Array[ComboStepData] = []
@export var reset_timeout := 0.35
