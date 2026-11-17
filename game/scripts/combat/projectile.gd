class_name Projectile
extends Node3D
## Sprint 30/32: a generic projectile carrier — a HitboxComponent traveling
## in a straight line (the player's firebolt, the Medusa's spit — any
## faction). Its DamageEvent lands through the same hurtbox→Health path as
## melee (no bespoke damage code); it despawns on its first hit or when its
## lifetime runs out.

var velocity := Vector3.ZERO
var lifetime := 2.0

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
	queue_free()
