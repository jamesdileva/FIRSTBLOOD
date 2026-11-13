class_name EquipmentComponent
extends Node
## Sprint 26 (D-079): the player's worn gear — one piece per slot,
## equipping into an occupied slot swaps the old piece out. Totals are
## computed on demand; the player controller composes them with the level
## stats (D-066) whenever `equipment_changed` fires. The loadout is owned
## by GearLibrary (D-080): this component applies it at ready and mirrors
## every change back into it (and the save).

signal equipment_changed

var equipped: Dictionary = {}  # slot (StringName) -> GearData

func _ready() -> void:
	GearLibrary.ensure_loaded()
	apply_ids(GearLibrary.loadout)

func equip(item: GearData) -> void:
	if item == null or item.id.is_empty():
		return
	equipped[item.slot] = item
	_sync_library()
	equipment_changed.emit()

func unequip_slot(slot: StringName) -> void:
	if equipped.erase(slot):
		_sync_library()
		equipment_changed.emit()

## The armory's verb: wear the piece (swapping its slot) or take it off.
func toggle(item: GearData) -> void:
	if is_equipped(item):
		unequip_slot(item.slot)
	else:
		equip(item)

func is_equipped(item: GearData) -> bool:
	return equipped.get(item.slot) == item

## Bulk-apply an id list (session loadout / save restore) — one changed
## emission, no save round-trip (the library is the source here).
func apply_ids(ids: Array) -> void:
	equipped.clear()
	for item in GearLibrary.resolve(ids):
		equipped[item.slot] = item
	equipment_changed.emit()

func _sync_library() -> void:
	GearLibrary.loadout.clear()
	for item in equipped.values():
		GearLibrary.loadout.append(StringName(item.id))
	GearLibrary.save_loadout()

func id_list() -> Array[StringName]:
	var ids: Array[StringName] = []
	for item in equipped.values():
		ids.append(StringName(item.id))
	return ids

func hp_bonus() -> float:
	return _total("hp_bonus")

func armor_total() -> float:
	return _total("armor")

func attack_bonus() -> float:
	return _total("attack_bonus")

func movement_bonus() -> float:
	return _total("movement_bonus")

func attack_speed_bonus() -> float:
	return _total("attack_speed_bonus")

func _total(property: String) -> float:
	var sum := 0.0
	for item in equipped.values():
		sum += item.get(property)
	return sum
