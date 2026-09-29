class_name HurtboxComponent
extends Area3D
## Damageable area (guide §6). Passive: never scans, only receives. Resolves
## incoming DamageEvents — checking immunity (D-015: asks the owning actor's
## `is_invulnerable()` if it defines one, e.g. the dodge i-frames) — then emits
## the structured result for its owner to react to.

signal damaged(event: DamageEvent)
signal damage_blocked(event: DamageEvent)

@export var faction: CombatTypes.Faction = CombatTypes.Faction.NEUTRAL

var _debug_mesh: MeshInstance3D

func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_layer = CombatTypes.hurtbox_layer(faction)
	collision_mask = 0

func receive_damage(event: DamageEvent) -> void:
	if _is_immune():
		damage_blocked.emit(event)
		return
	damaged.emit(event)

func _is_immune() -> bool:
	var node: Node = self
	while node != null:
		if node.has_method("is_invulnerable") and node.is_invulnerable():
			return true
		node = node.get_parent()
	return false

func _build_debug_shape() -> void:
	# Built lazily: the CollisionShape3D child may be added after this node
	# enters the tree (e.g. by tests composing components at runtime). Looked
	# up by type, not name — runtime-created shapes get auto-generated names.
	var shape_node := _find_shape_node()
	if shape_node == null or shape_node.shape == null:
		return
	var mesh := _debug_mesh_for(shape_node.shape)
	if mesh == null:
		return
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "DebugShape"
	mesh_instance.transform = shape_node.transform
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.2, 1.0, 0.4, 0.25)
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	_debug_mesh = mesh_instance

func _find_shape_node() -> CollisionShape3D:
	for child in get_children():
		var shape_node := child as CollisionShape3D
		if shape_node != null:
			return shape_node
	return null

func _debug_mesh_for(shape: Shape3D) -> Mesh:
	if shape is BoxShape3D:
		var box := BoxMesh.new()
		box.size = shape.size
		return box
	if shape is SphereShape3D:
		var sphere := SphereMesh.new()
		sphere.radius = shape.radius
		sphere.height = shape.radius * 2.0
		return sphere
	if shape is CapsuleShape3D:
		var capsule := CapsuleMesh.new()
		capsule.radius = shape.radius
		capsule.height = shape.height
		return capsule
	return null

func _process(_delta: float) -> void:
	if _debug_mesh == null:
		_build_debug_shape()
	if _debug_mesh != null:
		_debug_mesh.visible = CombatDebug.combat_shapes_visible
