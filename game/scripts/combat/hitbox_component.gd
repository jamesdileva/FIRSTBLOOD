class_name HitboxComponent
extends Area3D
## Attack area (guide §6). While active it delivers one DamageEvent per
## activation to each valid opposing HurtboxComponent it overlaps. Teams are
## filtered by physics layers (D-013) and again in code as defense-in-depth.

signal hit_landed(event: DamageEvent, target: HurtboxComponent)

@export var faction: CombatTypes.Faction = CombatTypes.Faction.NEUTRAL
@export var damage := 10.0
@export var stagger_damage := 0.0
@export var knockback := Vector3.ZERO
@export var hit_type: CombatTypes.HitType = CombatTypes.HitType.NORMAL
@export var attack_id := StringName("")

var _active := false
var _hit_targets: Dictionary = {}
var _debug_mesh: MeshInstance3D

func _ready() -> void:
	monitorable = false
	monitoring = false
	collision_layer = 0
	collision_mask = CombatTypes.hitbox_mask(faction)
	area_entered.connect(_on_area_entered)

func set_active(value: bool) -> void:
	if _active == value:
		return
	_active = value
	_hit_targets.clear()
	monitoring = value

func is_active() -> bool:
	return _active

func _physics_process(_delta: float) -> void:
	if not _active:
		return
	# Sweep as well as listening for area_entered: overlaps that already exist
	# when the hitbox turns on must still register exactly once (dedup below).
	for area in get_overlapping_areas():
		_try_hit(area)

func _on_area_entered(area: Area3D) -> void:
	if _active:
		_try_hit(area)

func _try_hit(area: Area3D) -> void:
	var hurtbox := area as HurtboxComponent
	if hurtbox == null:
		return
	if hurtbox.faction == faction:
		return  # team filter: never hit self or allies
	if _hit_targets.has(hurtbox.get_instance_id()):
		return
	_hit_targets[hurtbox.get_instance_id()] = true
	var event := DamageEvent.new()
	event.source = _resolve_source()
	event.amount = damage
	event.stagger_damage = stagger_damage
	event.knockback = knockback
	event.hit_type = hit_type
	event.attack_id = attack_id
	hurtbox.receive_damage(event)
	hit_landed.emit(event, hurtbox)

func _resolve_source() -> Node:
	if owner != null:
		return owner
	return get_parent()

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
	_debug_mesh = MeshInstance3D.new()
	_debug_mesh.name = "DebugShape"
	_debug_mesh.transform = shape_node.transform
	_debug_mesh.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.25, 0.2, 0.35)
	_debug_mesh.material_override = material
	_debug_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_debug_mesh)

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
		_debug_mesh.visible = CombatDebug.combat_shapes_visible and _active
