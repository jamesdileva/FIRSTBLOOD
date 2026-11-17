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
## Selection weight (guide §12: weighted, not purely random). 0 = never
## brain-selected — reserved for followup-chained attacks.
@export var weight := 1.0
## Sprint 11: the boss will hold TELEGRAPH for this long before startup.
@export var telegraph_duration := 0.0
## Sprint 12: attack id chained automatically after this attack's recovery
## (the melee string). Empty = the string ends here.
@export var followup := StringName("")
## Sprint 12: forward lunge toward the target during the active window
## (the "approach/pressure" attack). 0 = rooted.
@export var lunge_speed := 0.0
## Sprint 31 (D-092): per-attack footprint — scales the attack BoxShape and
## the ground marker (ONE = the scene's base shape; a wide slab makes a
## shockwave, the marker mirrors it for the danger zone).
@export var hitbox_size_scale := Vector3.ONE
## Sprint 32 (D-094): how the ATTACK phase behaves — &"melee" (the hitbox
## window, default), &"projectile" (spawn a bolt toward the target), or
## &"shield" (a timed self-buff; `duration` seconds, `damage` returned).
@export var attack_shape := &"melee"
## Sprint 32: a status applied by this attack's hits (e.g. &"petrify"),
## carried by the DamageEvent to the victim's resolution.
@export var status_effect := StringName("")
## Sprint 32: seconds for timed shapes (the shield's mirror window).
@export var duration := 0.0
