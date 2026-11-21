class_name CombatBlast
extends RefCounted
## Sprint 38 (D-107): the one radial-damage implementation — a shape query
## at a position, every hurtbox on the target layer takes an honest event,
## plus an expanding flash. The Flame Set's firebolt (Sprint 37) and the
## Gladiator Set's finisher explosion (this sprint) both route through here.

## Detonates at `position`; returns how many hurtboxes took the blast.
static func detonate(tree_node: Node3D, position: Vector3, radius: float,
		damage: float, source: Node, target_mask: int, attack_id: StringName) -> int:
	var space := tree_node.get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	params.shape = sphere
	params.transform = Transform3D(Basis(), position)
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.collision_mask = target_mask
	var hits := 0
	for hit in space.intersect_shape(params, 8):
		var hurtbox := hit.collider as HurtboxComponent
		if hurtbox == null:
			continue
		var blast := DamageEvent.new()
		blast.source = source
		blast.amount = damage
		blast.attack_id = attack_id
		hurtbox.receive_damage(blast)
		hits += 1
	_spawn_flash(tree_node, position, radius)
	return hits

## The readable half of an explosion: an expanding orange flash, freed
## before the next swing (gameplay timing never depends on it).
static func _spawn_flash(tree_node: Node, position: Vector3, radius: float) -> void:
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	flash.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.5, 0.1, 0.55)
	flash.material_override = material
	flash.position = position
	tree_node.get_parent().add_child(flash)
	tree_node.get_tree().create_timer(0.15).timeout.connect(flash.queue_free)
