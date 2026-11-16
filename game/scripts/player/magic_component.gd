class_name MagicComponent
extends Node
## Sprint 29/30 (D-087/088/089): the four-slot spell loadout (guide §25's
## MagicLoadout) and its cast path. Casting resolves through the sibling
## ManaComponent's atomic spend — no mana, no cast, nothing else happens.
## Sprint 30 fills the dispatcher: heal, fire (a real projectile), freeze
## (the boss rooted), reflect (a timed negation-and-return buff). The input
## gate (LB + face) lives in the player controller's neutral states — this
## component is input-agnostic.

signal spell_cast(spell: SpellData, slot: StringName)

const PROJECTILE_SPEED := 10.0
const HEAL_TINT := Color(0.35, 0.9, 0.4)
const REFLECT_TINT := Color(0.5, 0.85, 0.95)

@export var slot_a: SpellData
@export var slot_b: SpellData
@export var slot_x: SpellData
@export var slot_y: SpellData

var _reflect_left := 0.0
var _reflect_power := 0.0

func cast_slot(slot: StringName) -> bool:
	var spell := _spell(slot)
	if spell == null:
		return false
	var mana := get_node_or_null("../Mana") as ManaComponent
	if mana == null:
		return false
	if not mana.spend(spell.mana_cost):
		return false
	spell_cast.emit(spell, slot)
	_dispatch(spell)
	return true

func _spell(slot: StringName) -> SpellData:
	match slot:
		&"a":
			return slot_a
		&"b":
			return slot_b
		&"x":
			return slot_x
		&"y":
			return slot_y
	return null

func _physics_process(delta: float) -> void:
	if _reflect_left > 0.0:
		_reflect_left -= delta
		if _reflect_left <= 0.0:
			_reflect_left = 0.0
			_clear_player_tint()

## D-091: the reflect window's state, consumed by the player's damage
## resolution.
func reflect_active() -> bool:
	return _reflect_left > 0.0

func reflect_power() -> float:
	return _reflect_power

## D-058 full-reset semantics: a retry ends the window (and its tint).
func end_reflect() -> void:
	_reflect_left = 0.0
	_reflect_power = 0.0
	_clear_player_tint()

func _dispatch(spell: SpellData) -> void:
	match spell.effect:
		&"heal":
			var health := get_node_or_null("../Health") as HealthComponent
			if health != null:
				health.heal(spell.power)
				_flash_tint(HEAL_TINT, 0.3)
		&"fire":
			_spawn_fire_projectile(spell)
		&"freeze":
			var boss := get_tree().get_first_node_in_group("boss")
			if boss != null and boss.has_method("freeze_for"):
				boss.freeze_for(spell.duration)
		&"reflect":
			_reflect_left = spell.duration
			_reflect_power = spell.power
			_set_player_tint(REFLECT_TINT)
		&"spark":
			pass  # the Sprint 29 placeholder: the mana spend IS the effect
		_:
			push_warning("Unknown spell effect '%s' — nothing happened." % spell.effect)

## D-090: a code-built carrier — a faction-PLAYER HitboxComponent flying
## straight at the boss's chest (forward if no live boss). The DamageEvent
## lands through the same hurtbox→Health path as melee.
func _spawn_fire_projectile(spell: SpellData) -> void:
	var player := get_parent() as Node3D
	if player == null:
		return
	var origin: Vector3 = player.global_position + Vector3.UP * 1.2
	var direction := -player.global_transform.basis.z
	var boss := get_tree().get_first_node_in_group("boss") as Node3D
	if boss != null and (not boss.has_method("is_dead") or not boss.is_dead()):
		direction = ((boss.global_position + Vector3.UP * 1.0) - origin).normalized()
	var projectile := SpellProjectile.new()
	projectile.velocity = direction * PROJECTILE_SPEED
	projectile.position = origin + direction * 0.6
	var hitbox := HitboxComponent.new()
	hitbox.name = "Hitbox"
	hitbox.faction = CombatTypes.Faction.PLAYER
	hitbox.damage = spell.power
	hitbox.attack_id = &"spell_fire"
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	shape.shape = sphere
	hitbox.add_child(shape)
	var mesh := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.18
	sphere_mesh.height = 0.36
	mesh.mesh = sphere_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.45, 0.1)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.4, 0.05)
	mesh.material_override = material
	projectile.add_child(hitbox)
	projectile.add_child(mesh)
	player.get_parent().add_child(projectile)

func _flash_tint(color: Color, seconds: float) -> void:
	_set_player_tint(color)
	get_tree().create_timer(seconds).timeout.connect(_clear_player_tint)

func _set_player_tint(color: Color) -> void:
	var player := get_parent()
	if player != null and player.has_method("set_body_tint"):
		player.set_body_tint(color)

func _clear_player_tint() -> void:
	var player := get_parent()
	if player != null and player.has_method("clear_body_tint"):
		player.clear_body_tint()

## One-line F1 summary of the loadout.
func loadout_debug() -> String:
	return "A=%s B=%s X=%s Y=%s" % [
		_slot_debug(slot_a), _slot_debug(slot_b), _slot_debug(slot_x), _slot_debug(slot_y),
	]

func _slot_debug(spell: SpellData) -> String:
	if spell == null:
		return "—"
	return "%s(%d)" % [spell.display_name, roundi(spell.mana_cost)]
