class_name SpellData
extends Resource
## Sprint 29 (D-088): one spell — data only. `effect` is the dispatch key
## the cast path resolves (Sprint 29 ships only the spark no-op; Sprint 30's
## pool fills the dispatcher). `mana_cost` is paid through the
## ManaComponent's atomic spend before anything happens.

@export var id := ""
@export var display_name := "UNNAMED"
@export var mana_cost := 0.0
@export var effect := &"spark"
## Sprint 30 (D-089): generic effect params — `power` means what the effect
## says (heal: HP restored; fire: projectile damage; reflect: damage
## returned) and `duration` is seconds for timed effects (freeze, reflect).
@export var power := 0.0
@export var duration := 0.0
## Sprint 37 (D-105): the Flame Set's fire variant — when a set with the
## `&"flame_bolt"` effect is active, the projectile explodes on impact:
## `blast_damage` to every enemy hurtbox within `blast_radius` (0 = never).
@export var blast_damage := 0.0
@export var blast_radius := 0.0
