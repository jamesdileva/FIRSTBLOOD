class_name DamageEvent
extends RefCounted
## Structured damage payload (guide §6, D-014): the only sanctioned way damage
## intent crosses actors. Hitboxes create these; receivers decide what they mean.
## No receiver-side behavior is implemented in MVP — status_effect is a
## placeholder field reserved for post-MVP systems.

var source: Node
var amount := 0.0
var stagger_damage := 0.0
var knockback := Vector3.ZERO
var hit_type: CombatTypes.HitType = CombatTypes.HitType.NORMAL
var attack_id := StringName("")
var status_effect := StringName("")
