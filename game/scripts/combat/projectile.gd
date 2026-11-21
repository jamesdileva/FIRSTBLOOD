class_name Projectile
extends Node3D
## Sprint 30/32/37: a generic projectile carrier — a HitboxComponent traveling
## in a straight line (the player's firebolt, the Medusa's spit — any
## faction). Its DamageEvent lands through the same hurtbox→Health path as
## melee (no bespoke damage code); it despawns on its first hit or when its
## lifetime runs out. Sprint 37 (D-105/106): with `explode_damage` set, the
## impact detonates a radial blast — every enemy hurtbox in the radius takes
## a blast event through the same receive_damage path (the primary included).

var velocity := Vector3.ZERO
var lifetime := 2.0
var explode_damage := 0.0
var explode_radius := 0.0

func _ready() -> void:
	add_to_group("spell_projectile")
	var hitbox := get_node_or_null("Hitbox") as HitboxComponent
	if hitbox != null:
		hitbox.hit_landed.connect(_on_hit)
		hitbox.set_active(true)

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_hit(_event: DamageEvent, _target: HurtboxComponent) -> void:
	if explode_damage > 0.0 and explode_radius > 0.0:
		_explode()
	queue_free()

## The blast: the shared CombatBlast detonation — every hurtbox on the
## enemy hurtbox layer takes the blast event (including the primary, whose
## direct hit already landed). The blast's source is this projectile, the
## same source the direct hit carries.
func _explode() -> void:
	CombatBlast.detonate(self, global_position, explode_radius, explode_damage,
			self, CombatTypes.hurtbox_layer(CombatTypes.Faction.BOSS), &"fire_blast")
