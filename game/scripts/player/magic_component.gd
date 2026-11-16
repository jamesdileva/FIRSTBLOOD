class_name MagicComponent
extends Node
## Sprint 29 (D-087/088): the four-slot spell loadout (guide §25's
## MagicLoadout) and its cast path. Casting resolves through the sibling
## ManaComponent's atomic spend — no mana, no cast, nothing else happens.
## The spell's `effect` key dispatches to implementations; only the spark
## no-op exists until Sprint 30's pool. The input gate (LB + face) lives in
## the player controller's neutral states — this component is input-agnostic.

signal spell_cast(spell: SpellData, slot: StringName)

@export var slot_a: SpellData
@export var slot_b: SpellData
@export var slot_x: SpellData
@export var slot_y: SpellData

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

func _dispatch(spell: SpellData) -> void:
	match spell.effect:
		&"spark":
			pass  # the Sprint 29 placeholder: the mana spend IS the effect
		_:
			push_warning("Unknown spell effect '%s' — nothing happened." % spell.effect)

## One-line F1 summary of the loadout.
func loadout_debug() -> String:
	return "A=%s B=%s X=%s Y=%s" % [
		_slot_debug(slot_a), _slot_debug(slot_b), _slot_debug(slot_x), _slot_debug(slot_y),
	]

func _slot_debug(spell: SpellData) -> String:
	if spell == null:
		return "—"
	return "%s(%d)" % [spell.display_name, roundi(spell.mana_cost)]
