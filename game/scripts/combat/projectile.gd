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

## The blast: a radial shape-query at the impact — every hurtbox on the
## enemy hurtbox layer takes the blast event (including the primary, whose
## direct hit already landed). The blast's source is this projectile, the
## same source the direct hit carries.
func _explode() -> void:
	var space := get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = explode_radius
	params.shape = sphere
	params.transform = Transform3D(Basis(), global_position)
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.collision_mask = CombatTypes.hurtbox_layer(CombatTypes.Faction.BOSS)
	for hit in space.intersect_shape(params, 8):
		var hurtbox := hit.collider as HurtboxComponent
		if hurtbox == null:
			continue
		var blast := DamageEvent.new()
		blast.source = self
		blast.amount = explode_damage
		blast.attack_id = &"fire_blast"
		hurtbox.receive_damage(blast)
	_spawn_flash()

## The readable half of the explosion: an expanding orange flash, freed
## before the next swing (gameplay timing never depends on it).
func _spawn_flash() -> void:
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = explode_radius
	sphere.height = explode_radius * 2.0
	flash.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.5, 0.1, 0.55)
	flash.material_override = material
	flash.position = global_position
	get_parent().add_child(flash)
	get_tree().create_timer(0.15).timeout.connect(flash.queue_free)
