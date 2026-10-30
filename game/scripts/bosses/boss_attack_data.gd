class_name BossAttackData
extends Resource
## One boss attack (guide §12): range, timing, payload, cooldown, selection
## weight. Sprint 11 inserts the TELEGRAPH state using `telegraph_duration`.

@export var attack_id := StringName("boss_light")
@export var animation := StringName("boss_attack_01")
@export var damage := 15.0
@export var stagger_damage := 8.0
@export var hit_type: CombatTypes.HitType = CombatTypes.HitType.NORMAL
## Usable distance band from the boss origin (meters).
@export var min_range := 1.0
@export var max_range := 2.5
@export var startup := 0.25
@export var active := 0.15
@export var recovery := 0.5
## Seconds before this attack can be selected again.
@export var cooldown := 2.0
## Selection weight (guide §12: weighted, not purely random).
@export var weight := 1.0
## Sprint 11: the boss will hold TELEGRAPH for this long before startup.
@export var telegraph_duration := 0.0
